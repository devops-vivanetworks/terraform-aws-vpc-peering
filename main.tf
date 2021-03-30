# This file contains terraform version constrains, provider definition, and also main resources.
# https://www.terraform.io/docs/configuration/resources.html

terraform {
  required_version = ">= 0.12.0"

  required_providers {
    hashicorp-aws = {
      source = "hashicorp/aws"
      version = "~> 3.0.0"
    }
  }
}

#############
# Requester #
#############

resource "aws_vpc_peering_connection" "connection" {
  count = var.is_requester ? 1 : 0

  vpc_id        = var.vpc_id
  peer_owner_id = var.peer_account_id
  peer_region   = var.peer_vpc_region
  peer_vpc_id   = var.peer_vpc_id
  auto_accept   = false

  tags = merge(
    var.additional_tags,
    map("Name", format("%s-%s", var.requester_account_alias, var.accepter_account_alias)),
    map("ProductDomain", var.product_domain),
    map("Environment", var.environment),
    map("Description", format("VPC peering connection to %s", var.accepter_account_alias)),
    map("ManagedBy", "terraform"),
    map("Side", "requester"))
}

resource "aws_vpc_peering_connection_options" "requester" {
  count = var.is_connection_accepted && var.is_requester ? 1 : 0

  vpc_peering_connection_id = aws_vpc_peering_connection.connection[count.index].id

  requester {
    allow_remote_vpc_dns_resolution  = local.allow_dns_resolution
    allow_classic_link_to_remote_vpc = local.allow_classic_link_connection
    allow_vpc_to_remote_classic_link = local.allow_classic_link_connection
  }
}

############
# Accepter #
############

resource "aws_vpc_peering_connection_accepter" "accepter" {
  count = var.is_requester ? 0 : 1

  vpc_peering_connection_id = var.vpc_peering_connection_id
  auto_accept               = true

  tags = merge(
    var.additional_tags,
    map("Name", format("%s-%s", var.requester_account_alias, var.accepter_account_alias)),
    map("ProductDomain", var.product_domain),
    map("Environment", var.environment),
    map("Description", format("VPC peering connection to %s", var.requester_account_alias)),
    map("ManagedBy", "terraform"),
    map("Side", "accepter"))
}

resource "aws_vpc_peering_connection_options" "accepter" {
  count = var.is_connection_accepted && ! var.is_requester ? 1 : 0

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.accepter[count.index].id

  accepter {
    allow_remote_vpc_dns_resolution  = local.allow_dns_resolution
    allow_classic_link_to_remote_vpc = local.allow_classic_link_connection
    allow_vpc_to_remote_classic_link = local.allow_classic_link_connection
  }
}

############################
# Add route to route table #
############################

resource "aws_route" "route_table_public" {
  for_each = data.aws_route_tables.public.ids

  route_table_id            = each.value
  destination_cidr_block    = var.destination_vpc_cidr_block
  vpc_peering_connection_id = local.vpc_peering_connection_id

  lifecycle {
    ignore_changes = [
      id,
    ]
  }
}

resource "aws_route" "route_table_app" {
  for_each = data.aws_route_tables.app.ids

  route_table_id            = each.value
  destination_cidr_block    = var.destination_vpc_cidr_block
  vpc_peering_connection_id = local.vpc_peering_connection_id

  lifecycle {
    ignore_changes = [
      id,
    ]
  }
}

resource "aws_route" "route_table_data" {
  for_each = data.aws_route_tables.data.ids

  route_table_id            = each.value
  destination_cidr_block    = var.destination_vpc_cidr_block
  vpc_peering_connection_id = local.vpc_peering_connection_id

  lifecycle {
    ignore_changes = [
      id,
    ]
  }
}
