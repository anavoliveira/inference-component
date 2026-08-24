resource "aws_appautoscaling_target" "this" {
  provider = aws.provider-lotus

  service_namespace  = "sagemaker"
  resource_id        = "inference-component/${awscc_sagemaker_inference_component.this.inference_component_name}"
  scalable_dimension = "sagemaker:inference-component:DesiredCopyCount"
  min_capacity       = var.flavor_params.autoscaling.min_capacity
  max_capacity       = var.flavor_params.autoscaling.max_capacity

  depends_on = [awscc_sagemaker_inference_component.this]
}

resource "aws_appautoscaling_policy" "this" {
  provider = aws.provider-lotus

  name               = "${var.model_name}-target-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.flavor_params.autoscaling.max_requests_per_minute_per_instance
    scale_in_cooldown  = var.flavor_params.autoscaling.scale_in_cooldown_secs
    scale_out_cooldown = var.flavor_params.autoscaling.scale_out_cooldown_secs

    predefined_metric_specification {
      predefined_metric_type = "SageMakerInferenceComponentInvocationsPerCopy"
    }
  }

  # NOTE: flavor_params.autoscaling.scale_out_from_zero_cooldown_secs has no
  # equivalent argument on aws_appautoscaling_policy / TargetTrackingScaling -
  # the AWS Application Auto Scaling API doesn't expose a separate
  # scale-out-from-zero cooldown distinct from ScaleOutCooldown. Accepted in
  # the variable for interface compatibility but not wired up here.
}
