variable "project_role" {
  type = string
}

variable "model_name" {
  type = string
}

variable "flavor_params" {
  # Intermediate module: just relays this through to modulo-sagemaker/modulo-sagemaker,
  # which has the authoritative, fully-typed schema.
  type = any
}
