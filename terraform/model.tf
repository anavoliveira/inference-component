resource "aws_sagemaker_model" "iris" {
  name               = "${var.project_name}-model"
  execution_role_arn = aws_iam_role.sagemaker_execution.arn

  primary_container {
    # Custom image (not an AWS-managed framework container) - see ecr.tf. Avoids
    # the AWS-managed sklearn container's "pip install ." step at container
    # startup, which needs PyPI access unavailable from these VPC subnets
    # (no NAT gateway). Everything is baked in at build time instead. The
    # image itself is built and pushed to the existing repo outside this
    # stack (data.aws_ecr_repository.iris_ic references it, doesn't create it).
    image          = "${data.aws_ecr_repository.iris_ic.repository_url}:${var.container_image_tag}"
    model_data_url = var.model_data_url
  }

  vpc_config {
    subnets            = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = var.tags
}
