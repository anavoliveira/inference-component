terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.84.0 is the first version that supports min_instance_count = 0 on
      # aws_sagemaker_endpoint_configuration (fixes hashicorp/terraform-provider-aws#40606).
      # Compatible with the root module's "~> 5.0" pin.
      version = ">= 5.84.0, < 6.0.0"

      # This is the innermost submodule (a "flavor") in esteira -> modulo-sagemaker
      # -> here. None of these levels configure real providers; esteira is the
      # only one that does (provider-lotus, provider-datamesh; awscc is a plain
      # default provider there, no alias). Every level in between just relays
      # the same providers downward via `providers = {}` on its own `module`
      # block. There is no default (unaliased) aws provider anywhere in this
      # chain, so every resource here must set `provider = aws.provider-lotus`
      # (or provider-datamesh for flavor_params.data_mesh resources) explicitly.
      configuration_aliases = [aws.provider-lotus, aws.provider-datamesh]
    }
    awscc = {
      source = "hashicorp/awscc"
      # hashicorp/aws has no aws_sagemaker_inference_component resource, and still
      # requires model_name on production_variants (terraform-provider-aws#40644 open),
      # which is incompatible with inference-component-only endpoints. awscc wraps the
      # AWS Cloud Control API directly, so it does not have either limitation.
      #
      # Plain default provider (esteira's awscc block has no alias) - passed
      # through explicitly at every level anyway (providers = { awscc = awscc }),
      # since implicit inheritance across multiple nested modules is unreliable.
      version = ">= 1.4.0, < 2.0.0"
    }
  }
}
