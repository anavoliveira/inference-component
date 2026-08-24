resource "aws_sagemaker_model" "this" {
  name               = var.model_name
  execution_role_arn = local.execution_role_arn

  primary_container {
    # Custom image (not an AWS-managed framework container) - see ../container/.
    # Avoids the AWS-managed sklearn container's "pip install ." step at
    # container startup, which needs PyPI access unavailable from these VPC
    # subnets (no NAT gateway). Everything is baked in at build time instead.
    # Built and pushed to an existing ECR repo outside this stack.
    image          = var.flavor_params.image_uri
    model_data_url = local.model_data_url
    environment    = var.flavor_params.inference_environment
  }

  vpc_config {
    subnets            = var.flavor_params.network.subnet_ids
    security_group_ids = [data.aws_security_group.default.id]
  }

  tags = local.tags
}
