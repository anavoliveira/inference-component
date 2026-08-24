output "endpoint_name" {
  value = module.inference_component.endpoint_name
}

output "inference_component_name" {
  value = module.inference_component.inference_component_name
}

output "sagemaker_execution_role_arn" {
  value = module.inference_component.sagemaker_execution_role_arn
}
