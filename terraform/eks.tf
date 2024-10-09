data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  ####### set this to the AMI-ID output by Packer ####
  custom_ami_id_amd64 = "ami-abc1234567890"
  custom_ami_id_arm64 = "ami-abc1234567890"
  ####################################################
  name            = "webassembly-on-eks"
  cluster_version = "1.31"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example = local.name
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=670aa8a79d48e13e70726b0809ac3add3914b58e"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true
  cluster_ip_family              = "ipv6"
  create_cni_ipv6_iam_policy     = true

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    webassembly_amd64 = {
      attach_cluster_primary_security_group = true
      iam_role_attach_cni_policy            = true
      min_size                              = 2
      max_size                              = 3
      desired_size                          = 2
      instance_types                        = ["c6i.xlarge"]
      ami_type                              = "CUSTOM"
      platform                              = "linux"
      ami_id                                = local.custom_ami_id_amd64
      user_data_template_path               = "${path.module}/templates/user-data.tpl"
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
    webassembly_arm64 = {
      attach_cluster_primary_security_group = true
      iam_role_attach_cni_policy            = true
      min_size                              = 2
      max_size                              = 3
      desired_size                          = 2
      instance_types                        = ["c6g.xlarge"]
      ami_type                              = "CUSTOM"
      platform                              = "linux"
      ami_id                                = local.custom_ami_id_arm64
      user_data_template_path               = "${path.module}/templates/user-data.tpl"
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=4a2809c673afa13097af98c2e3c553da8db766a9"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_ipv6            = true
  create_egress_only_igw = true

  public_subnet_ipv6_prefixes                    = [0, 1, 2]
  public_subnet_assign_ipv6_address_on_creation  = true
  private_subnet_ipv6_prefixes                   = [3, 4, 5]
  private_subnet_assign_ipv6_address_on_creation = true
  intra_subnet_ipv6_prefixes                     = [6, 7, 8]
  intra_subnet_assign_ipv6_address_on_creation   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

module "ecr" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ecr.git?ref=df965a8501c9256c1893bb9d65fc2c037ffa1257"

  repository_name = "wasm-example"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 7 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ecr-microservice" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-ecr.git?ref=df965a8501c9256c1893bb9d65fc2c037ffa1257"

  repository_name = "microservice"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 7 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}