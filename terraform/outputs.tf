output "endpoint_name" {
  description = "Name of the SageMaker endpoint."
  value       = aws_sagemaker_endpoint.iris.name
}

output "inference_component_name" {
  description = "Name of the SageMaker inference component."
  value       = awscc_sagemaker_inference_component.iris.inference_component_name
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution role."
  value       = aws_iam_role.sagemaker_execution.arn
}
