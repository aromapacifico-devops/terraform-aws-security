# Plan-time tests against a mocked provider. They need no AWS account.
mock_provider "aws" {
  alias = "project"

  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "111122223333" }
  }

  override_data {
    target = data.aws_partition.current
    values = { partition = "aws" }
  }

  override_data {
    target = data.aws_region.current
    values = { region = "us-east-1" }
  }

  override_resource {
    target          = aws_kms_key.keys["data"]
    override_during = plan
    values          = { arn = "arn:aws:kms:us-east-1:111122223333:key/data" }
  }

  override_resource {
    target          = aws_kms_key.keys["objects"]
    override_during = plan
    values          = { arn = "arn:aws:kms:us-east-1:111122223333:key/objects" }
  }
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

run "creates_two_rotating_keys_with_aliases" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_kms_key.keys) == 2 && alltrue([for key in aws_kms_key.keys : key.enable_key_rotation])
    error_message = "Both keys must exist with rotation on."
  }

  assert {
    condition     = aws_kms_key.keys["data"].deletion_window_in_days == 7 && aws_kms_key.keys["objects"].deletion_window_in_days == 7
    error_message = "The deletion window must come from the input."
  }

  assert {
    condition     = aws_kms_alias.keys["data"].name == "alias/fnc-aroma-test-kms-data" && aws_kms_alias.keys["objects"].name == "alias/fnc-aroma-test-kms-objects"
    error_message = "Aliases must match the names the root builds."
  }

  assert {
    condition     = aws_kms_key.keys["data"].tags["Name"] == "fnc-aroma-test-kms-data"
    error_message = "Each key must carry a Name tag."
  }

  assert {
    condition = jsondecode(aws_kms_key.keys["data"].policy).Statement == [{
      Sid       = "EnableIamPolicies"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::111122223333:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
    error_message = "Without service principals the key policy holds only the account root statement."
  }
}

run "lets_listed_services_of_this_account_use_a_key" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    keys = merge(var.keys, { data = merge(var.keys.data, { service_principals = ["logs.us-east-1.amazonaws.com"] }) })
  }

  assert {
    condition     = jsondecode(aws_kms_key.keys["data"].policy).Statement[1].Principal.Service == ["logs.us-east-1.amazonaws.com"]
    error_message = "The listed service must be the principal of the second statement."
  }

  assert {
    condition     = jsondecode(aws_kms_key.keys["data"].policy).Statement[1].Condition.StringEquals["aws:SourceAccount"] == "111122223333"
    error_message = "Service use must be limited to this account."
  }

  assert {
    condition     = length(jsondecode(aws_kms_key.keys["objects"].policy).Statement) == 1
    error_message = "A key without service principals must not gain a service statement."
  }
}

run "creates_four_roles_trusted_by_their_service" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_iam_role.roles) == 4 && aws_iam_role.roles["iot_rule"].name == "fnc-aroma-test-role-iotrule"
    error_message = "Each purpose must create one role with the name the root builds."
  }

  assert {
    condition = alltrue([
      for purpose, service in {
        ingestion_function = "lambda.amazonaws.com"
        iot_rule           = "iot.amazonaws.com"
        firehose_delivery  = "firehose.amazonaws.com"
        focus_function     = "lambda.amazonaws.com"
      } : jsondecode(aws_iam_role.roles[purpose].assume_role_policy).Statement[0].Principal.Service == service
    ])
    error_message = "Each role must trust only its own service."
  }

  assert {
    condition = jsondecode(aws_iam_role.roles["iot_rule"].assume_role_policy).Statement[0].Condition == {
      StringEquals = { "aws:SourceAccount" = "111122223333" }
      ArnLike      = { "aws:SourceArn" = "arn:aws:iot:us-east-1:111122223333:rule/fnc_aroma_test_rule_telemetry" }
    }
    error_message = "The IoT rule role must accept only the named rule of this account."
  }

  assert {
    condition = alltrue([
      for purpose in ["ingestion_function", "firehose_delivery", "focus_function"] :
      !contains(keys(jsondecode(aws_iam_role.roles[purpose].assume_role_policy).Statement[0]), "Condition")
    ])
    error_message = "Lambda and Firehose trust policies carry no condition, as AWS documents them."
  }

  assert {
    condition     = alltrue([for role in values(aws_iam_role.roles) : length(jsondecode(role.assume_role_policy).Statement) == 1])
    error_message = "Each trust policy must hold a single statement."
  }
}

run "grants_least_privilege_per_role" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = alltrue(flatten([
      for policy in values(aws_iam_role_policy.roles) : [
        for statement in jsondecode(policy.policy).Statement : [for action in statement.Action : !strcontains(action, "*")]
      ]
    ]))
    error_message = "No action may hold a wildcard."
  }

  assert {
    condition = [
      for statement in flatten([for policy in values(aws_iam_role_policy.roles) : jsondecode(policy.policy).Statement]) :
      statement.Sid if contains(statement.Resource, "*")
    ] == ["DetectLabels"]
    error_message = "Only DetectLabels of the focus role may use the resource *."
  }

  assert {
    condition = alltrue([
      for statement in flatten([for policy in values(aws_iam_role_policy.roles) : jsondecode(policy.policy).Statement]) :
      can(statement.Condition.StringEquals["kms:ViaService"]) && alltrue([
        for arn in statement.Resource : contains(["arn:aws:kms:us-east-1:111122223333:key/data", "arn:aws:kms:us-east-1:111122223333:key/objects"], arn)
      ])
      if anytrue([for action in statement.Action : startswith(action, "kms:")])
    ])
    error_message = "KMS statements may reach only this module's keys and only through a named service."
  }

  assert {
    condition = alltrue(flatten([
      for policy in values(aws_iam_role_policy.roles) : [
        for statement in jsondecode(policy.policy).Statement : [
          for action in statement.Action : !startswith(action, "kms:") || length(statement.Resource) == 1
        ]
      ]
    ]))
    error_message = "Each KMS statement must name a single key."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["ingestion_function"].policy).Statement : statement.Resource if statement.Sid == "ReadRanges"
    ][0] == ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges", "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges/index/*"]
    error_message = "The ingestion role reads only the ranges table and its indexes."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Resource if statement.Sid == "ReadFlightObjects"
    ][0] == ["arn:aws:s3:::fnc-aroma-test-s3-flights/focus/*"]
    error_message = "The focus role reads only its prefix."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["firehose_delivery"].policy).Statement :
      statement.Condition.StringEquals["kms:EncryptionContext:aws:s3:arn"] if statement.Sid == "UseObjectsKeyThroughS3"
    ][0] == ["arn:aws:s3:::fnc-aroma-test-s3-archive"]
    error_message = "Firehose may use the objects key only for the archive bucket."
  }

  assert {
    condition     = !contains([for statement in jsondecode(aws_iam_role_policy.roles["firehose_delivery"].policy).Statement : statement.Sid], "WriteDeliveryLogs")
    error_message = "Without log groups the Firehose role holds no log permission."
  }

  assert {
    condition     = alltrue([for purpose, exclusive in aws_iam_role_policies_exclusive.roles : exclusive.policy_names == toset([var.roles[purpose].name])])
    error_message = "Each role must hold only its own inline policy."
  }
}

run "lets_firehose_write_delivery_logs_when_asked" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { log_group_arns = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/kinesisfirehose/fnc-aroma-test-fh-archive"] }) })
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["firehose_delivery"].policy).Statement : statement.Resource if statement.Sid == "WriteDeliveryLogs"
    ] == [["arn:aws:logs:us-east-1:111122223333:log-group:/aws/kinesisfirehose/fnc-aroma-test-fh-archive:log-stream:*"]]
    error_message = "Firehose writes only to the streams of its log group."
  }
}
