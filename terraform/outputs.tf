output "endpoint_name" {
  description = "Name of the SageMaker endpoint."
  value       = aws_sagemaker_endpoint.this.name
}

output "inference_component_name" {
  description = "Name of the SageMaker inference component."
  value       = awscc_sagemaker_inference_component.this.inference_component_name
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the (pre-existing) SageMaker execution role."
  value       = local.execution_role_arn
}
