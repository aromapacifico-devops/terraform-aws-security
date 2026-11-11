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
      read_table_arns  = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges", "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-farms"]
      log_group_arns   = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-ingest"]

      push_application_arns = ["arn:aws:sns:us-east-1:111122223333:app/GCM/fnc-aroma-test-push-fcm"]
      send_queue_arns       = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-dlvcheck"]
    }
    iot_rule = {
      name        = "fnc-aroma-test-role-iotrule"
      queue_arns  = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-ingest"]
      stream_arns = ["arn:aws:firehose:us-east-1:111122223333:deliverystream/fnc-aroma-test-fh-archive"]
      source_arn  = "arn:aws:iot:us-east-1:111122223333:rule/fnc_aroma_test_rule_telemetry"
    }
    firehose_delivery = {
      name            = "fnc-aroma-test-role-firehose"
      bucket_arns     = ["arn:aws:s3:::fnc-aroma-test-s3-archive"]
      glue_table_arns = ["arn:aws:glue:us-east-1:111122223333:table/fnc_aroma_test_telemetry/readings"]
    }
    focus_function = {
      name              = "fnc-aroma-test-role-focus"
      bucket_arns       = ["arn:aws:s3:::fnc-aroma-test-s3-flights"]
      object_prefix     = "focus/"
      restricted_prefix = "restricted/"
      model_arns        = ["arn:aws:bedrock:us-east-1:111122223333:inference-profile/us.amazon.nova-2-lite-v1:0", "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-2-lite-v1:0"]
      write_table_arns  = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-cases"]
      queue_arns        = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus"]
      event_bus_arns    = ["arn:aws:events:us-east-1:111122223333:event-bus/fnc-aroma-test-evb-platform"]
      log_group_arns    = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-focus"]
    }
    focus_delivery = {
      name       = "fnc-aroma-test-role-focusdlv"
      queue_arns = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus"]
      source_arn = "arn:aws:events:us-east-1:111122223333:rule/fnc-aroma-test-evb-platform/fnc-aroma-test-evr-focus"
    }
    delivery_status_function = {
      name             = "fnc-aroma-test-role-dlvstat"
      write_table_arns = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-alerts"]
      log_group_arns   = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-dlvstatus"]
    }
    delivery_check_function = {
      name              = "fnc-aroma-test-role-dlvcheck"
      queue_arns        = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-dlvcheck"]
      write_table_arns  = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-alerts"]
      read_table_arns   = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-farms"]
      sms_resource_arns = ["arn:aws:sms-voice:us-east-1:111122223333:configuration-set/fnc-aroma-test-sms-alerts"]
      log_group_arns    = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-dlvcheck"]
    }
    push_status_logs = {
      name = "fnc-aroma-test-role-pushlogs"
      log_group_arns = [
        "arn:aws:logs:us-east-1:111122223333:log-group:sns/us-east-1/111122223333/app/GCM/fnc-aroma-test-push-fcm",
        "arn:aws:logs:us-east-1:111122223333:log-group:sns/us-east-1/111122223333/app/GCM/fnc-aroma-test-push-fcm/Failure",
      ]
    }
    sms_status_logs = {
      name           = "fnc-aroma-test-role-smslogs"
      log_group_arns = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/sms/fnc-aroma-test-status"]
      source_arn     = "arn:aws:sms-voice:us-east-1:111122223333:configuration-set/fnc-aroma-test-sms-alerts"
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
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { send_queue_arns = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-dlvcheck"] }) })
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

run "creates_nine_roles_trusted_by_their_service" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_iam_role.roles) == 9 && aws_iam_role.roles["iot_rule"].name == "fnc-aroma-test-role-iotrule"
    error_message = "Each purpose must create one role with the name the root builds."
  }

  assert {
    condition = alltrue([
      for purpose, service in {
        ingestion_function       = "lambda.amazonaws.com"
        iot_rule                 = "iot.amazonaws.com"
        firehose_delivery        = "firehose.amazonaws.com"
        focus_function           = "lambda.amazonaws.com"
        focus_delivery           = "events.amazonaws.com"
        delivery_status_function = "lambda.amazonaws.com"
        delivery_check_function  = "lambda.amazonaws.com"
        push_status_logs         = "sns.amazonaws.com"
        sms_status_logs          = "sms-voice.amazonaws.com"
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
    condition = jsondecode(aws_iam_role.roles["focus_delivery"].assume_role_policy).Statement[0].Condition == {
      StringEquals = { "aws:SourceAccount" = "111122223333" }
      ArnLike      = { "aws:SourceArn" = "arn:aws:events:us-east-1:111122223333:rule/fnc-aroma-test-evb-platform/fnc-aroma-test-evr-focus" }
    }
    error_message = "The focus delivery role must accept only the focus rule of this account."
  }

  assert {
    condition = jsondecode(aws_iam_role.roles["sms_status_logs"].assume_role_policy).Statement[0].Condition == {
      StringEquals = { "aws:SourceAccount" = "111122223333" }
      ArnLike      = { "aws:SourceArn" = "arn:aws:sms-voice:us-east-1:111122223333:configuration-set/fnc-aroma-test-sms-alerts" }
    }
    error_message = "The SMS status role must accept only the named configuration set of this account."
  }

  assert {
    condition = alltrue([
      for purpose in ["ingestion_function", "firehose_delivery", "focus_function", "delivery_status_function", "delivery_check_function", "push_status_logs"] :
      !contains(keys(jsondecode(aws_iam_role.roles[purpose].assume_role_policy).Statement[0]), "Condition")
    ])
    error_message = "Lambda, Firehose and SNS trust policies carry no condition, as AWS documents them."
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
      for statement in jsondecode(aws_iam_role_policy.roles["ingestion_function"].policy).Statement : statement.Resource if statement.Sid == "ReadRangesAndFarms"
      ][0] == [
      "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges",
      "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-farms",
      "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-ranges/index/*",
      "arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-farms/index/*",
    ]
    error_message = "The ingestion role reads only the ranges and farm tables and their indexes."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Resource if statement.Sid == "ReadAndRemoveFlightObjects"
    ][0] == ["arn:aws:s3:::fnc-aroma-test-s3-flights/focus/*"]
    error_message = "The focus role reads and removes objects only in its prefix."
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

# Apply against the mocked provider, so computed attributes get values. Nothing reaches AWS.
run "exposes_key_and_role_arns" {
  command = apply

  providers = {
    aws.project = aws.project
  }

  override_resource {
    target          = aws_kms_key.keys["data"]
    override_during = apply
    values          = { arn = "arn:aws:kms:us-east-1:111122223333:key/data" }
  }

  override_resource {
    target          = aws_kms_key.keys["objects"]
    override_during = apply
    values          = { arn = "arn:aws:kms:us-east-1:111122223333:key/objects" }
  }

  assert {
    condition     = output.data_key_arn == "arn:aws:kms:us-east-1:111122223333:key/data" && output.objects_key_arn == "arn:aws:kms:us-east-1:111122223333:key/objects"
    error_message = "Key outputs must expose the ARN of each key."
  }

  assert {
    condition = (
      output.ingestion_function_role_arn == aws_iam_role.roles["ingestion_function"].arn &&
      output.iot_rule_role_arn == aws_iam_role.roles["iot_rule"].arn &&
      output.firehose_role_arn == aws_iam_role.roles["firehose_delivery"].arn &&
      output.focus_function_role_arn == aws_iam_role.roles["focus_function"].arn &&
      output.focus_delivery_role_arn == aws_iam_role.roles["focus_delivery"].arn &&
      output.delivery_status_function_role_arn == aws_iam_role.roles["delivery_status_function"].arn &&
      output.delivery_check_function_role_arn == aws_iam_role.roles["delivery_check_function"].arn &&
      output.push_status_logs_role_arn == aws_iam_role.roles["push_status_logs"].arn &&
      output.sms_status_logs_role_arn == aws_iam_role.roles["sms_status_logs"].arn
    )
    error_message = "Each role output must expose the ARN of its own role."
  }

  assert {
    condition = length(toset([
      output.ingestion_function_role_arn, output.iot_rule_role_arn, output.firehose_role_arn, output.focus_function_role_arn,
      output.delivery_status_function_role_arn, output.delivery_check_function_role_arn, output.push_status_logs_role_arn,
      output.sms_status_logs_role_arn, output.focus_delivery_role_arn,
    ])) == 9
    error_message = "Role outputs must be nine different roles."
  }
}

run "lets_the_focus_role_move_objects_with_people" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Resource if statement.Sid == "WriteRestrictedObjects"
    ] == [["arn:aws:s3:::fnc-aroma-test-s3-flights/restricted/*"]]
    error_message = "The focus role writes only to the restricted prefix."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Action if statement.Sid == "UseObjectsKeyThroughS3"
    ] == [["kms:Decrypt", "kms:GenerateDataKey"]]
    error_message = "Copying an encrypted object needs decrypt and generate data key on the objects key."
  }
}

run "rejects_a_restricted_prefix_inside_the_focus_prefix" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_function = merge(var.roles.focus_function, { restricted_prefix = "focus/restricted/" }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_focus_role_without_a_restricted_prefix" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_function = merge(var.roles.focus_function, { restricted_prefix = null }) })
  }

  expect_failures = [var.roles]
}

run "publishes_alerts_only_to_phone_endpoints_of_the_farm" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["ingestion_function"].policy).Statement : statement.Resource if statement.Sid == "PublishToFarmPhones"
    ] == [["arn:aws:sns:us-east-1:111122223333:endpoint/GCM/fnc-aroma-test-push-fcm/*"]]
    error_message = "The ingestion role publishes only to the endpoints of its platform applications."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["ingestion_function"].policy).Statement : statement.Action if statement.Sid == "WriteReadingsAndAlerts"
    ] == [["dynamodb:BatchWriteItem", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]]
    error_message = "Conditional updates of alert state need GetItem and UpdateItem on the written tables."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["ingestion_function"].policy).Statement : statement.Resource if statement.Sid == "SendDeliveryChecks"
    ] == [["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-dlvcheck"]]
    error_message = "The ingestion role sends only to the delivery check queue."
  }
}

run "lets_firehose_read_only_its_archive_schema" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["firehose_delivery"].policy).Statement : statement.Resource if statement.Sid == "ReadArchiveSchema"
      ] == [[
        "arn:aws:glue:us-east-1:111122223333:catalog",
        "arn:aws:glue:us-east-1:111122223333:database/fnc_aroma_test_telemetry",
        "arn:aws:glue:us-east-1:111122223333:table/fnc_aroma_test_telemetry/readings",
    ]]
    error_message = "Format conversion reads only the catalog, the database and the table of the archive."
  }
}

run "lets_the_delivery_functions_record_and_send" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["delivery_status_function"].policy).Statement : statement.Resource if statement.Sid == "FindAlertByMessage"
    ] == [["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-alerts/index/*"]]
    error_message = "The status function queries only the indexes of the alerts table."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["delivery_check_function"].policy).Statement : statement.Resource if statement.Sid == "SendUrgentSms"
    ] == [["arn:aws:sms-voice:us-east-1:111122223333:configuration-set/fnc-aroma-test-sms-alerts"]]
    error_message = "The check function sends SMS only through the listed resources."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["push_status_logs"].policy).Statement : statement.Resource if statement.Sid == "WritePushStatus"
      ] == [[
        "arn:aws:logs:us-east-1:111122223333:log-group:sns/us-east-1/111122223333/app/GCM/fnc-aroma-test-push-fcm:*",
        "arn:aws:logs:us-east-1:111122223333:log-group:sns/us-east-1/111122223333/app/GCM/fnc-aroma-test-push-fcm/Failure:*",
    ]]
    error_message = "SNS writes push status only to the success and failure groups of its application."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["sms_status_logs"].policy).Statement : statement.Resource if statement.Sid == "WriteSmsStatus"
    ] == [["arn:aws:logs:us-east-1:111122223333:log-group:/aws/sms/fnc-aroma-test-status:*"]]
    error_message = "End User Messaging SMS writes only to the SMS status group."
  }
}

run "rejects_a_topic_as_push_application" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { ingestion_function = merge(var.roles.ingestion_function, { push_application_arns = ["arn:aws:sns:us-east-1:111122223333:fnc-aroma-test-sns-alerts"] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_sms_resources_without_a_configuration_set" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { delivery_check_function = merge(var.roles.delivery_check_function, { sms_resource_arns = ["arn:aws:sms-voice:us-east-1:111122223333:pool/pool-1"] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_an_iot_rule_as_source_of_sms_status" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { sms_status_logs = merge(var.roles.sms_status_logs, { source_arn = "arn:aws:iot:us-east-1:111122223333:rule/fnc_aroma_test_rule_telemetry" }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_firehose_role_without_a_glue_table" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { firehose_delivery = merge(var.roles.firehose_delivery, { glue_table_arns = [] }) })
  }

  expect_failures = [var.roles]
}

run "lets_the_focus_function_work_from_its_queue" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Resource if statement.Sid == "ConsumeWorkQueue"
    ] == [["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus"]]
    error_message = "The focus role consumes only its work queue."
  }

  assert {
    condition = !contains(flatten([
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Action
    ]), "sqs:SendMessage")
    error_message = "The focus role sends to no queue, since SQS moves exhausted messages to the dead letter queue."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Action if statement.Sid == "ReadAndRemoveFlightObjects"
    ] == [["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:GetObjectVersion"]]
    error_message = "The focus role reads exact versions and removes them, with no read of the latest version."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement.Action if statement.Sid == "UseDataKeyThroughSqs"
    ] == [["kms:Decrypt"]]
    error_message = "Receiving from the encrypted queue needs only decrypt."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_function"].policy).Statement : statement if statement.Sid == "PublishInferenceCompleted"
      ][0] == {
      Sid       = "PublishInferenceCompleted"
      Effect    = "Allow"
      Action    = ["events:PutEvents"]
      Resource  = ["arn:aws:events:us-east-1:111122223333:event-bus/fnc-aroma-test-evb-platform"]
      Condition = { StringEquals = { "events:detail-type" = "inference.completed" } }
    }
    error_message = "The focus role publishes only inference.completed on the platform bus."
  }

  assert {
    condition     = [for statement in jsondecode(aws_iam_role_policy.roles["focus_delivery"].policy).Statement : statement.Sid] == ["SendToWorkQueue", "UseDataKeyThroughSqs"]
    error_message = "The delivery role only sends to the work queue and uses the data key through SQS."
  }

  assert {
    condition = [
      for statement in jsondecode(aws_iam_role_policy.roles["focus_delivery"].policy).Statement : statement.Resource if statement.Sid == "SendToWorkQueue"
    ] == [["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus"]]
    error_message = "The delivery role sends only to the focus work queue."
  }
}

run "rejects_a_focus_role_without_its_work_queue" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_function = merge(var.roles.focus_function, { queue_arns = [] }) })
  }

  expect_failures = [var.roles]
}

run "rejects_a_delivery_role_bound_to_another_service" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_delivery = merge(var.roles.focus_delivery, { source_arn = "arn:aws:iot:us-east-1:111122223333:rule/fnc_aroma_test_rule_telemetry" }) })
  }

  expect_failures = [var.roles]
}

run "rejects_an_event_bus_wildcard" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    roles = merge(var.roles, { focus_function = merge(var.roles.focus_function, { event_bus_arns = ["arn:aws:events:us-east-1:111122223333:event-bus/*"] }) })
  }

  expect_failures = [var.roles]
}
