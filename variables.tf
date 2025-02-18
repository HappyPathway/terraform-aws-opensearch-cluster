variable "cluster_config" {
  description = "Configuration block for the cluster"
  type = object({
    engine_version                = optional(string)
    instance_type                = optional(string)
    instance_count               = optional(number)
    zone_awareness_enabled       = optional(bool)
    availability_zone_count      = optional(number)
    dedicated_master_enabled     = optional(bool)
    dedicated_master_type        = optional(string)
    dedicated_master_count       = optional(number)
    warm_enabled                 = optional(bool)
    warm_count                   = optional(number)
    warm_type                    = optional(string)
    cold_storage_options        = optional(object({
      enabled = optional(bool)
    }))
  })
  default = {}
}

variable "domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
}

variable "ebs_options" {
  description = "EBS related options for the domain"
  type = object({
    ebs_enabled = optional(bool)
    volume_type = optional(string)
    volume_size = optional(number)
    iops        = optional(number)
  })
  default = {}
}

variable "encrypt_at_rest" {
  description = "Encrypt at rest options"
  type = object({
    enabled    = optional(bool)
    kms_key_id = optional(string)
  })
  default = {}
}

variable "vpc_options" {
  description = "VPC options for the domain"
  type = object({
    subnet_ids         = optional(list(string))
    security_group_ids = optional(list(string))
  })
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_security_group" {
  description = "Whether to create a security group for the OpenSearch domain"
  type        = bool
  default     = true
}

variable "security_group_config" {
  description = "Security group configuration"
  type = object({
    name        = optional(string)
    description = optional(string)
    vpc_id      = string
    ingress_rules = optional(list(object({
      from_port   = optional(number)
      to_port     = optional(number)
      protocol    = optional(string)
      cidr_blocks = optional(list(string))
      security_groups = optional(list(string))
    })))
  })
  default = null
}

variable "advanced_security_options" {
  description = "Advanced security option configuration"
  type = object({
    enabled                        = optional(bool)
    internal_user_database_enabled = optional(bool)
    master_user_options = optional(object({
      master_user_name     = optional(string)
      master_user_password = optional(string)
      master_user_arn      = optional(string)
    }))
  })
  default = {}
}

variable "iam_role_config" {
  description = "IAM role configuration for OpenSearch"
  type = object({
    create       = optional(bool, true)
    name         = optional(string)
    description  = optional(string)
    policy_arns  = optional(list(string))
    custom_policy_json = optional(string)
  })
  default = {}
}