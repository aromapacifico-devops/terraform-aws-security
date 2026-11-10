# Outputs of the module. Each one exposes a single attribute and has a description.
output "data_key_arn" {
  description = "ARN of the data key, for the DynamoDB tables."
  value       = aws_kms_key.keys["data"].arn
}

output "objects_key_arn" {
  description = "ARN of the objects key, for the S3 buckets."
  value       = aws_kms_key.keys["objects"].arn
}

output "ingestion_function_role_arn" {
  description = "ARN of the ingestion function role."
  value       = aws_iam_role.roles["ingestion_function"].arn
}

output "iot_rule_role_arn" {
  description = "ARN of the IoT rule role."
  value       = aws_iam_role.roles["iot_rule"].arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose delivery role."
  value       = aws_iam_role.roles["firehose_delivery"].arn
}

output "focus_function_role_arn" {
  description = "ARN of the focus confirmation function role."
  value       = aws_iam_role.roles["focus_function"].arn
}
