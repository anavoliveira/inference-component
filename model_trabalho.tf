resource "aws_sagemaker_model" "this" {
  name               = local.flavor_params.project.model_name
  execution_role_arn = module.iam.arn

  primary_container {
    image          = local.flavor_params.image_uri
    model_data_url = local.model_data_url
    environment    = local.flavor_params.inference_environment
  }

  vpc_config {
    subnets = [
      "subnet-0fc7f8d193406bce4",
      "subnet-029ee35e1144dcee8",
    ]
    security_group_ids = [data.aws_security_group.lotus.id]
  }

  tags = local.tags
}
