data "aws_iam_policy_document" "sagemaker_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sagemaker_execution" {
  name               = "${var.project_name}-sagemaker-execution-role"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

data "aws_iam_policy_document" "model_artifact_access" {
  statement {
    sid       = "ListModelArtifactBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.model_artifact_bucket_arn]
  }

  statement {
    sid       = "ReadModelArtifact"
    actions   = ["s3:GetObject"]
    resources = ["${var.model_artifact_bucket_arn}/*"]
  }

  # Data capture writes request/response payloads to S3 (var.data_capture_s3_uri).
  # Assumes it lives in the same bucket as the model artifact - true for this
  # test setup; split into its own statement/bucket ARN if that ever changes.
  statement {
    sid       = "WriteDataCapture"
    actions   = ["s3:PutObject"]
    resources = ["${var.model_artifact_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "model_artifact_access" {
  name   = "${var.project_name}-model-artifact-access"
  role   = aws_iam_role.sagemaker_execution.id
  policy = data.aws_iam_policy_document.model_artifact_access.json
}
