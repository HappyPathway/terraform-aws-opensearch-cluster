resource "aws_opensearch_domain" "main" {
  domain_name = var.domain_name

  dynamic "cluster_config" {
    for_each = var.cluster_config != null ? [var.cluster_config] : []
    content {
      instance_type                = cluster_config.value.instance_type
      instance_count               = cluster_config.value.instance_count
      zone_awareness_enabled       = cluster_config.value.zone_awareness_enabled
      dedicated_master_enabled     = cluster_config.value.dedicated_master_enabled
      dedicated_master_type        = cluster_config.value.dedicated_master_type
      dedicated_master_count       = cluster_config.value.dedicated_master_count
      warm_enabled                 = cluster_config.value.warm_enabled
      warm_count                   = cluster_config.value.warm_count
      warm_type                    = cluster_config.value.warm_type

      dynamic "cold_storage_options" {
        for_each = cluster_config.value.cold_storage_options != null ? [cluster_config.value.cold_storage_options] : []
        content {
          enabled = cold_storage_options.value.enabled
        }
      }
    }
  }

  dynamic "ebs_options" {
    for_each = var.ebs_options != null ? [var.ebs_options] : []
    content {
      ebs_enabled = ebs_options.value.ebs_enabled
      volume_type = ebs_options.value.volume_type
      volume_size = ebs_options.value.volume_size
      iops        = ebs_options.value.iops
    }
  }

  dynamic "encrypt_at_rest" {
    for_each = var.encrypt_at_rest != null ? [var.encrypt_at_rest] : []
    content {
      enabled    = encrypt_at_rest.value.enabled
      kms_key_id = encrypt_at_rest.value.kms_key_id
    }
  }

  dynamic "vpc_options" {
    for_each = var.vpc_options != null ? [var.vpc_options] : []
    content {
      subnet_ids         = vpc_options.value.subnet_ids
      security_group_ids = concat(
        coalesce(vpc_options.value.security_group_ids, []),
        var.create_security_group && var.security_group_config != null ? [aws_security_group.opensearch[0].id] : []
      )
    }
  }

  dynamic "advanced_security_options" {
    for_each = var.advanced_security_options != null ? [var.advanced_security_options] : []
    content {
      enabled                        = advanced_security_options.value.enabled
      internal_user_database_enabled = advanced_security_options.value.internal_user_database_enabled

      dynamic "master_user_options" {
        for_each = advanced_security_options.value.master_user_options != null ? [advanced_security_options.value.master_user_options] : []
        content {
          master_user_name     = master_user_options.value.master_user_name
          master_user_password = master_user_options.value.master_user_password
          master_user_arn      = master_user_options.value.master_user_arn
        }
      }
    }
  }

  tags = var.tags

  depends_on = [aws_iam_role.opensearch]
}

resource "aws_security_group" "opensearch" {
  count       = var.create_security_group && var.security_group_config != null ? 1 : 0
  name        = coalesce(var.security_group_config.name, "${var.domain_name}-opensearch-sg")
  description = coalesce(var.security_group_config.description, "Security group for OpenSearch domain ${var.domain_name}")
  vpc_id      = var.security_group_config.vpc_id

  dynamic "ingress" {
    for_each = var.security_group_config.ingress_rules != null ? var.security_group_config.ingress_rules : []
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      security_groups  = ingress.value.security_groups
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = coalesce(var.security_group_config.name, "${var.domain_name}-opensearch-sg")
  })
}

resource "aws_iam_role" "opensearch" {
  count = var.iam_role_config.create ? 1 : 0
  name  = coalesce(var.iam_role_config.name, "${var.domain_name}-opensearch-role")
  description = coalesce(var.iam_role_config.description, "IAM role for OpenSearch domain ${var.domain_name}")

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "opensearch.amazonaws.com"
        }
      }
    ]
  })

  dynamic "inline_policy" {
    for_each = var.iam_role_config.custom_policy_json != null ? [1] : []
    content {
      name   = "${var.domain_name}-custom-policy"
      policy = var.iam_role_config.custom_policy_json
    }
  }

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "opensearch" {
  for_each = var.iam_role_config.create ? toset(coalesce(var.iam_role_config.policy_arns, [])) : []
  
  role       = aws_iam_role.opensearch[0].name
  policy_arn = each.value
}