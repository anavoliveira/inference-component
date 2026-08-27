resource "terraform_data" "endpoint_config" {
  input = {
    name     = local.endpoint_config_name
    region   = "sa-east-1"
    profile  = var.aws_profile
    role_arn = module.iam.arn
  }

  triggers_replace = [
    local.endpoint_config_name,
    local.flavor_params.instance_type,
    local.flavor_params.initial_instance_count,
    local.flavor_params.volume_size_in_gb,
    local.flavor_params.autoscaling.max_capacity,
    module.iam.arn,
    join(",", local.flavor_params.network.subnet_ids),
    data.aws_security_group.lotus.id,
  ]

  depends_on = [aws_sagemaker_model.this]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      PRODUCTION_VARIANTS_JSON = jsonencode([
        {
          VariantName          = local.variant_name
          InstanceType         = local.flavor_params.instance_type
          InitialInstanceCount = local.flavor_params.initial_instance_count
          VolumeSizeInGB       = local.flavor_params.volume_size_in_gb
          ManagedInstanceScaling = {
            Status           = "ENABLED"
            MinInstanceCount = 0
            MaxInstanceCount = local.flavor_params.autoscaling.max_capacity
          }
        }
      ])

      # Must match aws_sagemaker_model's vpc_config exactly - AWS's Vpc consistency
      # check is order-sensitive, and vpc_config.subnets is a set in the aws
      # provider schema (normalized/sorted), so read it back from the model
      # instead of hardcoding/reusing the raw subnet list directly.
      VPC_CONFIG_JSON = jsonencode({
        Subnets          = aws_sagemaker_model.this.vpc_config[0].subnets
        SecurityGroupIds = aws_sagemaker_model.this.vpc_config[0].security_group_ids
      })
    }
    command = <<-EOT
      tmp=$(mktemp)
      vpcTmp=$(mktemp)
      printf '%s' "$PRODUCTION_VARIANTS_JSON" > "$tmp"
      printf '%s' "$VPC_CONFIG_JSON" > "$vpcTmp"
      aws sagemaker create-endpoint-config \
        --endpoint-config-name "${self.input.name}" \
        --production-variants "file://$tmp" \
        --execution-role-arn "${self.input.role_arn}" \
        --vpc-config "file://$vpcTmp" \
        --region "${self.input.region}"
      exit_code=$?
      rm -f "$tmp" "$vpcTmp"
      exit $exit_code
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      aws sagemaker delete-endpoint-config \
        --endpoint-config-name "${self.input.name}" \
        --region "${self.input.region}"
    EOT
  }
}

resource "aws_sagemaker_endpoint" "this" {
  name                 = local.endpoint_name
  endpoint_config_name = local.endpoint_config_name

  tags = local.tags

  depends_on = [terraform_data.endpoint_config]
}
