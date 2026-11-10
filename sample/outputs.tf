# Outputs that prove the sample worked.
output "data_key_arn" {
  description = "ARN of the data key."
  value       = module.this.data_key_arn
}

output "objects_key_arn" {
  description = "ARN of the objects key."
  value       = module.this.objects_key_arn
}

output "ingestion_function_role_arn" {
  description = "ARN of the ingestion function role."
  value       = module.this.ingestion_function_role_arn
}

output "iot_rule_role_arn" {
  description = "ARN of the IoT rule role."
  value       = module.this.iot_rule_role_arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose delivery role."
  value       = module.this.firehose_role_arn
}

output "focus_function_role_arn" {
  description = "ARN of the focus confirmation function role."
  value       = module.this.focus_function_role_arn
}
