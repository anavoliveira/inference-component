locals {
  # Falls back to the KMS key this stack creates (kms.tf) when var.kms_key_id
  # isn't explicitly overridden.
  kms_key_arn = coalesce(var.kms_key_id, aws_kms_key.endpoint.arn)

  # SageMaker EndpointConfigs are immutable and can't be deleted while an
  # Endpoint still uses them - versioning the name (like the model above)
  # lets the new config be created and the endpoint switched over to it
  # before the old config is destroyed.
  endpoint_config_suffix = substr(md5(join(",", [
    var.instance_type,
    tostring(var.max_instance_count),
    local.kms_key_arn,
    tostring(var.data_capture_enabled),
    var.data_capture_s3_uri != null ? var.data_capture_s3_uri : "",
    tostring(var.data_capture_sampling_percentage),
  ])), 0, 8)
  endpoint_config_name = "${var.project_name}-endpoint-config-${local.endpoint_config_suffix}"
}

# hashicorp/aws still requires `model_name` on production_variants
# (terraform-provider-aws#40644, open) and hashicorp/awscc has no
# awscc_sagemaker_endpoint_config resource at all. Inference-component-only
# endpoints require an endpoint config with NO model on the variant (AWS API
# supports this; neither provider's schema does yet), so this one piece is
# created directly via the AWS CLI and tracked with terraform_data.
resource "terraform_data" "endpoint_config" {
  input = {
    name     = local.endpoint_config_name
    region   = var.aws_region
    profile  = var.aws_profile
    role_arn = aws_iam_role.sagemaker_execution.arn
    kms_key  = local.kms_key_arn
  }

  triggers_replace = [
    local.endpoint_config_name,
    var.variant_name,
    var.instance_type,
    var.max_instance_count,
    aws_iam_role.sagemaker_execution.arn,
    join(",", var.subnet_ids),
    join(",", var.security_group_ids),
    local.kms_key_arn,
    var.data_capture_enabled,
    var.data_capture_s3_uri != null ? var.data_capture_s3_uri : "",
    var.data_capture_sampling_percentage,
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    environment = {
      PRODUCTION_VARIANTS_JSON = jsonencode([
        {
          VariantName  = var.variant_name
          InstanceType = var.instance_type
          # CreateEndpointConfig rejects InitialInstanceCount = 0 (min value:
          # 1) even though ManagedInstanceScaling.MinInstanceCount = 0 is what
          # actually enables scale-to-zero. This is only the STARTING point
          # for a brand-new endpoint; switching an EXISTING endpoint to a new
          # config uses --retain-all-variant-properties instead (see
          # terraform_data.endpoint_update below), which ignores this value.
          InitialInstanceCount = 1
          ManagedInstanceScaling = {
            Status           = "ENABLED"
            MinInstanceCount = 0
            MaxInstanceCount = var.max_instance_count
          }
        }
      ])
      # Must match aws_sagemaker_model's vpc_config exactly - AWS's Vpc consistency
      # check is order-sensitive, and vpc_config.subnets is a set in the aws provider
      # schema (normalized/sorted), so read it back from the model instead of
      # reusing var.subnet_ids directly.
      VPC_CONFIG_JSON = jsonencode({
        Subnets          = aws_sagemaker_model.iris.vpc_config[0].subnets
        SecurityGroupIds = aws_sagemaker_model.iris.vpc_config[0].security_group_ids
      })
      # Empty string when data_capture_enabled = false - the PowerShell command
      # only adds --data-capture-config when this is non-empty.
      DATA_CAPTURE_CONFIG_JSON = var.data_capture_enabled ? jsonencode({
        EnableCapture             = true
        InitialSamplingPercentage = var.data_capture_sampling_percentage
        DestinationS3Uri          = var.data_capture_s3_uri
        CaptureOptions = [
          { CaptureMode = "Input" },
          { CaptureMode = "Output" },
        ]
        KmsKeyId = local.kms_key_arn
      }) : ""
    }
    command = <<-EOT
      $tmp = New-TemporaryFile
      $vpcTmp = New-TemporaryFile
      $utf8NoBom = New-Object System.Text.UTF8Encoding $false
      [System.IO.File]::WriteAllText($tmp, $env:PRODUCTION_VARIANTS_JSON, $utf8NoBom)
      [System.IO.File]::WriteAllText($vpcTmp, $env:VPC_CONFIG_JSON, $utf8NoBom)

      $extraArgs = @()
      if ("${self.input.kms_key}") { $extraArgs += @("--kms-key-id", "${self.input.kms_key}") }

      $dcTmp = $null
      if ($env:DATA_CAPTURE_CONFIG_JSON) {
        $dcTmp = New-TemporaryFile
        [System.IO.File]::WriteAllText($dcTmp, $env:DATA_CAPTURE_CONFIG_JSON, $utf8NoBom)
        $extraArgs += @("--data-capture-config", "file://$dcTmp")
      }

      aws sagemaker create-endpoint-config `
        --endpoint-config-name "${self.input.name}" `
        --production-variants "file://$tmp" `
        --execution-role-arn "${self.input.role_arn}" `
        --vpc-config "file://$vpcTmp" `
        --region "${self.input.region}" `
        --profile "${self.input.profile}" `
        @extraArgs
      $exit = $LASTEXITCODE
      Remove-Item $tmp, $vpcTmp
      if ($dcTmp) { Remove-Item $dcTmp }
      exit $exit
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    on_failure  = continue
    command     = <<-EOT
      aws sagemaker delete-endpoint-config `
        --endpoint-config-name "${self.input.name}" `
        --region "${self.input.region}" `
        --profile "${self.input.profile}"
    EOT
  }

  lifecycle {
    create_before_destroy = true
  }
}

# AWS::SageMaker::Endpoint is not (yet) implemented by the Cloud Control API
# backend (CreateResource returns UnsupportedActionException), so
# awscc_sagemaker_endpoint cannot be used despite existing in the provider's
# schema. aws_sagemaker_endpoint has no model_name constraint (that only
# applies to production_variants in the endpoint configuration), so it works
# natively here.
resource "aws_sagemaker_endpoint" "iris" {
  name                 = var.endpoint_name
  endpoint_config_name = local.endpoint_config_name

  tags = var.tags

  depends_on = [terraform_data.endpoint_config]

  lifecycle {
    # UpdateEndpoint (what changing this attribute triggers) fails for
    # IC-enabled endpoints unless RetainAllVariantProperties=true, which this
    # resource doesn't expose - terraform_data.endpoint_update below handles
    # switching the config via the AWS CLI instead.
    ignore_changes = [endpoint_config_name]
  }
}

# aws_sagemaker_endpoint can create an endpoint (pointing at whatever config
# was current then) but can't update endpoint_config_name on an IC-enabled
# endpoint - see the ignore_changes above. This does that update instead, via
# --retain-all-variant-properties (not exposed by the Terraform resource),
# which tells SageMaker to keep the endpoint's current instance count rather
# than requiring the new config's InitialInstanceCount to match it exactly.
resource "terraform_data" "endpoint_update" {
  input = {
    endpoint_name        = aws_sagemaker_endpoint.iris.name
    endpoint_config_name = local.endpoint_config_name
    region               = var.aws_region
    profile              = var.aws_profile
  }

  triggers_replace = [local.endpoint_config_name]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    command     = <<-EOT
      $profileArgs = if ("${self.input.profile}") { @("--profile", "${self.input.profile}") } else { @() }
      aws sagemaker update-endpoint `
        --endpoint-name "${self.input.endpoint_name}" `
        --endpoint-config-name "${self.input.endpoint_config_name}" `
        --retain-all-variant-properties `
        --region "${self.input.region}" `
        @profileArgs
    EOT
  }

  depends_on = [aws_sagemaker_endpoint.iris, terraform_data.endpoint_config]
}
