terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "fickle-terraform-state"
    key    = "fickle/server/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# Get base infrastructure data
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "fickle-terraform-state"
    key    = "fickle/infra/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Spot fleet request
resource "aws_spot_fleet_request" "fickle" {
  iam_fleet_role                      = "arn:aws:iam::037009365307:role/aws-ec2-spot-fleet-tagging-role"
  allocation_strategy                 = "priceCapacityOptimized"
  target_capacity                     = 1
  terminate_instances_with_expiration = true
  fleet_type                          = "maintain"
  wait_for_fulfillment                = true

  launch_template_config {
    launch_template_specification {
      id      = data.terraform_remote_state.infra.outputs.launch_template_id
      version = "$Latest"
    }

    overrides {
      instance_type     = "t3.small"
      subnet_id         = data.terraform_remote_state.infra.outputs.subnet_id
      weighted_capacity = 1
    }
  }

  tags = {
    Name    = "FickleSpotRequest"
    purpose = "fickle"
  }
}

# Get instance IP (available after spot fleet fulfillment)
data "aws_instances" "fickle" {
  filter {
    name   = "tag:Name"
    values = ["Fickle"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
  depends_on = [aws_spot_fleet_request.fickle]
}

# Outputs
output "spot_fleet_id" {
  value = aws_spot_fleet_request.fickle.id
}

output "instance_ip" {
  value = data.aws_instances.fickle.public_ips[0]
}
