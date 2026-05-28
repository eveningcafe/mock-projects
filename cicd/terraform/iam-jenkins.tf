# IRSA: cho phép Jenkins ServiceAccount assume role qua OIDC provider
data "aws_caller_identity" "current" {}

locals {
  oidc_issuer = replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")
}

data "aws_iam_policy_document" "jenkins_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:jenkins:jenkins"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.cluster_name}-jenkins-sa"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Cho phép `aws eks update-kubeconfig` và gọi EKS API
resource "aws_iam_role_policy" "jenkins_eks" {
  name = "jenkins-eks-describe"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins.arn
}
