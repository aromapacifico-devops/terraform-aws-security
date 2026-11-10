# Local values and transformations of the module.
locals {
  # Targets each role purpose must receive (required) and may receive (allowed).
  role_targets = {
    ingestion_function = {
      required = ["queue_arns", "write_table_arns", "read_table_arns", "topic_arns", "log_group_arns"]
      allowed  = ["queue_arns", "write_table_arns", "read_table_arns", "topic_arns", "log_group_arns"]
    }
    iot_rule = {
      required = ["queue_arns", "stream_arns", "source_arn"]
      allowed  = ["queue_arns", "stream_arns", "source_arn"]
    }
    firehose_delivery = {
      required = ["bucket_arns"]
      allowed  = ["bucket_arns", "log_group_arns"]
    }
    focus_function = {
      required = ["bucket_arns", "object_prefix", "model_arns", "write_table_arns", "dead_letter_queue_arns", "log_group_arns"]
      allowed  = ["bucket_arns", "object_prefix", "model_arns", "write_table_arns", "dead_letter_queue_arns", "log_group_arns"]
    }
  }

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  # Key policy per key. The root statement keeps access under IAM policies, as the AWS default key
  # policy does. Optional service principals may use the key for this account only.
  key_policies = {
    for purpose, key in var.keys : purpose => {
      Version = "2012-10-17"
      Statement = concat(
        [{
          Sid       = "EnableIamPolicies"
          Effect    = "Allow"
          Principal = { AWS = "arn:${local.partition}:iam::${local.account_id}:root" }
          Action    = "kms:*"
          Resource  = "*"
        }],
        length(key.service_principals) == 0 ? [] : [{
          Sid       = "AllowServicesOfThisAccount"
          Effect    = "Allow"
          Principal = { Service = key.service_principals }
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:ReEncryptFrom",
            "kms:ReEncryptTo",
          ]
          Resource  = "*"
          Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
        }]
      )
    }
  }

  role_services = {
    ingestion_function = "lambda.amazonaws.com"
    iot_rule           = "iot.amazonaws.com"
    firehose_delivery  = "firehose.amazonaws.com"
    focus_function     = "lambda.amazonaws.com"
  }

  # Trust policy per role. IoT Core passes the rule ARN, so its role accepts only that rule of this
  # account. AWS documents no such condition for Lambda execution roles or Firehose delivery roles.
  trust_policies = {
    for purpose, role in var.roles : purpose => {
      Version = "2012-10-17"
      Statement = [merge(
        {
          Effect    = "Allow"
          Principal = { Service = local.role_services[purpose] }
          Action    = "sts:AssumeRole"
        },
        purpose != "iot_rule" ? {} : {
          Condition = {
            StringEquals = { "aws:SourceAccount" = local.account_id }
            ArnLike      = { "aws:SourceArn" = role.source_arn }
          }
        }
      )]
    }
  }
}
