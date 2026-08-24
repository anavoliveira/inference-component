variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Leave as \"\" to use ambient/environment credentials (e.g. in CI)."
  type        = string
  default     = ""
}

variable "project_role" {
  description = "Name of the existing SageMaker execution role (not created by this stack)."
  type        = string
  default     = "itau-mlops-sagemakerstudio-user-execution-role"
}

variable "model_name" {
  description = "Nome do projeto"
  type        = string
}

variable "flavor_params" {
  description = "Consolidated flavor parameters - see ../../terraform/variables.tf for the authoritative schema."
  type = object({
    project = object({
      model_name          = string
      experiment_id       = string
      id_mrm              = string
      condominio          = string
      tech_team_email     = string
      owner_contact_email = string
    })

    network = object({
      vpc_id     = string
      subnet_ids = list(string)
    })

    model = object({
      model_path      = string
      model_file_name = string
      s3_bucket       = string
    })

    image_uri              = string
    inference_environment  = optional(map(string), {})
    instance_type          = string
    initial_instance_count = optional(number, 1)
    volume_size_in_gb      = optional(number, 30)

    data_capture = optional(object({
      mode       = optional(string, "InputAndOutput")
      percentage = optional(number, 100)
    }))

    autoscaling = optional(object({
      min_capacity                         = number
      max_capacity                         = number
      max_requests_per_minute_per_instance = number
      scale_in_cooldown_secs               = optional(number, 600)
      scale_out_cooldown_secs              = optional(number, 300)
      scale_out_from_zero_cooldown_secs    = optional(number, 60)

      compute_resource_requirements = optional(object({
        min_memory_required_in_mb              = optional(number, 1024)
        max_memory_required_in_mb              = optional(number)
        number_of_cpu_cores_required           = optional(number, 1)
        number_of_accelerator_devices_required = optional(number)
      }), {})
    }))

    explainer_config = optional(object({
      clarify_explainer_config = optional(object({
        inference_config = optional(object({
          feature_headers       = optional(list(string))
          feature_attribute     = optional(string)
          feature_types         = optional(list(string))
          max_record_count      = optional(number)
          max_payload_in_mb     = optional(number)
          probability_index     = optional(number)
          label_index           = optional(number)
          probability_attribute = optional(string)
          label_attribute       = optional(string)
          content_template      = optional(string)
        }))
        shap_config = object({
          shap_baseline_config = object({
            mime_type         = optional(string)
            shap_baseline     = optional(string)
            shap_baseline_uri = optional(string)
          })
          number_of_samples = optional(number)
          use_logit         = optional(bool)
          seed              = optional(number)
          text_config = optional(object({
            language    = string # en, de, es, fr, it, pt, etc.
            granularity = string # token, sentence, paragraph
          }))
        })
      }))
    }))

    pos_inference = optional(object({
      image_uri               = string
      instance_type           = string
      instance_count          = string
      volume_size_in_gb       = string
      emit_cloudwatch_metrics = optional(string, "false")
      create_infra            = optional(bool, false)
    }))

    data_mesh = optional(object({
      table_name          = optional(string, "")
      spec_db_source_name = optional(string, "")
      spec_db_corp_name   = optional(string, "")
      spec_s3bucket       = optional(string, "")
      pos_inference_kms   = optional(string, "")
      match_database      = optional(map(list(string)), {})
      expressions_columns = optional(list(object({
        name = string
        type = string
      })), [])
    }))
  })
}
