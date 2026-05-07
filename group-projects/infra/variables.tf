variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "group-projects-eks"
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

# Network Configuration - Using existing VPC/Subnet from the other setup
variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
  default     = "vpc-036b914bdf14d227e"
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster (requires at least 2 in different AZs)"
  type        = list(string)
  default     = ["subnet-0c51b6b97f99b69ed", "subnet-095f2eb89045eb289"]  # ap-southeast-1a and 1b
}

# Node Group Configuration - Minimal for cost savings
variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"  # 2 vCPU, 4 GB RAM - better for running workloads
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3  # 3 groups working in parallel + need >=3 for A02 DaemonSet to be meaningful
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 3
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4  # Headroom for A02 StatefulSet (3 redis pods)
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20  # Minimal disk size
}

variable "use_spot_instances" {
  description = "Use Spot instances for cost savings (can be interrupted)"
  type        = bool
  default     = true  # Save ~70% on compute costs
}

# Access Configuration
variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Open to all - restrict in production
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "devops-class"
    ManagedBy   = "terraform"
    Purpose     = "learning"
  }
}

# EBS CSI Driver Configuration
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = "v1.59.0-eksbuild.1"  # Latest stable version for k8s 1.35
}