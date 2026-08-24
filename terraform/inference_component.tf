resource "awscc_sagemaker_inference_component" "this" {
  inference_component_name = local.inference_component_name
  endpoint_name            = aws_sagemaker_endpoint.this.name
  variant_name             = local.variant_name

  specification = {
    model_name = aws_sagemaker_model.this.name

    compute_resource_requirements = {
      number_of_cpu_cores_required           = var.flavor_params.autoscaling.compute_resource_requirements.number_of_cpu_cores_required
      min_memory_required_in_mb              = var.flavor_params.autoscaling.compute_resource_requirements.min_memory_required_in_mb
      max_memory_required_in_mb              = var.flavor_params.autoscaling.compute_resource_requirements.max_memory_required_in_mb
      number_of_accelerator_devices_required = var.flavor_params.autoscaling.compute_resource_requirements.number_of_accelerator_devices_required
    }
  }

  runtime_config = {
    copy_count = 1
  }

  tags = [for k, v in local.tags : { key = k, value = v }]

  lifecycle {
    # Application Auto Scaling manages DesiredCopyCount after creation; avoid
    # fighting it on subsequent `terraform apply` runs.
    ignore_changes = [runtime_config]
  }
}
