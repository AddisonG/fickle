terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "fickle-terraform-state"
    key    = "fickle/infra/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# VPC
resource "aws_vpc" "fickle" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true

  tags = {
    Name    = "FickleVPC"
    purpose = "fickle"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "fickle" {
  vpc_id = aws_vpc.fickle.id

  tags = {
    Name    = "FickleIGW"
    purpose = "fickle"
  }
}

# Subnet
resource "aws_subnet" "fickle" {
  vpc_id                          = aws_vpc.fickle.id
  cidr_block                      = "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.fickle.ipv6_cidr_block, 8, 1)
  availability_zone               = "ap-southeast-2b"
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true

  tags = {
    Name    = "FickleSubnet"
    purpose = "fickle"
  }
}

# Route table
resource "aws_route_table" "fickle" {
  vpc_id = aws_vpc.fickle.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fickle.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.fickle.id
  }

  tags = {
    Name    = "FickleRouteTable"
    purpose = "fickle"
  }
}

# Route table association
resource "aws_route_table_association" "fickle" {
  subnet_id      = aws_subnet.fickle.id
  route_table_id = aws_route_table.fickle.id
}

# Security group
resource "aws_security_group" "fickle" {
  name_prefix = "fickle-"
  vpc_id      = aws_vpc.fickle.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "FickleSG"
    purpose = "fickle"
  }
}

# EBS volume for persistent data
resource "aws_ebs_volume" "fickle" {
  availability_zone = "ap-southeast-2b"
  size              = 22
  type              = "gp3"
  final_snapshot    = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name    = "FickleOverlayVolume"
    purpose = "fickle"
    importance = "critical"
  }
}

# IAM role for EC2 instances
resource "aws_iam_role" "fickle" {
  name        = "FickleRole"
  description = "Allows attaching the FickleOverlayVolume, and claiming the Fickle Elastic IP"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "FickleRole"
    purpose = "fickle"
  }
}

# IAM instance profile
resource "aws_iam_instance_profile" "fickle" {
  name = "FickleInstanceProfile"
  role = aws_iam_role.fickle.name

  tags = {
    Name    = "FickleInstanceProfile"
    purpose = "fickle"
  }
}

# IAM policy for Fickle operations
resource "aws_iam_role_policy" "fickle" {
  name = "FicklePolicy"
  role = aws_iam_role.fickle.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ec2:AttachVolume"
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:instance/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeVolumes",
          "ec2:AssignIpv6Addresses"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "ec2:AssociateAddress"
        Resource = [
          "arn:aws:ec2:*:*:elastic-ip/*",
          "arn:aws:ec2:*:*:instance/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "route53domains:UpdateDomainNameservers"
        Resource = "*"
      }
    ]
  })
}

# Launch template
resource "aws_launch_template" "fickle" {
  name          = "FickleTemplate"
  image_id      = "ami-05f998315cca9bfe3"
  instance_type = "t3.small"
  key_name      = "addison-personal"

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    security_groups             = [aws_security_group.fickle.id]
    subnet_id                   = aws_subnet.fickle.id
    ipv6_address_count          = 1
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.fickle.arn
  }

  user_data = base64encode(templatefile("userdata.tpl", {
    volume_id = aws_ebs_volume.fickle.id
    region    = "ap-southeast-2"
  }))

  instance_market_options {
    market_type = "spot"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "FickleInstance"
      purpose = "fickle"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "FickleBaseVolume"
      purpose = "fickle"
    }
  }

  tags = {
    Name    = "FickleTemplate"
    purpose = "fickle"
  }
}

# Outputs
output "launch_template_id" {
  value = aws_launch_template.fickle.id
}

output "subnet_id" {
  value = aws_subnet.fickle.id
}
