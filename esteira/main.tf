module "teste-sagemaker" {
  source = "git::https.../modulo-sagemaker"

  flavor_params = ... # preencher com o objeto real do flavor

  providers = {
    aws.provider-lotus    = aws.provider-lotus
    aws.provider-datamesh = aws.provider-datamesh
    awscc                 = awscc
  }
}
