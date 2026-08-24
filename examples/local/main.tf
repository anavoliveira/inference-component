# Root wrapper for standalone/local testing of ../../terraform (the flavor
# module). Mirrors the real platform root's provider pattern - a default aws
# provider plus an aliased "provider-datamesh" one (normally assume-role'd
# into a separate account for flavor_params.data_mesh resources).
#
# This test account has no real cross-account datamesh role, so
# provider-datamesh just reuses the same credentials here - only relevant
# once data_mesh resources are actually implemented in the module.

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

provider "aws" {
  alias   = "provider-datamesh"
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

provider "awscc" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

module "inference_component" {
  source = "../../terraform"

  providers = {
    aws                   = aws
    aws.provider-datamesh = aws.provider-datamesh
    awscc                 = awscc
  }

  aws_region    = var.aws_region
  aws_profile   = var.aws_profile
  project_role  = var.project_role
  model_name    = var.model_name
  flavor_params = var.flavor_params
}
