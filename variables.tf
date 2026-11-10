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
  description = "Platform roles keyed by purpose (ingestion_function, iot_rule, firehose_delivery, focus_function), with the final role name and the ARNs each role may reach. The module owns the actions of each purpose."
  type = map(object({
    name                   = string
    queue_arns             = optional(list(string), [])
    write_table_arns       = optional(list(string), [])
    read_table_arns        = optional(list(string), [])
    topic_arns             = optional(list(string), [])
    stream_arns            = optional(list(string), [])
    bucket_arns            = optional(list(string), [])
    object_prefix          = optional(string)
    model_arns             = optional(list(string), [])
    dead_letter_queue_arns = optional(list(string), [])
    log_group_arns         = optional(list(string), [])
    source_arn             = optional(string)
  }))

  validation {
    condition     = toset(keys(var.roles)) == toset(keys(local.role_targets))
    error_message = "roles must hold exactly the purposes ingestion_function, iot_rule, firehose_delivery and focus_function."
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
        for arn in concat(role.queue_arns, role.dead_letter_queue_arns) :
        can(regex("^arn:aws[a-z-]*:sqs:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]{1,80}(\\.fifo)?$", arn))
      ]
    ]))
    error_message = "queue_arns and dead_letter_queue_arns must be full SQS queue ARNs with no wildcard."
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
        for arn in role.topic_arns : can(regex("^arn:aws[a-z-]*:sns:[a-z0-9-]+:[0-9]{12}:[A-Za-z0-9_-]{1,256}(\\.fifo)?$", arn))
      ]
    ]))
    error_message = "topic_arns must be full SNS topic ARNs with no wildcard."
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
      for role in values(var.roles) :
      role.source_arn == null || can(regex("^arn:aws[a-z-]*:iot:[a-z0-9-]+:[0-9]{12}:rule/[A-Za-z0-9_]{1,128}$", role.source_arn))
    ])
    error_message = "source_arn must be an IoT topic rule ARN. Rule names use only letters, digits and underscores."
  }
}
