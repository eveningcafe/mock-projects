output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.app.address
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.eks_cluster.name}"
}
