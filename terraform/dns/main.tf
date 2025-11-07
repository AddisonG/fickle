terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "fickle-terraform-state"
    key    = "fickle/dns/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Route53 hosted zone
resource "aws_route53_zone" "fickle" {
  name = "gourluck.click"

  tags = {
    Name    = "FickleHostedZone"
    purpose = "fickle"
  }
}

# Update domain nameservers
resource "aws_route53domains_registered_domain" "fickle" {
  provider    = aws.us_east_1
  domain_name = "gourluck.click"

  name_server {
    name = aws_route53_zone.fickle.name_servers[0]
  }
  name_server {
    name = aws_route53_zone.fickle.name_servers[1]
  }
  name_server {
    name = aws_route53_zone.fickle.name_servers[2]
  }
  name_server {
    name = aws_route53_zone.fickle.name_servers[3]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws route53domains update-domain-nameservers \
        --domain-name gourluck.click \
        --nameservers Name=example.com Name=example.net \
        --region us-east-1
    EOT
  }
}

# Get running Fickle instance
data "aws_instances" "fickle" {
  filter {
    name   = "tag:Name"
    values = ["Fickle"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# DNS records pointing to actual instance IP
resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.fickle.zone_id
  name    = "gourluck.click"
  type    = "A"
  ttl     = 300
  records = [data.aws_instances.fickle.public_ips[0]]
}

resource "aws_route53_record" "apex_ipv6" {
  zone_id = aws_route53_zone.fickle.zone_id
  name    = "gourluck.click"
  type    = "AAAA"
  ttl     = 300
  records = [data.aws_instances.fickle.ipv6_addresses[0]]
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.fickle.zone_id
  name    = "*.gourluck.click"
  type    = "A"
  ttl     = 300
  records = [data.aws_instances.fickle.public_ips[0]]
}

resource "aws_route53_record" "wildcard_ipv6" {
  zone_id = aws_route53_zone.fickle.zone_id
  name    = "*.gourluck.click"
  type    = "AAAA"
  ttl     = 300
  records = [data.aws_instances.fickle.ipv6_addresses[0]]
}

# Outputs
output "instance_ip" {
  value = data.aws_instances.fickle.public_ips[0]
}

output "hosted_zone_id" {
  value = aws_route53_zone.fickle.zone_id
}
