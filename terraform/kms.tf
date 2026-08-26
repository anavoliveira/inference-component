data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key" {
  statement {
    sid       = "AccountRootFullAccess"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "AllowSageMakerExecutionRole"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.sagemaker_execution.arn]
    }
  }
}

resource "aws_kms_key" "endpoint" {
  description             = "${var.project_name} endpoint storage volume + data capture encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key.json

  tags = var.tags
}

resource "aws_kms_alias" "endpoint" {
  name          = "alias/${var.project_name}-endpoint"
  target_key_id = aws_kms_key.endpoint.key_id
}
