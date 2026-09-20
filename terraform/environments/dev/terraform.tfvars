project_name       = "devops-nimbus-app"
environment        = "dev"
aws_region         = "eu-west-1"
vpc_cidr           = "10.0.0.0/16"
az_count           = 3
kubernetes_version = "1.30"

node_instance_types = ["t3.medium"]
node_min_size       = 2
node_max_size       = 6
node_desired_size   = 2
