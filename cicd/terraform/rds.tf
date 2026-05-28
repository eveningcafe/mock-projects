resource "aws_db_subnet_group" "app" {
  name       = "${var.project}-db"
  subnet_ids = module.vpc.private_subnets
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Allow Postgres from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_db_instance" "app" {
  identifier             = "${var.project}-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "appdb"
  username               = "appuser"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = var.tags
}
