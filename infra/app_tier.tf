# App tier: IAM role, launch template, Auto Scaling group, and Application Load Balancer.

# ---------- IAM role for the app instances ----------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "lab-app-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# Lets Systems Manager manage the instance: Session Manager, Patch Manager, Run Command.
resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least privilege: read the app package, nothing else in S3.
data "aws_iam_policy_document" "app_read_artifacts" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/app/*"]
  }
}

# Least privilege: read only this database's secret.
data "aws_iam_policy_document" "app_read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.app.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "app_read_db_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_read_db_secret.json
}

resource "aws_iam_role_policy" "app_read_artifacts" {
  name   = "read-app-artifacts"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_read_artifacts.json
}

resource "aws_iam_instance_profile" "app" {
  name = "lab-app-instance"
  role = aws_iam_role.app.name
}

# ---------- Launch template ----------
# Always the latest Amazon Linux 2023 image, looked up from AWS's public parameter.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "app" {
  name_prefix   = "lab-app-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"

  # No key_name: there is no SSH key. Access is through Session Manager only.

  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  # Require IMDSv2 (session tokens), which blocks a common credential-theft technique.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    bucket   = aws_s3_bucket.artifacts.id
    key      = aws_s3_object.app.key
    region   = "us-east-2"
    app_port = local.app_port
    db_host       = aws_db_instance.app.address
    db_name       = aws_db_instance.app.db_name
    db_secret_arn = aws_db_instance.app.master_user_secret[0].secret_arn
  }))

  # default_tags don't reach instances launched by Auto Scaling, so set them here.
  dynamic "tag_specifications" {
    for_each = ["instance", "volume"]
    content {
      resource_type = tag_specifications.value
      tags = {
        Name        = "lab-app"
        Project     = "aws-platform-lab"
        Owner       = "keith"
        Environment = "lab"
      }
    }
  }

  # A new app.zip changes the template, which triggers an instance refresh below.
  tags = { AppVersion = local.app_zip_hash }
}

# ---------- Application Load Balancer ----------
resource "aws_lb" "app" {
  name               = "lab-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name     = "lab-app-tg"
  port     = local.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.lab.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ---------- Auto Scaling group ----------
resource "aws_autoscaling_group" "app" {
  name                = "lab-app-asg"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 2 # one per availability zone
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  # Replace instances that fail the load balancer's /health check, not just ones that crash.
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Rolling replacement whenever the launch template changes (for example, a new app.zip).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "lab-app"
    propagate_at_launch = true
  }
}

output "app_url" {
  value = "http://${aws_lb.app.dns_name}"
}
