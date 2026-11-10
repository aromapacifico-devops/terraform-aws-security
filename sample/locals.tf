# Transformations of the sample. The final resource names and the payload of the module are built here.
locals {
  prefix     = "${var.client}-${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition
  arn_tail   = "${local.region}:${local.account_id}"

  keys = {
    data = {
      alias                   = "alias/${local.prefix}-kms-data"
      description             = "Data key of the DynamoDB tables"
      deletion_window_in_days = var.key_deletion_window_in_days
    }
    objects = {
      alias                   = "alias/${local.prefix}-kms-objects"
      description             = "Objects key of the S3 buckets"
      deletion_window_in_days = var.key_deletion_window_in_days
    }
  }

  roles = {
    ingestion_function = {
      name             = "${local.prefix}-role-ingest"
      queue_arns       = ["arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}-sqs-ingest"]
      write_table_arns = ["arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}-ddb-readings", "arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}-ddb-alerts"]
      read_table_arns  = ["arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}-ddb-ranges"]
      topic_arns       = ["arn:${local.partition}:sns:${local.arn_tail}:${local.prefix}-sns-alerts"]
      log_group_arns   = ["arn:${local.partition}:logs:${local.arn_tail}:log-group:/aws/lambda/${local.prefix}-fn-ingest"]
    }
    iot_rule = {
      name        = "${local.prefix}-role-iotrule"
      queue_arns  = ["arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}-sqs-ingest"]
      stream_arns = ["arn:${local.partition}:firehose:${local.arn_tail}:deliverystream/${local.prefix}-fh-archive"]
      source_arn  = "arn:${local.partition}:iot:${local.arn_tail}:rule/${replace(local.prefix, "-", "_")}_rule_telemetry"
    }
    firehose_delivery = {
      name        = "${local.prefix}-role-firehose"
      bucket_arns = ["arn:${local.partition}:s3:::${local.prefix}-s3-archive"]
    }
    focus_function = {
      name          = "${local.prefix}-role-focus"
      bucket_arns   = ["arn:${local.partition}:s3:::${local.prefix}-s3-flights"]
      object_prefix = "focus/"
      model_arns = [
        "arn:${local.partition}:bedrock:${local.arn_tail}:inference-profile/us.amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-east-1::foundation-model/amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-east-2::foundation-model/amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-west-2::foundation-model/amazon.nova-2-lite-v1:0",
      ]
      write_table_arns       = ["arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}-ddb-cases"]
      dead_letter_queue_arns = ["arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}-sqs-focus-dlq"]
      log_group_arns         = ["arn:${local.partition}:logs:${local.arn_tail}:log-group:/aws/lambda/${local.prefix}-fn-focus"]
    }
  }
}
