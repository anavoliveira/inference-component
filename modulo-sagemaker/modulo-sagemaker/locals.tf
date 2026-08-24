locals {
  # var.project_role is a role name, not an ARN - build it (the role is
  # pre-existing, not created by this stack).
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_role}"

  model_data_url = "s3://${var.flavor_params.model.s3_bucket}/${trimsuffix(trimprefix(var.flavor_params.model.model_path, "/"), "/")}/${var.flavor_params.model.model_file_name}"

  variant_name             = "AllTraffic"
  endpoint_config_name     = "${var.model_name}-endpoint-config"
  endpoint_name            = "${var.model_name}-endpoint"
  inference_component_name = "${var.model_name}-ic"

  # flavor_params.project doubles as this stack's tagging convention -
  # flavor_params has no separate `tags` field.
  tags = {
    ModelName         = var.flavor_params.project.model_name
    ExperimentId      = var.flavor_params.project.experiment_id
    IdMrm             = var.flavor_params.project.id_mrm
    Condominio        = var.flavor_params.project.condominio
    TechTeamEmail     = var.flavor_params.project.tech_team_email
    OwnerContactEmail = var.flavor_params.project.owner_contact_email
  }
}
