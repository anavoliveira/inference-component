# References an existing ECR repository/image (managed outside this stack)
# instead of creating one. Fails at plan time if the repo doesn't exist,
# which is the desired signal - image build/push stays a separate workflow.
data "aws_ecr_repository" "iris_ic" {
  name = var.ecr_repository_name
}
