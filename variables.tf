# Input variables of the module.
variable "client" {
  description = "Client code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.client))
    error_message = "client must be 1 to 10 lowercase alphanumeric characters."
  }
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,15}$", var.project))
    error_message = "project must be 1 to 15 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "additional_tags" {
  description = "Tags added to the resources of this module, on top of the provider default tags."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.additional_tags) : length(trimspace(key)) > 0])
    error_message = "additional_tags keys cannot be empty."
  }
}

variable "keys" {
  description = "KMS keys of the environment, keyed by purpose (data, objects). The root builds each alias."
  type = map(object({
    alias                   = string
    description             = string
    deletion_window_in_days = optional(number, 30)
    service_principals      = optional(list(string), [])
  }))

  validation {
    condition     = toset(keys(var.keys)) == toset(["data", "objects"])
    error_message = "keys must hold exactly the purposes data and objects."
  }

  validation {
    condition = alltrue([
      for key in values(var.keys) :
      can(regex("^alias/[a-zA-Z0-9/_-]{1,250}$", key.alias)) && !startswith(key.alias, "alias/aws/")
    ])
    error_message = "Each alias must start with alias/, use letters, digits, /, _ or -, and not start with alias/aws/."
  }

  validation {
    condition     = alltrue([for key in values(var.keys) : length(trimspace(key.description)) > 0])
    error_message = "Each key needs a description."
  }

  validation {
    condition = alltrue([
      for key in values(var.keys) :
      key.deletion_window_in_days >= 7 && key.deletion_window_in_days <= 30 && floor(key.deletion_window_in_days) == key.deletion_window_in_days
    ])
    error_message = "deletion_window_in_days must be a whole number from 7 to 30."
  }

  validation {
    condition = alltrue(flatten([
      for key in values(var.keys) : [
        for principal in key.service_principals : can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)*\\.amazonaws\\.com$", principal))
      ]
    ]))
    error_message = "service_principals must be AWS service principals such as logs.us-east-1.amazonaws.com."
  }
}

variable "roles" {
  description = "Platform roles keyed by purpose (ingestion_function, iot_rule, firehose_delivery, focus_function, focus_delivery, delivery_status_function, delivery_check_function, push_status_logs, sms_status_logs), with the final role name and the ARNs each role may reach. The module owns the actions of each purpose."
  type = map(object({
    name                  = string
    queue_arns            = optional(list(string), [])
    write_table_arns      = optional(list(string), [])
    read_table_arns       = optional(list(string), [])
    send_queue_arns       = optional(list(string), [])
    push_application_arns = optional(list(string), [])
    glue_table_arns       = optional(list(string), [])
    sms_resource_arns     = optional(list(string), [])
    stream_arns           = optional(list(string), [])
    bucket_arns           = optional(list(string), [])
    object_prefix         = optional(string)
    restricted_prefix     = optional(string)
    model_arns            = optional(list(string), [])
    event_bus_arns        = optional(list(string), [])
    log_group_arns        = optional(list(string), [])
    source_arn            = optional(string)
  }))

  validation {
    condition     = toset(keys(var.roles)) == toset(keys(local.role_targets))
    error_message = "roles must hold exactly the purposes ingestion_function, iot_rule, firehose_delivery, focus_function, focus_delivery, delivery_status_function, delivery_check_function, push_status_logs and sms_status_logs."
  }

  validation {
    condition = alltrue(flatten([
      for purpose, role in var.roles : [
        for target in try(local.role_targets[purpose].required, []) : try(length(role[target]), 0) > 0
      ]
    ]))
    error_message = "A role is missing a target its purpose needs. See local.role_targets for the targets of each purpose."
  }

  validation {
    condition = alltrue(flatten([
      for purpose, role in var.roles : [
        for target, value in role :
        target == "name" || contains(try(local.role_targets[purpose].allowed, []), target) || try(length(value), 0) == 0
      ]
    ]))
    error_message = "A role sets a target its purpose does not use."
  }

  validation {
    condition     = alltrue([for role in values(var.roles) : can(regex("^[a-z0-9-]{1,28}$", role.name))])
    error_message = "Each role name must be 1 to 28 lowercase letters, digits or hyphens."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in concat(role.queue_arns, role.send_queue_arns) :
        can(regex("^arn:aws[a-z-]*:sqs:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]{1,80}(\\.fifo)?$", arn))
      ]
    ]))
    error_message = "queue_arns and send_queue_arns must be full SQS queue ARNs with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.event_bus_arns : can(regex("^arn:aws[a-z-]*:events:[a-z0-9-]+:[0-9]{12}:event-bus/[A-Za-z0-9._-]{1,256}$", arn))
      ]
    ]))
    error_message = "event_bus_arns must be full EventBridge event bus ARNs with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in concat(role.write_table_arns, role.read_table_arns) :
        can(regex("^arn:aws[a-z-]*:dynamodb:[a-z0-9-]+:[0-9]{12}:table/[A-Za-z0-9_.-]{3,255}$", arn))
      ]
    ]))
    error_message = "write_table_arns and read_table_arns must be full DynamoDB table ARNs with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.push_application_arns : can(regex("^arn:aws[a-z-]*:sns:[a-z0-9-]+:[0-9]{12}:app/(GCM|APNS|APNS_SANDBOX)/[A-Za-z0-9_.-]{1,256}$", arn))
      ]
    ]))
    error_message = "push_application_arns must be SNS platform application ARNs for GCM, APNS or APNS_SANDBOX, with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.glue_table_arns : can(regex("^arn:aws[a-z-]*:glue:[a-z0-9-]+:[0-9]{12}:table/[a-z0-9_]{1,255}/[a-z0-9_]{1,255}$", arn))
      ]
    ]))
    error_message = "glue_table_arns must be Glue table ARNs, table/<database>/<table>, with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.sms_resource_arns :
        can(regex("^arn:aws[a-z-]*:sms-voice:[a-z0-9-]+:[0-9]{12}:(configuration-set|phone-number|pool|sender-id)/[A-Za-z0-9_./-]{1,128}$", arn))
      ]
    ]))
    error_message = "sms_resource_arns must be End User Messaging SMS configuration set, phone number, pool or sender ID ARNs, with no wildcard."
  }

  validation {
    condition = alltrue([
      for role in values(var.roles) :
      length(role.sms_resource_arns) == 0 || anytrue([for arn in role.sms_resource_arns : strcontains(arn, ":configuration-set/")])
    ])
    error_message = "sms_resource_arns must include the configuration set that records the SMS events."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.stream_arns : can(regex("^arn:aws[a-z-]*:firehose:[a-z0-9-]+:[0-9]{12}:deliverystream/[A-Za-z0-9_.-]{1,64}$", arn))
      ]
    ]))
    error_message = "stream_arns must be full Firehose delivery stream ARNs with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.bucket_arns : can(regex("^arn:aws[a-z-]*:s3:::[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", arn))
      ]
    ]))
    error_message = "bucket_arns must be S3 bucket ARNs, with no object path and no wildcard."
  }

  validation {
    condition = alltrue([
      for role in values(var.roles) :
      role.object_prefix == null || can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/$", role.object_prefix))
    ])
    error_message = "object_prefix must be a relative path that ends with / and holds no wildcard, such as flights/focus/."
  }

  validation {
    condition = alltrue([
      for role in values(var.roles) :
      role.restricted_prefix == null || can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/$", role.restricted_prefix))
    ])
    error_message = "restricted_prefix must be a relative path that ends with / and holds no wildcard, such as restricted/."
  }

  validation {
    condition = alltrue([
      for role in values(var.roles) :
      role.object_prefix == null || role.restricted_prefix == null || (
        !startswith(coalesce(role.object_prefix, "-"), coalesce(role.restricted_prefix, "-")) &&
        !startswith(coalesce(role.restricted_prefix, "-"), coalesce(role.object_prefix, "-"))
      )
    ])
    error_message = "object_prefix and restricted_prefix must not contain each other, so a moved object never lands where it is read."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.model_arns :
        can(regex("^arn:aws[a-z-]*:bedrock:[a-z0-9-]+:([0-9]{12})?:(inference-profile|foundation-model)/[A-Za-z0-9.:_-]+$", arn))
      ]
    ]))
    error_message = "model_arns must be Bedrock inference profile or foundation model ARNs with no wildcard."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.roles) : [
        for arn in role.log_group_arns : can(regex("^arn:aws[a-z-]*:logs:[a-z0-9-]+:[0-9]{12}:log-group:[A-Za-z0-9_/.#-]{1,512}$", arn))
      ]
    ]))
    error_message = "log_group_arns must be CloudWatch log group ARNs without the trailing :* and with no wildcard."
  }

  validation {
    condition = alltrue([
      for purpose, role in var.roles :
      role.source_arn == null || (
        purpose == "iot_rule" ? can(regex("^arn:aws[a-z-]*:iot:[a-z0-9-]+:[0-9]{12}:rule/[A-Za-z0-9_]{1,128}$", role.source_arn)) :
        purpose == "focus_delivery" ? can(regex("^arn:aws[a-z-]*:events:[a-z0-9-]+:[0-9]{12}:rule/([A-Za-z0-9._-]{1,256}/)?[A-Za-z0-9._-]{1,64}$", role.source_arn)) :
        purpose == "sms_status_logs" ? can(regex("^arn:aws[a-z-]*:sms-voice:[a-z0-9-]+:[0-9]{12}:configuration-set/[A-Za-z0-9_-]{1,64}$", role.source_arn)) :
        false
      )
    ])
    error_message = "source_arn must be the IoT topic rule ARN for iot_rule, with only letters, digits and underscores in the name, the EventBridge rule ARN for focus_delivery, or the End User Messaging SMS configuration set ARN for sms_status_logs."
  }
}

variable "firewall" {
  description = "Permanent cloud firewall rules of the environment. vpc_id and the subnet IDs come from the network module. open_subnet_ids are the telemetry ingress, drone ingress and application subnets, closed_subnet_ids the data, object storage, administration and public query subnets. center_cidrs are the source ranges of the linked collection centers. enable_endpoint_groups creates the groups of the interface endpoints, and follows enable_private_endpoints of the network module. Null creates nothing."
  type = object({
    vpc_id                 = string
    open_subnet_ids        = list(string)
    closed_subnet_ids      = list(string)
    center_cidrs           = list(string)
    enable_endpoint_groups = bool
  })
  default = null

  validation {
    condition     = var.firewall == null || can(regex("^vpc-[0-9a-f]{8,17}$", var.firewall.vpc_id))
    error_message = "firewall.vpc_id must be a VPC ID such as vpc-0123456789abcdef0."
  }

  validation {
    condition     = var.firewall == null || (length(var.firewall.open_subnet_ids) > 0 && length(var.firewall.closed_subnet_ids) > 0)
    error_message = "firewall needs at least one open subnet and one closed subnet."
  }

  validation {
    condition = var.firewall == null || alltrue([
      for subnet in concat(var.firewall.open_subnet_ids, var.firewall.closed_subnet_ids) : can(regex("^subnet-[0-9a-f]{8,17}$", subnet))
    ])
    error_message = "firewall subnet IDs must look like subnet-0123456789abcdef0."
  }

  validation {
    condition     = var.firewall == null || length(setintersection(var.firewall.open_subnet_ids, var.firewall.closed_subnet_ids)) == 0
    error_message = "A subnet cannot be open and closed at the same time."
  }

  validation {
    condition = var.firewall == null || alltrue([
      for cidr in var.firewall.center_cidrs : try(cidrhost(cidr, 0) == split("/", cidr)[0] && tonumber(split("/", cidr)[1]) >= 16, false)
    ])
    error_message = "center_cidrs must be IPv4 network ranges of /16 or narrower, such as 10.41.3.0/24."
  }

  validation {
    condition     = var.firewall == null || length(distinct(var.firewall.center_cidrs)) == length(var.firewall.center_cidrs)
    error_message = "center_cidrs cannot repeat a range."
  }

  validation {
    condition     = var.firewall == null || length(var.firewall.center_cidrs) <= 20
    error_message = "center_cidrs holds at most 20 ranges, so the ACL rule numbers stay within one block."
  }
}
