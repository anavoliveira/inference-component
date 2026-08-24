terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"

      # Intermediate module: no real provider blocks here, only aliases
      # relayed from esteira down to modulo-sagemaker/modulo-sagemaker (see
      # main.tf in this directory).
      configuration_aliases = [
        aws.provider-lotus,
        aws.provider-datamesh,
      ]
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.4.0, < 2.0.0"
      # No alias - esteira's awscc provider has none either.
    }
  }
}
