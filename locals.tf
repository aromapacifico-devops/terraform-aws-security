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
}
