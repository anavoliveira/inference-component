# Criação dos recursos - dividida em arquivos por assunto (o Terraform não
# se importa com nomes de arquivo, apenas concatena todo *.tf do diretório):
#   variables.tf              - project_role, model_name, flavor_params
#   locals.tf                 - valores derivados (execution role ARN, tags, nomes)
#   data.tf                   - aws_caller_identity, security group default
#   model.tf                  - aws_sagemaker_model
#   endpoint.tf                - endpoint config (via AWS CLI/terraform_data) + aws_sagemaker_endpoint
#   inference_component.tf     - awscc_sagemaker_inference_component
#   autoscaling.tf              - aws_appautoscaling_target/policy (scale to zero)
#   outputs.tf                 - endpoint_name, inference_component_name, execution role
