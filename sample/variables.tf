# Input variables of the sample.
variable "client" {
  description = "Client code."
  type        = string
}

variable "project" {
  description = "Project code."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "region" {
  description = "AWS Region of the sample."
  type        = string
}

variable "deploy_role_arn" {
  description = "Role to assume. Leave empty to use the local credentials."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider."
  type        = map(string)
}

variable "key_deletion_window_in_days" {
  description = "Days a deleted key waits before KMS removes it."
  type        = number

  validation {
    condition     = var.key_deletion_window_in_days >= 7 && var.key_deletion_window_in_days <= 30
    error_message = "key_deletion_window_in_days must be from 7 to 30."
  }
}
