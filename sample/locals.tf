# Transformations of the sample. The final resource names and the payload of the module are built here.
locals {
  prefix     = "${var.client}-${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition
  arn_tail   = "${local.region}:${local.account_id}"

  table_arn      = "arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}"
  queue_arn      = "arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}"
  log_group_arn  = "arn:${local.partition}:logs:${local.arn_tail}:log-group:"
  arn_tail_slash = "${local.region}/${local.account_id}"
  push_app       = "app/GCM/${local.prefix}-push-fcm"
  sms_config_set = "arn:${local.partition}:sms-voice:${local.arn_tail}:configuration-set/${local.prefix}-sms-alerts"

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
      name                  = "${local.prefix}-role-ingest"
      queue_arns            = ["arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}-sqs-ingest"]
      write_table_arns      = ["${local.table_arn}-ddb-readings", "${local.table_arn}-ddb-alerts"]
      read_table_arns       = ["${local.table_arn}-ddb-ranges", "${local.table_arn}-ddb-farms"]
      push_application_arns = ["arn:${local.partition}:sns:${local.arn_tail}:${local.push_app}"]
      send_queue_arns       = ["${local.queue_arn}-sqs-dlvcheck"]
      log_group_arns        = ["${local.log_group_arn}/aws/lambda/${local.prefix}-fn-ingest"]
    }
    iot_rule = {
      name        = "${local.prefix}-role-iotrule"
      queue_arns  = ["arn:${local.partition}:sqs:${local.arn_tail}:${local.prefix}-sqs-ingest"]
      stream_arns = ["arn:${local.partition}:firehose:${local.arn_tail}:deliverystream/${local.prefix}-fh-archive"]
      source_arn  = "arn:${local.partition}:iot:${local.arn_tail}:rule/${replace(local.prefix, "-", "_")}_rule_telemetry"
    }
    firehose_delivery = {
      name            = "${local.prefix}-role-firehose"
      bucket_arns     = ["arn:${local.partition}:s3:::${local.prefix}-s3-archive"]
      glue_table_arns = ["arn:${local.partition}:glue:${local.arn_tail}:table/${replace(local.prefix, "-", "_")}_telemetry/readings"]
    }
    focus_function = {
      name              = "${local.prefix}-role-focus"
      bucket_arns       = ["arn:${local.partition}:s3:::${local.prefix}-s3-flights"]
      object_prefix     = "focus/"
      restricted_prefix = "restricted/"
      model_arns = [
        "arn:${local.partition}:bedrock:${local.arn_tail}:inference-profile/us.amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-east-1::foundation-model/amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-east-2::foundation-model/amazon.nova-2-lite-v1:0",
        "arn:${local.partition}:bedrock:us-west-2::foundation-model/amazon.nova-2-lite-v1:0",
      ]
      write_table_arns = ["arn:${local.partition}:dynamodb:${local.arn_tail}:table/${local.prefix}-ddb-cases"]
      queue_arns       = ["${local.queue_arn}-sqs-focus"]
      event_bus_arns   = ["arn:${local.partition}:events:${local.arn_tail}:event-bus/${local.prefix}-evb-platform"]
      log_group_arns   = ["arn:${local.partition}:logs:${local.arn_tail}:log-group:/aws/lambda/${local.prefix}-fn-focus"]
    }
    focus_delivery = {
      name       = "${local.prefix}-role-focusdlv"
      queue_arns = ["${local.queue_arn}-sqs-focus"]
      source_arn = "arn:${local.partition}:events:${local.arn_tail}:rule/${local.prefix}-evb-platform/${local.prefix}-evr-focus"
    }
    delivery_status_function = {
      name             = "${local.prefix}-role-dlvstat"
      write_table_arns = ["${local.table_arn}-ddb-alerts"]
      log_group_arns   = ["${local.log_group_arn}/aws/lambda/${local.prefix}-fn-dlvstatus"]
    }
    delivery_check_function = {
      name              = "${local.prefix}-role-dlvcheck"
      queue_arns        = ["${local.queue_arn}-sqs-dlvcheck"]
      write_table_arns  = ["${local.table_arn}-ddb-alerts"]
      read_table_arns   = ["${local.table_arn}-ddb-farms"]
      sms_resource_arns = [local.sms_config_set]
      log_group_arns    = ["${local.log_group_arn}/aws/lambda/${local.prefix}-fn-dlvcheck"]
    }
    push_status_logs = {
      name = "${local.prefix}-role-pushlogs"
      log_group_arns = [
        "${local.log_group_arn}sns/${local.arn_tail_slash}/${local.push_app}",
        "${local.log_group_arn}sns/${local.arn_tail_slash}/${local.push_app}/Failure",
      ]
    }
    sms_status_logs = {
      name           = "${local.prefix}-role-smslogs"
      log_group_arns = ["${local.log_group_arn}/aws/sms/${local.prefix}-status"]
      source_arn     = local.sms_config_set
    }
  }
}
