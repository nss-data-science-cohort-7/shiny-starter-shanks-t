# provider "aws" {
#   region = "us-east-1"
# }

# locals {
#   region = "us-east-1"
#   name   = "ex-${basename(path.cwd)}"

#   #   vpc_cidr = "10.0.0.0/16"
#   azs = module.vpc.azs

#   container_name = "shiny"
#   container_port = 3838

#   tags = {
#     Name       = local.name
#     Example    = local.name
#     Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
#   }
# }

# module "vpc" {
#   source = "terraform-aws-modules/vpc/aws"

#   name = "my-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = ["us-east-1a", "us-east-1b"]
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

#   enable_nat_gateway = true
#   enable_vpn_gateway = true

#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }

# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "~> 9.0"

#   name = local.name

#   load_balancer_type = "application"

#   vpc_id  = module.vpc.vpc_id
#   subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

#   # For example only
#   enable_deletion_protection = false

#   # Security Group
#   security_group_ingress_rules = {
#     all_http = {
#       from_port   = 80
#       to_port     = 80
#       ip_protocol = "tcp"
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#   }
#   security_group_egress_rules = {
#     all = {
#       ip_protocol = "-1"
#       cidr_ipv4   = "0.0.0.0/0"
#     }
#   }

#   listeners = {
#     ex_http = {
#       port     = 80
#       protocol = "HTTP"

#       forward = {
#         target_group_key = "ex_ecs"
#       }
#     }
#   }

#   target_groups = {
#     ex_ecs = {
#       backend_protocol                  = "HTTP"
#       backend_port                      = local.container_port
#       target_type                       = "ip"
#       deregistration_delay              = 5
#       load_balancing_cross_zone_enabled = true

#       health_check = {
#         enabled             = true
#         healthy_threshold   = 2
#         interval            = 300
#         matcher             = "200-299"
#         path                = "/"
#         port                = "traffic-port"
#         protocol            = "HTTP"
#         timeout             = 120
#         unhealthy_threshold = 2
#       }

#       # There's nothing to attach here in this definition. Instead,
#       # ECS will attach the IPs of the tasks to this target group
#       create_attachment = false
#     }
#   }

#   tags = local.tags
# }

# module "ecs_cluster" {
#   source = "terraform-aws-modules/ecs/aws//modules/cluster"

#   cluster_name = "ecs-fargate"

#   cluster_configuration = {
#     execute_command_configuration = {
#       logging = "OVERRIDE"
#       log_configuration = {
#         cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
#       }
#     }
#   }

#   fargate_capacity_providers = {
#     FARGATE = {
#       default_capacity_provider_strategy = {
#         weight = 50
#       }
#     }
#     FARGATE_SPOT = {
#       default_capacity_provider_strategy = {
#         weight = 50
#       }
#     }
#   }

#   tags = {
#     Environment = "Development"
#     Project     = "EcsEc2"
#   }
# }

# module "ecs_service" {
#   source = "terraform-aws-modules/ecs/aws//modules/service"

#   name        = "shiny"
#   cluster_arn = module.ecs_cluster.arn

#   cpu    = 256
#   memory = 512

#   # Container definition(s)
#   container_definitions = {

#     shiny = {
#       cpu       = 256
#       memory    = 512
#       essential = true
#       image     = "127293717875.dkr.ecr.us-east-1.amazonaws.com/shiny:latest"
#       port_mappings = [
#         {
#           name          = "shiny"
#           containerPort = 80
#           protocol      = "tcp"
#         }
#       ]

#       # Example image used requires access to write to root filesystem
#       readonly_root_filesystem = false

#       enable_cloudwatch_logging = true
#       memory_reservation        = 100
#     }
#   }

#   load_balancer = {
#     service = {
#       target_group_arn = module.alb.target_groups["ex_ecs"].arn
#       container_name   = "shiny"
#       container_port   = 80
#     }
#   }

#   subnet_ids = module.vpc.private_subnets
#   security_group_rules = {
#     alb_ingress_3000 = {
#       type                     = "ingress"
#       from_port                = 80
#       to_port                  = 80
#       protocol                 = "tcp"
#       description              = "Service port"
#       source_security_group_id = module.alb.security_group_id
#     }
#     egress_all = {
#       type        = "egress"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   }

#   tags = {
#     Environment = "dev"
#     Terraform   = "true"
#   }
# }


# TODO: ADD DNS name, 
# add HTTPS certs, 
# modularize resources to that they are well organized andeasy to understand 
# consider what other services/architectures that can allow adding features to app 

terraform {
  required_version = "~> 1.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  container_name = "shiny"
  container_port = 3838 # ! Must be same EXPOSED port from our Dockerfile
  example        = "shiny-example"
  image_uri      = "127293717875.dkr.ecr.us-east-1.amazonaws.com/shiny"
}

variable "IMAGE_TAG" {
  default = "latest"
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = { example = local.example }
  }
}

data "aws_caller_identity" "this" {}
data "aws_ecr_authorization_token" "this" {}
data "aws_region" "this" {}


# * Create an AWS Virtual Private Cloud (VPC).
resource "aws_vpc" "this" { cidr_block = "10.0.0.0/16" }

# * Create Security Groups that will allow future resources to make and receive
# * requests from the internet (e.g. people can visit the application).
resource "aws_security_group" "http" {
  description = "Permit incoming HTTP traffic"
  name        = "http"
  vpc_id      = resource.aws_vpc.this.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "TCP"
    to_port     = 80
  }
}
resource "aws_security_group" "https" {
  description = "Permit incoming HTTPS traffic"
  name        = "https"
  vpc_id      = resource.aws_vpc.this.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    protocol    = "TCP"
    to_port     = 443
  }
}
resource "aws_security_group" "egress_all" {
  description = "Permit all outgoing traffic"
  name        = "egress-all"
  vpc_id      = resource.aws_vpc.this.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}
resource "aws_security_group" "ingress_api" {
  description = "Permit some incoming traffic"
  name        = "ingress-esc-service"
  vpc_id      = resource.aws_vpc.this.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = local.container_port
    protocol    = "TCP"
    to_port     = local.container_port
  }
}

# * AWS requires the use multiple Availability Zones and we only want to use
# * ones the are up and running so we find those ones here.
data "aws_availability_zones" "available" { state = "available" }

# * Create an Internet Gateway so that future resources running inside our VPC
# * can connect to the interent.
resource "aws_internet_gateway" "this" { vpc_id = resource.aws_vpc.this.id }

# * Create public subnetworks (Public Subnets) that are exposed to the interent
# * to make and take requests.
resource "aws_route_table" "public" { vpc_id = resource.aws_vpc.this.id }
resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = resource.aws_internet_gateway.this.id
  route_table_id         = resource.aws_route_table.public.id
}
resource "aws_subnet" "public" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(resource.aws_vpc.this.cidr_block, 8, count.index)
  vpc_id            = resource.aws_vpc.this.id
}
resource "aws_route_table_association" "public" {
  for_each = { for k, v in resource.aws_subnet.public : k => v.id }

  route_table_id = resource.aws_route_table.public.id
  subnet_id      = each.value
}

# *  make private subnetworks (Private Subnets) that will
# * need to connect to external websites on the internet. To do this, we must
# * create a NAT Gateway that will route those requests from our Private Subnet
# * through our Public Subnets to actually reach those external websites.
resource "aws_eip" "this" { domain = "vpc" }
resource "aws_nat_gateway" "this" {
  allocation_id = resource.aws_eip.this.id
  subnet_id     = resource.aws_subnet.public[0].id # Just route all requests through one of our Public Subnets.

  depends_on = [resource.aws_internet_gateway.this]
}

# * Create Private Subnets on our VPC. This acts like an isolated sandbox
# * the ECS Service runs inside of. Any requests to and
# * from the broader internet will be filtered throught our Public Subnets
# * and the NAT Gateway.
resource "aws_route_table" "private" { vpc_id = resource.aws_vpc.this.id }
resource "aws_route" "private" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = resource.aws_nat_gateway.this.id # Connect to NAT Gateway, not Internet Gateway
  route_table_id         = resource.aws_route_table.private.id
}
resource "aws_subnet" "private" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(resource.aws_vpc.this.cidr_block, 8, count.index + length(resource.aws_subnet.public)) # Avoid conflicts with Public Subnets
  vpc_id            = resource.aws_vpc.this.id
}
resource "aws_route_table_association" "private" {
  # https://github.com/hashicorp/terraform/issues/22476#issuecomment-547689853
  for_each = { for k, v in resource.aws_subnet.private : k => v.id }

  route_table_id = resource.aws_route_table.private.id
  subnet_id      = each.value
}

# * Create an AWS Application Load Balancer that accepts HTTP requests (on port 80) and
# * forwards those requests to port 8080 (container port) on the VPC 
resource "aws_lb" "this" {
  load_balancer_type = "application"

  depends_on = [resource.aws_internet_gateway.this]

  security_groups = [
    resource.aws_security_group.egress_all.id,
    resource.aws_security_group.http.id,
    resource.aws_security_group.https.id,
  ]

  subnets = resource.aws_subnet.public[*].id
}
resource "aws_lb_target_group" "this" {
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = resource.aws_vpc.this.id

  depends_on = [resource.aws_lb.this]
  # Health check settings
  health_check {
    interval            = 300 # Time between health checks
    path                = "/" # URL path to use for health checks
    timeout             = 100 # Amount of time during which no response means a failed health check
    healthy_threshold   = 3   # Number of consecutive successful health checks before marking as healthy
    unhealthy_threshold = 2   # Number of consecutive failed health checks before marking as unhealthy
    matcher             = "200-299"
  }
}
resource "aws_lb_listener" "this" {
  load_balancer_arn = resource.aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}

resource "aws_ecs_cluster" "this" { name = "${local.example}-cluster" }
resource "aws_ecs_cluster_capacity_providers" "this" {
  capacity_providers = ["FARGATE"]
  cluster_name       = resource.aws_ecs_cluster.this.name
}

data "aws_iam_policy_document" "this" {
  version = "2012-10-17"

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}
resource "aws_iam_role" "this" { assume_role_policy = data.aws_iam_policy_document.this.json }
resource "aws_iam_role_policy_attachment" "default" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = resource.aws_iam_role.this.name
}
resource "aws_ecs_task_definition" "this" {
  container_definitions = jsonencode([{
    environment : [
      { name = "MY_INPUT_ENV_VAR", value = "terraform-modified-env-var" }
    ],
    essential    = true,
    image        = "${local.image_uri}:${var.IMAGE_TAG}",
    name         = local.container_name,
    portMappings = [{ containerPort = local.container_port }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-region"        = "us-east-1",
        "awslogs-group"         = "plotly",
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
  cpu                      = 256
  execution_role_arn       = aws_iam_role.this.arn
  family                   = "family-of-${local.example}-tasks"
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}


resource "aws_ecs_service" "this" {
  cluster         = resource.aws_ecs_cluster.this.id
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = "${local.example}-service"
  task_definition = resource.aws_ecs_task_definition.this.arn

  lifecycle {
    ignore_changes = [desired_count] # Allow external changes to happen without Terraform conflicts, particularly around auto-scaling.
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = local.container_port
    target_group_arn = resource.aws_lb_target_group.this.arn
  }

  network_configuration {
    security_groups = [
      resource.aws_security_group.egress_all.id,
      resource.aws_security_group.ingress_api.id,
    ]
    subnets = resource.aws_subnet.private[*].id
  }
}

# * Output the URL of Application Load Balancer to connect to
# * the application running inside  ECS
output "lb_url" { value = "http://${resource.aws_lb.this.dns_name}" }