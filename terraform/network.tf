# The model and endpoint config run inside var.subnet_ids with no NAT gateway.
# SageMaker-managed ENIs in a VPC don't get a public IP, so without this the
# instance can reach neither S3 (to download model.tar.gz) nor other AWS
# services over the private network. Gateway endpoints are free and add no
# infrastructure to maintain.
#
# var.subnet_ids have no explicit route table association (data "aws_route_table"
# filtered by subnet_id returns nothing for them), so they use the VPC's main
# route table implicitly - look that up directly instead.
data "aws_route_table" "main" {
  vpc_id = var.vpc_id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [data.aws_route_table.main.id]

  tags = var.tags
}

# Pulling our own image from a private ECR repo (instead of an AWS-managed
# framework image) also needs the ECR API + Docker Registry interface
# endpoints - private ECR repos aren't reachable through the same
# platform-internal path AWS-managed images use.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true

  tags = var.tags
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true

  tags = var.tags
}
