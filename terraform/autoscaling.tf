resource "aws_appautoscaling_target" "inference_component" {
  service_namespace  = "sagemaker"
  resource_id        = "inference-component/${awscc_sagemaker_inference_component.iris.inference_component_name}"
  scalable_dimension = "sagemaker:inference-component:DesiredCopyCount"
  min_capacity       = var.min_copy_count
  max_capacity       = var.max_copy_count

  depends_on = [awscc_sagemaker_inference_component.iris]
}

resource "aws_appautoscaling_policy" "inference_component_target_tracking" {
  name               = "${var.project_name}-target-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.inference_component.service_namespace
  resource_id        = aws_appautoscaling_target.inference_component.resource_id
  scalable_dimension = aws_appautoscaling_target.inference_component.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.scale_to_zero_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "SageMakerInferenceComponentInvocationsPerCopy"
    }
  }
}
