# EC2 build machine — làm Jenkins JNLP agent
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "tls_private_key" "build" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "build" {
  key_name   = "${var.project}-build"
  public_key = tls_private_key.build.public_key_openssh
  tags       = var.tags
}

resource "local_file" "build_private_key" {
  content         = tls_private_key.build.private_key_pem
  filename        = "${path.module}/build-machine-key.pem"
  file_permission = "0600"
}

# IAM instance profile cho EC2: ECR push + EKS describe
resource "aws_iam_role" "build" {
  name = "${var.project}-build"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "build_ecr" {
  role       = aws_iam_role.build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy" "build_eks" {
  name = "build-eks-describe"
  role = aws_iam_role.build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "build" {
  name = "${var.project}-build"
  role = aws_iam_role.build.name
}

resource "aws_security_group" "build" {
  name        = "${var.project}-build-sg"
  description = "Jenkins build machine"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-build-sg" })
}

resource "aws_instance" "build" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.build.id]
  key_name               = aws_key_pair.build.key_name
  iam_instance_profile   = aws_iam_instance_profile.build.name

  associate_public_ip_address = true

  user_data = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y openjdk-21-jre-headless docker.io unzip git curl python3-pip

    # aws CLI v2
    curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip
    unzip -q /tmp/awscli.zip -d /tmp
    /tmp/aws/install

    # kubectl
    curl -fsSL https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl

    usermod -aG docker ubuntu
    systemctl enable --now docker
  EOT

  tags = merge(var.tags, { Name = "${var.project}-build" })
}

output "build_machine_public_ip" {
  value = aws_instance.build.public_ip
}

output "build_machine_ssh_key" {
  value = "${path.module}/build-machine-key.pem"
}
