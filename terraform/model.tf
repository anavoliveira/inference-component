locals {
  # SageMaker Models are immutable and can't be deleted while an Inference
  # Component still references them - versioning the name lets Terraform
  # create the replacement before destroying the old one (create_before_destroy
  # below), instead of trying to delete an in-use model first.
  #
  # "with_image_config" marks the (reverted) attempt to set
  # image_config.repository_access_mode = "Platform" - AWS rejects that for
  # models attached to an Inference Component ("The Inference Component does
  # not support models with the ImageConfig specification"), confirmed
  # against the live account on 2026-08-26. Kept in the hash so this model
  # gets a fresh name distinct from the broken one already created in AWS,
  # instead of colliding with it under create_before_destroy.
  model_name_suffix = substr(md5(join(",", [
    aws_ecr_repository.iris_ic.repository_url,
    var.container_image_tag,
    var.model_data_url,
    "no_image_config",
  ])), 0, 8)
  model_name = "${var.project_name}-model-${local.model_name_suffix}"
}

resource "aws_sagemaker_model" "iris" {
  name               = local.model_name
  execution_role_arn = aws_iam_role.sagemaker_execution.arn

  primary_container {
    # Custom image (not an AWS-managed framework container) - see ecr.tf. Avoids
    # the AWS-managed sklearn container's "pip install ." step at container
    # startup, which needs PyPI access unavailable from these VPC subnets
    # (no NAT gateway). Everything is baked in at build time instead.
    #
    # No image_config here - see model_name_suffix comment above for why.
    image          = "${aws_ecr_repository.iris_ic.repository_url}:${var.container_image_tag}"
    model_data_url = var.model_data_url
  }

  vpc_config {
    subnets            = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
