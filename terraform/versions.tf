terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.84.0 is the first version that supports min_instance_count = 0 on
      # aws_sagemaker_endpoint_configuration (fixes hashicorp/terraform-provider-aws#40606).
      # Compatible with the root module's "~> 5.0" pin.
      version = ">= 5.84.0, < 6.0.0"

      # This is a child module (a "flavor") - it does not configure its own
      # providers; the calling root module passes them in via the `providers`
      # argument on the `module` block. `aws` is the default/unaliased
      # provider slot; `aws.provider-datamesh` is a second aws configuration
      # (typically assume-role'd into a different account) for the
      # flavor_params.data_mesh resources.
      configuration_aliases = [aws, aws.provider-datamesh]
    }
    awscc = {
      source = "hashicorp/awscc"
      # hashicorp/aws has no aws_sagemaker_inference_component resource, and still
      # requires model_name on production_variants (terraform-provider-aws#40644 open),
      # which is incompatible with inference-component-only endpoints. awscc wraps the
      # AWS Cloud Control API directly, so it does not have either limitation.
      #
      # NOTE: the root module snippet shared for this platform only configures
      # "aws" providers (provider-lotus / provider-datamesh) - it will also need
      # a `provider "awscc" {}` block, passed to this module as `providers = { awscc = awscc }`.
      version = ">= 1.4.0, < 2.0.0"
    }
  }
}
