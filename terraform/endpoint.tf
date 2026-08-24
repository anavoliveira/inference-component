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
    role_arn = local.execution_role_arn
  }

  triggers_replace = [
    local.endpoint_config_name,
    var.flavor_params.instance_type,
    var.flavor_params.initial_instance_count,
    var.flavor_params.volume_size_in_gb,
    var.flavor_params.autoscaling.max_capacity,
    local.execution_role_arn,
    join(",", var.flavor_params.network.subnet_ids),
    data.aws_security_group.default.id,
  ]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    environment = {
      PRODUCTION_VARIANTS_JSON = jsonencode([
        {
          VariantName          = local.variant_name
          InstanceType         = var.flavor_params.instance_type
          InitialInstanceCount = var.flavor_params.initial_instance_count
          VolumeSizeInGB       = var.flavor_params.volume_size_in_gb
          ManagedInstanceScaling = {
            Status           = "ENABLED"
            MinInstanceCount = 0
            # SageMaker's ManagedInstanceScaling has no direct equivalent to
            # flavor_params.autoscaling.max_capacity (that's the inference
            # component's DesiredCopyCount ceiling, a different dimension) -
            # reused here as the instance-count ceiling too, since
            # flavor_params has no dedicated field for it.
            MaxInstanceCount = var.flavor_params.autoscaling.max_capacity
          }
        }
      ])
      # Must match aws_sagemaker_model's vpc_config exactly - AWS's Vpc consistency
      # check is order-sensitive, and vpc_config.subnets is a set in the aws provider
      # schema (normalized/sorted), so read it back from the model instead of
      # reusing var.flavor_params.network.subnet_ids directly.
      VPC_CONFIG_JSON = jsonencode({
        Subnets          = aws_sagemaker_model.this.vpc_config[0].subnets
        SecurityGroupIds = aws_sagemaker_model.this.vpc_config[0].security_group_ids
      })
    }
    command = <<-EOT
      $tmp = New-TemporaryFile
      $vpcTmp = New-TemporaryFile
      $utf8NoBom = New-Object System.Text.UTF8Encoding $false
      [System.IO.File]::WriteAllText($tmp, $env:PRODUCTION_VARIANTS_JSON, $utf8NoBom)
      [System.IO.File]::WriteAllText($vpcTmp, $env:VPC_CONFIG_JSON, $utf8NoBom)
      $profileArgs = if ("${self.input.profile}") { @("--profile", "${self.input.profile}") } else { @() }
      aws sagemaker create-endpoint-config `
        --endpoint-config-name "${self.input.name}" `
        --production-variants "file://$tmp" `
        --execution-role-arn "${self.input.role_arn}" `
        --vpc-config "file://$vpcTmp" `
        --region "${self.input.region}" `
        @profileArgs
      $exit = $LASTEXITCODE
      Remove-Item $tmp, $vpcTmp
      exit $exit
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-NoProfile", "-Command"]
    command     = <<-EOT
      $profileArgs = if ("${self.input.profile}") { @("--profile", "${self.input.profile}") } else { @() }
      aws sagemaker delete-endpoint-config `
        --endpoint-config-name "${self.input.name}" `
        --region "${self.input.region}" `
        @profileArgs
    EOT
  }
}

# AWS::SageMaker::Endpoint is not (yet) implemented by the Cloud Control API
# backend (CreateResource returns UnsupportedActionException), so
# awscc_sagemaker_endpoint cannot be used despite existing in the provider's
# schema. aws_sagemaker_endpoint has no model_name constraint (that only
# applies to production_variants in the endpoint configuration), so it works
# natively here.
resource "aws_sagemaker_endpoint" "this" {
  provider = aws.provider-lotus

  name                 = local.endpoint_name
  endpoint_config_name = local.endpoint_config_name

  tags = local.tags

  depends_on = [terraform_data.endpoint_config]
}
