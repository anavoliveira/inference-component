data "aws_caller_identity" "current_account" {}

provider "aws" {
  alias = "provider-datamesh"
  region = "sa-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${{data.aws_caller_identity.current_account.account_id}}:role/{role_name}"
  }
}

  
provider "aws" {
  alias = "provider-lotus"
  region = "sa-east-1"
}

provider "awscc" {
  region  = "sa-east-1"
}