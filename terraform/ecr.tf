resource "aws_ecr_repository" "iris_ic" {
  name                 = "${var.project_name}-inference"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
