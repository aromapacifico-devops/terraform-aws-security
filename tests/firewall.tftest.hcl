# Plan-time tests of the cloud firewall rules against a mocked provider. They need no AWS account.
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
      name                   = "fnc-aroma-test-role-focus"
      bucket_arns            = ["arn:aws:s3:::fnc-aroma-test-s3-flights"]
      object_prefix          = "focus/"
      restricted_prefix      = "restricted/"
      model_arns             = ["arn:aws:bedrock:us-east-1:111122223333:inference-profile/us.amazon.nova-2-lite-v1:0", "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-2-lite-v1:0"]
      write_table_arns       = ["arn:aws:dynamodb:us-east-1:111122223333:table/fnc-aroma-test-ddb-cases"]
      dead_letter_queue_arns = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus-dlq"]
      log_group_arns         = ["arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/fnc-aroma-test-fn-focus"]
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

run "creates_no_firewall_by_default" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = length(aws_security_group.endpoints) == 0 && length(aws_vpc_security_group_ingress_rule.endpoints) == 0
    error_message = "No security group may exist without the firewall input."
  }

  assert {
    condition     = output.endpoint_security_group_ids == {}
    error_message = "The endpoint group map must be empty without the firewall input."
  }
}

# Apply against the mocked provider, so the rule IDs owned by each group are known.
run "opens_endpoints_to_three_centers_on_443_only" {
  command = apply

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "prod"
    firewall = {
      vpc_id                 = "vpc-0123456789abcdef0"
      open_subnet_ids        = ["subnet-0a00000000000001a", "subnet-0a00000000000002a", "subnet-0a00000000000003a"]
      closed_subnet_ids      = ["subnet-0b00000000000001b", "subnet-0b00000000000002b"]
      center_cidrs           = ["10.41.3.0/24", "10.41.10.0/24", "10.42.3.0/24", "10.42.10.0/24", "10.43.3.0/24", "10.43.10.0/24"]
      enable_endpoint_groups = true
    }
  }

  assert {
    condition     = toset(keys(aws_security_group.endpoints)) == toset(["iot_data", "s3", "private_api"])
    error_message = "SG-01 to SG-03 must create one group per interface endpoint."
  }

  assert {
    condition     = alltrue([for group in aws_security_group.endpoints : group.vpc_id == "vpc-0123456789abcdef0" && startswith(group.name, "fnc-aroma-prod-sg-vpce-")])
    error_message = "Each group must live in the given VPC and follow the naming pattern."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.endpoints) == 18
    error_message = "Each of the 3 groups needs one rule per center range, 18 in total."
  }

  assert {
    condition = alltrue([
      for rule in aws_vpc_security_group_ingress_rule.endpoints :
      rule.ip_protocol == "tcp" && rule.from_port == 443 && rule.to_port == 443 && contains(var.firewall.center_cidrs, rule.cidr_ipv4)
    ])
    error_message = "Every ingress rule must allow only TCP 443 from a center range."
  }

  assert {
    condition     = alltrue([for exclusive in aws_vpc_security_group_rules_exclusive.endpoints : length(exclusive.ingress_rule_ids) == 6 && length(exclusive.egress_rule_ids) == 0])
    error_message = "Each group must own exactly its 6 ingress rules and no egress rule (SG-04)."
  }

  assert {
    condition     = output.endpoint_security_group_ids == { for key, group in aws_security_group.endpoints : key => group.id }
    error_message = "The output must map each endpoint to its own group."
  }
}

run "skips_endpoint_groups_while_endpoints_are_off" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "dev"
    firewall = {
      vpc_id                 = "vpc-0123456789abcdef0"
      open_subnet_ids        = ["subnet-0a00000000000001a"]
      closed_subnet_ids      = ["subnet-0b00000000000001b"]
      center_cidrs           = []
      enable_endpoint_groups = false
    }
  }

  assert {
    condition     = length(aws_security_group.endpoints) == 0
    error_message = "No endpoint group may exist while the endpoints are off."
  }
}

run "rejects_a_center_range_with_host_bits" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    firewall = {
      vpc_id                 = "vpc-0123456789abcdef0"
      open_subnet_ids        = ["subnet-0a00000000000001a"]
      closed_subnet_ids      = ["subnet-0b00000000000001b"]
      center_cidrs           = ["10.41.3.7/24"]
      enable_endpoint_groups = true
    }
  }

  expect_failures = [var.firewall]
}

run "rejects_an_open_range" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    firewall = {
      vpc_id                 = "vpc-0123456789abcdef0"
      open_subnet_ids        = ["subnet-0a00000000000001a"]
      closed_subnet_ids      = ["subnet-0b00000000000001b"]
      center_cidrs           = ["0.0.0.0/0"]
      enable_endpoint_groups = true
    }
  }

  expect_failures = [var.firewall]
}

run "rejects_a_subnet_both_open_and_closed" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    firewall = {
      vpc_id                 = "vpc-0123456789abcdef0"
      open_subnet_ids        = ["subnet-0a00000000000001a"]
      closed_subnet_ids      = ["subnet-0a00000000000001a"]
      center_cidrs           = ["10.41.3.0/24"]
      enable_endpoint_groups = true
    }
  }

  expect_failures = [var.firewall]
}
