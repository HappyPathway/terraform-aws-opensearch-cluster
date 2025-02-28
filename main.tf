resource "aws_opensearch_domain" "main" {
  domain_name = var.domain_name

  cluster_config {
    instance_type          = var.cluster_config.instance_type
    instance_count         = var.cluster_config.instance_count
    zone_awareness_enabled = var.cluster_config.zone_awareness_enabled
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 100
  }

  encrypt_at_rest {
    enabled    = var.encrypt_at_rest.enabled
    kms_key_id = var.encrypt_at_rest.kms_key_id
  }

  vpc_options {
    subnet_ids         = var.vpc_options.subnet_ids
    security_group_ids = var.vpc_options.security_group_ids
  }

  advanced_security_options {
    enabled                        = false
    internal_user_database_enabled = false
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