provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

provider "awscc" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
