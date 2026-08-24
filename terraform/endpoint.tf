locals {
  endpoint_config_name = "${var.project_name}-endpoint-config"
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
    kms_key  = coalesce(var.kms_key_id, "")
  }

  triggers_replace = [
    local.endpoint_config_name,
    var.variant_name,
    var.instance_type,
    var.max_instance_count,
    aws_iam_role.sagemaker_execution.arn,
    join(",", var.subnet_ids),
    join(",", var.security_group_ids),
    coalesce(var.kms_key_id, ""),
    var.data_capture_enabled,
    coalesce(var.data_capture_s3_uri, ""),
    var.data_capture_sampling_percentage,
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    environment = {
      PRODUCTION_VARIANTS_JSON = jsonencode([
        {
          VariantName          = var.variant_name
          InstanceType         = var.instance_type
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
      DATA_CAPTURE_CONFIG_JSON = var.data_capture_enabled ? jsonencode(merge(
        {
          EnableCapture             = true
          InitialSamplingPercentage = var.data_capture_sampling_percentage
          DestinationS3Uri          = var.data_capture_s3_uri
          CaptureOptions = [
            { CaptureMode = "Input" },
            { CaptureMode = "Output" },
          ]
        },
        var.kms_key_id != null ? { KmsKeyId = var.kms_key_id } : {}
      )) : ""
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
    command     = <<-EOT
      aws sagemaker delete-endpoint-config `
        --endpoint-config-name "${self.input.name}" `
        --region "${self.input.region}" `
        --profile "${self.input.profile}"
    EOT
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
}
