data "aws_caller_identity" "current" {}

# flavor_params.network has no security_group_ids field - use the VPC's
# existing default security group instead of creating one or adding a
# variable for it.
data "aws_security_group" "default" {
  vpc_id = var.flavor_params.network.vpc_id

  filter {
    name   = "group-name"
    values = ["default"]
  }
}
