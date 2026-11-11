# Resources of the module. Every resource sets provider = aws.project.
resource "aws_kms_key" "keys" {
  for_each = var.keys
  provider = aws.project

  description             = each.value.description
  enable_key_rotation     = true
  deletion_window_in_days = each.value.deletion_window_in_days
  policy                  = jsonencode(local.key_policies[each.key])

  tags = merge(var.additional_tags, { Name = trimprefix(each.value.alias, "alias/") })
}

resource "aws_kms_alias" "keys" {
  for_each = var.keys
  provider = aws.project

  name          = each.value.alias
  target_key_id = aws_kms_key.keys[each.key].key_id
}

resource "aws_iam_role" "roles" {
  for_each = var.roles
  provider = aws.project

  name               = each.value.name
  assume_role_policy = jsonencode(local.trust_policies[each.key])

  tags = merge(var.additional_tags, { Name = each.value.name })
}

resource "aws_iam_role_policy" "roles" {
  for_each = var.roles
  provider = aws.project

  name = each.value.name
  role = aws_iam_role.roles[each.key].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.role_statements[each.key]
  })
}

resource "aws_iam_role_policies_exclusive" "roles" {
  for_each = var.roles
  provider = aws.project

  role_name    = aws_iam_role.roles[each.key].name
  policy_names = [aws_iam_role_policy.roles[each.key].name]
}

# SG-04. No egress block, so Terraform removes the default allow-all egress rule of each new group.
resource "aws_security_group" "endpoints" {
  #checkov:skip=CKV2_AWS_5:The network module attaches the groups to its interface endpoints, see docs/iac-exceptions.md
  for_each = local.endpoint_groups
  provider = aws.project

  name        = "${local.name_prefix}-sg-vpce-${replace(each.key, "_", "-")}"
  description = "${each.value.rule} ${each.value.label}, TCP 443 from the collection centers only"
  vpc_id      = var.firewall.vpc_id

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-sg-vpce-${replace(each.key, "_", "-")}" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoints" {
  for_each = local.endpoint_ingress
  provider = aws.project

  security_group_id = aws_security_group.endpoints[each.value.group].id
  description       = "${local.endpoint_groups[each.value.group].rule} HTTPS from collection center ${each.value.cidr}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value.cidr

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-sgr-vpce-${replace(each.value.group, "_", "-")}" })
}

# Rules added outside this module are removed at the next apply. Egress stays empty (SG-04).
resource "aws_vpc_security_group_rules_exclusive" "endpoints" {
  for_each = local.endpoint_groups
  provider = aws.project

  security_group_id = aws_security_group.endpoints[each.key].id
  ingress_rule_ids  = [for key, rule in aws_vpc_security_group_ingress_rule.endpoints : rule.id if local.endpoint_ingress[key].group == each.key]
  egress_rule_ids   = []
}

# Telemetry ingress, drone ingress and application subnets. NACL-03 is the final deny every network ACL ends with.
resource "aws_network_acl" "open" {
  #checkov:skip=CKV2_AWS_1:Subnets attach through the subnet IDs the network module passes in, see docs/iac-exceptions.md
  count    = var.firewall == null ? 0 : 1
  provider = aws.project

  vpc_id     = var.firewall.vpc_id
  subnet_ids = var.firewall.open_subnet_ids

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-nacl-ingress" })
}

# NACL-01. HTTPS from each collection center.
resource "aws_network_acl_rule" "center_in" {
  for_each = local.center_rule_numbers
  provider = aws.project

  network_acl_id = aws_network_acl.open[0].id
  rule_number    = each.value
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 443
  to_port        = 443
}

# NACL-02. A network ACL keeps no state, so responses return to the ephemeral ports of the center client.
resource "aws_network_acl_rule" "center_out" {
  for_each = local.center_rule_numbers
  provider = aws.project

  network_acl_id = aws_network_acl.open[0].id
  rule_number    = each.value
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.key
  from_port      = 1024
  to_port        = 65535
}

# NACL-04. Data, object storage, administration and public query subnets. No rule, so the final deny holds.
resource "aws_network_acl" "closed" {
  #checkov:skip=CKV2_AWS_1:Subnets attach through the subnet IDs the network module passes in, see docs/iac-exceptions.md
  count    = var.firewall == null ? 0 : 1
  provider = aws.project

  vpc_id     = var.firewall.vpc_id
  subnet_ids = var.firewall.closed_subnet_ids

  tags = merge(var.additional_tags, { Name = "${local.name_prefix}-nacl-closed" })
}
