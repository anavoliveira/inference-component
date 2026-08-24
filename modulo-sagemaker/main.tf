module "recursos" {
  source = "./modulo-sagemaker"

  providers = {
    aws.provider-lotus    = aws.provider-lotus
    aws.provider-datamesh = aws.provider-datamesh
    awscc                 = awscc
  }

  project_role  = var.project_role
  model_name    = var.model_name
  flavor_params = var.flavor_params
}
