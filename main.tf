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
