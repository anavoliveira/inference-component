terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.84.0 is the first version that supports min_instance_count = 0 on
      # aws_sagemaker_endpoint_configuration (fixes hashicorp/terraform-provider-aws#40606).
      version = ">= 5.84.0, < 6.0.0"
    }
    awscc = {
      source = "hashicorp/awscc"
      # hashicorp/aws has no aws_sagemaker_inference_component resource, and still
      # requires model_name on production_variants (terraform-provider-aws#40644 open),
      # which is incompatible with inference-component-only endpoints. awscc wraps the
      # AWS Cloud Control API directly, so it does not have either limitation.
      version = ">= 1.4.0, < 2.0.0"
    }
  }

  backend "local" {}
}
