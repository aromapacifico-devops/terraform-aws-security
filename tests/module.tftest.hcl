# Plan-time tests against a mocked provider. They need no AWS account.
mock_provider "aws" {
  alias = "project"
}

variables {
  client      = "fnc"
  project     = "aroma"
  environment = "test"

  keys = {
    data = {
      alias                   = "alias/fnc-aroma-test-kms-data"
      description             = "Data key of the DynamoDB tables"
      deletion_window_in_days = 7
    }
    objects = {
      alias                   = "alias/fnc-aroma-test-kms-objects"
      description             = "Objects key of the S3 buckets"
      deletion_window_in_days = 7
    }
  }

  roles = {
    ingestion_function = {
      name             = "fnc-aroma-test-role-ingest"
      queue_arns       = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-ingest"]
      write_table_arns = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-readings", "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-alerts"]
      read_table_arns  = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges"]
      topic_arns       = ["arn:aws:sns:us-east-1:111122223333:fnc-aroma-test-sns-alerts"]
      log_group_arns   = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-ingest"]
    }
    iot_rule = {
      name        = "fnc-aroma-test-role-iotrule"
      queue_arns  = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-ingest"]
      stream_arns = ["arn:aws:firehose:us-east-1:111122223333:deliverystream/fnc-aroma-test-fh-archive"]
      source_arn  = "arn:aws:iot:us-east-1:111122223333:rule/fnc_aroma_test_rule_telemetry"
    }
    firehose_delivery = {
      name        = "fnc-aroma-test-role-firehose"
      bucket_arns = ["arn:aws:s3:::fnc-aroma-test-s3-archive"]
    }
    focus_function = {
      name                   = "fnc-aroma-test-role-focus"
      bucket_arns            = ["arn:aws:s3:::fnc-aroma-test-s3-flights"]
      object_prefix          = "focus/"
      model_arns             = ["arn:aws:bedrock:us-east-1:111122223333:inference-profile/us.amazon.nova-2-lite-v1:0", "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-2-lite-v1:0"]
      write_table_arns       = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-cases"]
      dead_letter_queue_arns = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus-dlq"]
      log_group_arns         = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-focus"]
    }
  }
}

run "accepts_valid_governance_values" {
  command = plan

  providers = {
    aws.project = aws.project
  }
}

run "rejects_an_unknown_environment" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_an_invalid_client_code" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    client = "FNC"
  }

  expect_failures = [var.client]
}

run "rejects_an_unknown_key_purpose" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    keys = merge(var.keys, { logs = { alias = "alias/fnc-aroma-test-kms-logs", description = "Logs key" } })
  }

  expect_failures = [var.keys]
}

run "rejects_a_deletion_window_below_seven_days" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    keys = merge(var.keys, { data = merge(var.keys.data, { deletion_window_in_days = 6 }) })
  }

  expect_failures = [var.keys]
}

run "rejects_an_unknown_role_purpose" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { admin = { name = "fnc-aroma-test-role-admin" } })
  }

  expect_failures = [var.roles]
}

run "rejects_a_role_missing_a_target" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { iot_rule = merge(var.roles.iot_rule, { stream_arns = [] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_target_the_purpose_does_not_use" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { topic_arns = ["arn:aws:sns:us-east-1:111122223333:fnc-aroma-test-sns-alerts"] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_wildcard_table_arn" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_function = merge(var.roles.focus_function, { write_table_arns = ["arn:aws:dynamodb:us-east-1:111122223333:table/*"] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_bucket_arn_with_an_object_path" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { bucket_arns = ["arn:aws:s3:::fnc-aroma-test-s3-archive/*"] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_role_name_of_29_characters" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { name = "fnc-aroma-test-role-firehose1" }) })
  }

  expect_failures = [var.roles]
}
