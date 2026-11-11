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

output "delivery_status_function_role_arn" {
  description = "ARN of the delivery status function role."
  value       = aws_iam_role.roles["delivery_status_function"].arn
}

output "delivery_check_function_role_arn" {
  description = "ARN of the delivery check function role."
  value       = aws_iam_role.roles["delivery_check_function"].arn
}

output "push_status_logs_role_arn" {
  description = "ARN of the role SNS uses to write push delivery status, for the success and failure feedback of each platform application."
  value       = aws_iam_role.roles["push_status_logs"].arn
}

output "sms_status_logs_role_arn" {
  description = "ARN of the role End User Messaging SMS uses to write the events of its configuration set."
  value       = aws_iam_role.roles["sms_status_logs"].arn
}

output "endpoint_security_group_ids" {
  description = "IDs of the interface endpoint security groups, keyed iot_data, s3 and private_api, for endpoint_security_group_ids of the network module. Empty while the endpoint groups are off."
  value       = { for key, group in aws_security_group.endpoints : key => group.id }
}
