# Local values and transformations of the module.
locals {
  # Targets each role purpose must receive (required) and may receive (allowed).
  role_targets = {
    ingestion_function = {
      required = ["queue_arns", "write_table_arns", "read_table_arns", "push_application_arns", "send_queue_arns", "log_group_arns"]
      allowed  = ["queue_arns", "write_table_arns", "read_table_arns", "push_application_arns", "send_queue_arns", "log_group_arns"]
    }
    iot_rule = {
      required = ["queue_arns", "stream_arns", "source_arn"]
      allowed  = ["queue_arns", "stream_arns", "source_arn"]
    }
    firehose_delivery = {
      required = ["bucket_arns", "glue_table_arns"]
      allowed  = ["bucket_arns", "glue_table_arns", "log_group_arns"]
    }
    focus_function = {
      required = ["queue_arns", "bucket_arns", "object_prefix", "restricted_prefix", "model_arns", "write_table_arns", "event_bus_arns", "log_group_arns"]
      allowed  = ["queue_arns", "bucket_arns", "object_prefix", "restricted_prefix", "model_arns", "write_table_arns", "event_bus_arns", "log_group_arns"]
    }
    focus_delivery = {
      required = ["queue_arns", "source_arn"]
      allowed  = ["queue_arns", "source_arn"]
    }
    delivery_status_function = {
      required = ["write_table_arns", "log_group_arns"]
      allowed  = ["write_table_arns", "log_group_arns"]
    }
    delivery_check_function = {
      required = ["queue_arns", "write_table_arns", "read_table_arns", "sms_resource_arns", "log_group_arns"]
      allowed  = ["queue_arns", "write_table_arns", "read_table_arns", "sms_resource_arns", "log_group_arns"]
    }
    push_status_logs = {
      required = ["log_group_arns"]
      allowed  = ["log_group_arns"]
    }
    sms_status_logs = {
      required = ["log_group_arns", "source_arn"]
      allowed  = ["log_group_arns", "source_arn"]
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
    ingestion_function       = "lambda.amazonaws.com"
    iot_rule                 = "iot.amazonaws.com"
    firehose_delivery        = "firehose.amazonaws.com"
    focus_function           = "lambda.amazonaws.com"
    focus_delivery           = "events.amazonaws.com"
    delivery_status_function = "lambda.amazonaws.com"
    delivery_check_function  = "lambda.amazonaws.com"
    push_status_logs         = "sns.amazonaws.com"
    sms_status_logs          = "sms-voice.amazonaws.com"
  }

  # Purposes whose service passes the ARN of the resource acting for it. IoT Core and EventBridge pass
  # the rule, and End User Messaging SMS passes the configuration set, so those roles accept only that
  # resource of this account. AWS documents no such condition for Lambda, Firehose or SNS delivery
  # status roles.
  source_bound = ["iot_rule", "focus_delivery", "sms_status_logs"]

  # Trust policy per role.
  trust_policies = {
    for purpose, role in var.roles : purpose => {
      Version = "2012-10-17"
      Statement = [merge(
        {
          Effect    = "Allow"
          Principal = { Service = local.role_services[purpose] }
          Action    = "sts:AssumeRole"
        },
        !contains(local.source_bound, purpose) ? {} : {
          Condition = {
            StringEquals = { "aws:SourceAccount" = local.account_id }
            ArnLike      = { "aws:SourceArn" = role.source_arn }
          }
        }
      )]
    }
  }

  key_arns = { for purpose, key in aws_kms_key.keys : purpose => key.arn }
  via      = { for service in ["dynamodb", "s3", "sqs"] : service => "${service}.${local.region}.amazonaws.com" }

  ingestion = var.roles["ingestion_function"]
  iot_rule  = var.roles["iot_rule"]
  firehose  = var.roles["firehose_delivery"]
  focus     = var.roles["focus_function"]
  delivery  = var.roles["focus_delivery"]
  status    = var.roles["delivery_status_function"]
  check     = var.roles["delivery_check_function"]
  push_logs = var.roles["push_status_logs"]
  sms_logs  = var.roles["sms_status_logs"]

  # A platform application arn:...:app/GCM/<name> owns the endpoints arn:...:endpoint/GCM/<name>/<id>.
  push_endpoint_arns = [for arn in local.ingestion.push_application_arns : "${replace(arn, ":app/", ":endpoint/")}/*"]

  # Format conversion reads a table of the Glue catalog, which IAM checks against the catalog, the
  # database and the table.
  glue_schema_arns = distinct(flatten([
    for arn in local.firehose.glue_table_arns : [
      "${regex("^(arn:[^:]+:glue:[^:]+:[0-9]{12}):", arn)[0]}:catalog",
      "${regex("^(arn:[^:]+:glue:[^:]+:[0-9]{12}):", arn)[0]}:database/${regex(":table/([^/]+)/", arn)[0]}",
      arn,
    ]
  ]))

  # KMS actions a principal needs to read and write items of a table under a customer managed key.
  dynamodb_key_actions = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey"]

  # Permission statements per role, from the permission matrix of the card. Every KMS statement
  # names one key of this module and the service that may use it on the role's behalf.
  role_statements = {
    ingestion_function = [
      {
        Sid      = "ConsumeIngestionQueue"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
        Resource = local.ingestion.queue_arns
      },
      {
        # Readings, alert state items and alerts. State items and the delivery fields of an alert change
        # through conditional updates, which need the current item.
        Sid      = "WriteReadingsAndAlerts"
        Effect   = "Allow"
        Action   = ["dynamodb:BatchWriteItem", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = local.ingestion.write_table_arns
      },
      {
        Sid      = "ReadRangesAndFarms"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = concat(local.ingestion.read_table_arns, [for arn in local.ingestion.read_table_arns : "${arn}/index/*"])
      },
      {
        # Alerts go straight to the phone endpoints of a farm, with no topic in between.
        Sid      = "PublishToFarmPhones"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = local.push_endpoint_arns
      },
      {
        Sid      = "SendDeliveryChecks"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = local.ingestion.send_queue_arns
      },
      {
        Sid       = "UseDataKeyThroughSqs"
        Effect    = "Allow"
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["sqs"] } }
      },
      {
        Sid       = "UseDataKeyThroughDynamodb"
        Effect    = "Allow"
        Action    = local.dynamodb_key_actions
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["dynamodb"] } }
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.ingestion.log_group_arns : "${arn}:*"]
      },
    ]

    iot_rule = [
      {
        Sid      = "SendToIngestionQueue"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = local.iot_rule.queue_arns
      },
      {
        Sid       = "UseDataKeyThroughSqs"
        Effect    = "Allow"
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["sqs"] } }
      },
      {
        Sid      = "PutToArchiveStream"
        Effect   = "Allow"
        Action   = ["firehose:PutRecord"]
        Resource = local.iot_rule.stream_arns
      },
    ]

    firehose_delivery = concat(
      [
        {
          Sid      = "WriteArchiveObjects"
          Effect   = "Allow"
          Action   = ["s3:AbortMultipartUpload", "s3:GetObject", "s3:PutObject"]
          Resource = [for arn in local.firehose.bucket_arns : "${arn}/*"]
        },
        {
          Sid      = "ReadArchiveBucket"
          Effect   = "Allow"
          Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
          Resource = local.firehose.bucket_arns
        },
        {
          Sid      = "UseObjectsKeyThroughS3"
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
          Resource = [local.key_arns["objects"]]
          Condition = {
            StringEquals = {
              "kms:ViaService"                   = local.via["s3"]
              "kms:EncryptionContext:aws:s3:arn" = local.firehose.bucket_arns
            }
          }
        },
      ],
      [{
        Sid      = "ReadArchiveSchema"
        Effect   = "Allow"
        Action   = ["glue:GetTable", "glue:GetTableVersion", "glue:GetTableVersions"]
        Resource = local.glue_schema_arns
      }],
      length(local.firehose.log_group_arns) == 0 ? [] : [{
        Sid      = "WriteDeliveryLogs"
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = [for arn in local.firehose.log_group_arns : "${arn}:log-stream:*"]
      }]
    )

    focus_function = [
      {
        Sid      = "ConsumeWorkQueue"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
        Resource = local.focus.queue_arns
      },
      {
        # The function reads the exact version the flight record names. An object with a person is
        # copied to the restricted prefix, then that version is removed from the focus prefix.
        Sid      = "ReadAndRemoveFlightObjects"
        Effect   = "Allow"
        Action   = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:GetObjectVersion"]
        Resource = [for arn in local.focus.bucket_arns : "${arn}/${local.focus.object_prefix}*"]
      },
      {
        Sid      = "WriteRestrictedObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = [for arn in local.focus.bucket_arns : "${arn}/${local.focus.restricted_prefix}*"]
      },
      {
        Sid      = "UseObjectsKeyThroughS3"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [local.key_arns["objects"]]
        Condition = {
          StringEquals = {
            "kms:ViaService"                   = local.via["s3"]
            "kms:EncryptionContext:aws:s3:arn" = local.focus.bucket_arns
          }
        }
      },
      {
        # DetectLabels has no resource type, so IAM accepts only "*" here.
        Sid      = "DetectLabels"
        Effect   = "Allow"
        Action   = ["rekognition:DetectLabels"]
        Resource = ["*"]
      },
      {
        Sid      = "InvokeFocusModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = local.focus.model_arns
      },
      {
        Sid      = "WriteCases"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = local.focus.write_table_arns
      },
      {
        Sid       = "UseDataKeyThroughDynamodb"
        Effect    = "Allow"
        Action    = local.dynamodb_key_actions
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["dynamodb"] } }
      },
      {
        Sid       = "UseDataKeyThroughSqs"
        Effect    = "Allow"
        Action    = ["kms:Decrypt"]
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["sqs"] } }
      },
      {
        Sid       = "PublishInferenceCompleted"
        Effect    = "Allow"
        Action    = ["events:PutEvents"]
        Resource  = local.focus.event_bus_arns
        Condition = { StringEquals = { "events:detail-type" = "inference.completed" } }
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.focus.log_group_arns : "${arn}:*"]
      },
    ]

    # Role the EventBridge rule assumes to put each published flight record on the work queue.
    focus_delivery = [
      {
        Sid      = "SendToWorkQueue"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = local.delivery.queue_arns
      },
      {
        Sid       = "UseDataKeyThroughSqs"
        Effect    = "Allow"
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["sqs"] } }
      },
    ]

    delivery_status_function = [
      {
        Sid      = "RecordDeliveryStatus"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = local.status.write_table_arns
      },
      {
        # The sparse index on push_message_id finds the alert of a status log entry.
        Sid      = "FindAlertByMessage"
        Effect   = "Allow"
        Action   = ["dynamodb:Query"]
        Resource = [for arn in local.status.write_table_arns : "${arn}/index/*"]
      },
      {
        Sid       = "UseDataKeyThroughDynamodb"
        Effect    = "Allow"
        Action    = local.dynamodb_key_actions
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["dynamodb"] } }
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.status.log_group_arns : "${arn}:*"]
      },
    ]

    delivery_check_function = [
      {
        Sid      = "ConsumeDeliveryChecks"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
        Resource = local.check.queue_arns
      },
      {
        Sid      = "RecordDeliveryCheck"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = local.check.write_table_arns
      },
      {
        # The phone number for the SMS stays in the farm record.
        Sid      = "ReadFarmContact"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = local.check.read_table_arns
      },
      {
        Sid      = "SendUrgentSms"
        Effect   = "Allow"
        Action   = ["sms-voice:SendTextMessage"]
        Resource = local.check.sms_resource_arns
      },
      {
        Sid       = "UseDataKeyThroughSqs"
        Effect    = "Allow"
        Action    = ["kms:Decrypt"]
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["sqs"] } }
      },
      {
        Sid       = "UseDataKeyThroughDynamodb"
        Effect    = "Allow"
        Action    = local.dynamodb_key_actions
        Resource  = [local.key_arns["data"]]
        Condition = { StringEquals = { "kms:ViaService" = local.via["dynamodb"] } }
      },
      {
        Sid      = "WriteOwnLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.check.log_group_arns : "${arn}:*"]
      },
    ]

    # SNS writes the delivery status of each push to its success and failure log groups.
    push_status_logs = [
      {
        Sid      = "CreatePushStatusGroups"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = local.push_logs.log_group_arns
      },
      {
        Sid      = "WritePushStatus"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.push_logs.log_group_arns : "${arn}:*"]
      },
    ]

    # End User Messaging SMS writes the events of its configuration set to the SMS status log group.
    sms_status_logs = [
      {
        Sid      = "DescribeSmsStatusStreams"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogStreams"]
        Resource = concat(local.sms_logs.log_group_arns, [for arn in local.sms_logs.log_group_arns : "${arn}:*"])
      },
      {
        Sid      = "WriteSmsStatus"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [for arn in local.sms_logs.log_group_arns : "${arn}:*"]
      },
    ]
  }
}

# Permanent cloud firewall rules of docs/security/firewall-policy.md.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  center_cidrs = try(var.firewall.center_cidrs, [])

  # SG-01 to SG-03. One group per interface endpoint, present only while the endpoints are.
  endpoint_groups = try(var.firewall.enable_endpoint_groups, false) ? {
    iot_data    = { rule = "SG-01", label = "IoT Core data endpoint" }
    s3          = { rule = "SG-02", label = "S3 interface endpoint" }
    private_api = { rule = "SG-03", label = "private API endpoint" }
  } : {}

  # NACL-01 and NACL-02 rule number of each center range, in input order.
  center_rule_numbers = { for index, cidr in local.center_cidrs : cidr => 100 + index * 10 }

  # One ingress rule per group and center range, TCP 443 only.
  endpoint_ingress = {
    for pair in setproduct(keys(local.endpoint_groups), local.center_cidrs) :
    "${pair[0]} ${pair[1]}" => { group = pair[0], cidr = pair[1] }
  }
}
