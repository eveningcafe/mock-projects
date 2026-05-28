variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "cicd-demo"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cicd-demo-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.35"
}

# Node Group
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "desired_nodes" {
  type    = number
  default = 2
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}

variable "node_disk_size" {
  type    = number
  default = 20
}

variable "use_spot_instances" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# Database
variable "db_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Project     = "cicd-demo"
    ManagedBy   = "terraform"
  }
}
