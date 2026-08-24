resource "awscc_sagemaker_inference_component" "iris" {
  inference_component_name = var.inference_component_name
  endpoint_name            = aws_sagemaker_endpoint.iris.name
  variant_name             = var.variant_name

  specification = {
    model_name = aws_sagemaker_model.iris.name

    compute_resource_requirements = {
      number_of_cpu_cores_required = var.number_of_cpu_cores_required
      min_memory_required_in_mb    = var.min_memory_required_in_mb
    }
  }

  runtime_config = {
    copy_count = var.initial_copy_count
  }

  tags = [for k, v in var.tags : { key = k, value = v }]

  depends_on = [aws_vpc_endpoint.s3, aws_vpc_endpoint.ecr_api, aws_vpc_endpoint.ecr_dkr]

  lifecycle {
    # Application Auto Scaling manages DesiredCopyCount after creation; avoid
    # fighting it on subsequent `terraform apply` runs.
    ignore_changes = [runtime_config]
  }
}
