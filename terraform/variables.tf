variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used by the provider."
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Prefix used to name every resource created by this stack."
  type        = string
  default     = "iris-ic"
}

# --- Networking (existing VPC) ---------------------------------------------

variable "vpc_id" {
  description = "ID of the existing VPC the endpoint's model will attach to."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs (existing VPC) used in the SageMaker model's VpcConfig."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs (existing VPC) used in the SageMaker model's VpcConfig."
  type        = list(string)
}

# --- Model artifact ----------------------------------------------------------

variable "model_data_url" {
  description = "S3 URI of the packaged model artifact (model.tar.gz), e.g. s3://my-bucket/iris/model.tar.gz."
  type        = string
}

variable "model_artifact_bucket_arn" {
  description = "ARN of the S3 bucket holding the model artifact, used to scope the execution role's S3 permissions."
  type        = string
}

variable "container_image_uri" {
  description = <<-EOT
    Full URI (including tag) of the existing custom inference image (see
    ../container/), e.g.
    123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest.
    This stack does not build, push, or otherwise manage the image or its
    ECR repository - that happens outside this stack, e.g.:
      docker build --platform linux/amd64 --provenance=false --sbom=false \
        -t <image-uri> --push ../container
  EOT
  type        = string
}

# --- Endpoint / Inference Component ------------------------------------------

variable "endpoint_name" {
  description = "Name of the SageMaker endpoint."
  type        = string
  default     = "iris-ic-endpoint"
}

variable "variant_name" {
  description = "Name of the production variant in the endpoint configuration."
  type        = string
  default     = "AllTraffic"
}

variable "inference_component_name" {
  description = "Name of the SageMaker inference component."
  type        = string
  default     = "iris-ic"
}

variable "instance_type" {
  description = "Instance type backing the endpoint's managed-instance-scaling variant."
  type        = string
  default     = "ml.m5.xlarge"
}

variable "max_instance_count" {
  description = "Maximum number of instances the endpoint's managed instance scaling can grow to."
  type        = number
  default     = 2
}

variable "initial_copy_count" {
  description = "Initial DesiredCopyCount for the inference component at creation time."
  type        = number
  default     = 1
}

variable "min_copy_count" {
  description = "Minimum DesiredCopyCount for application autoscaling (0 enables scale-to-zero)."
  type        = number
  default     = 0
}

variable "max_copy_count" {
  description = "Maximum DesiredCopyCount for application autoscaling."
  type        = number
  default     = 2
}

variable "number_of_cpu_cores_required" {
  description = "vCPU cores reserved per inference component copy."
  type        = number
  default     = 1
}

variable "min_memory_required_in_mb" {
  description = "Memory (MB) reserved per inference component copy."
  type        = number
  default     = 1024
}

variable "scale_to_zero_target_value" {
  description = "Target value (invocations per copy per minute) for the target-tracking autoscaling policy."
  type        = number
  default     = 5
}

variable "scale_in_cooldown" {
  description = "Seconds to wait before scaling in (including down to zero) after the last scale-in."
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Seconds to wait before allowing another scale-out."
  type        = number
  default     = 60
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
