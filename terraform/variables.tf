variable "project_name" {
  description = "Nom du projet, utilisé comme préfixe pour toutes les ressources"
  type        = string
  default     = "nimbus"
}

variable "environment" {
  description = "Nom de l'environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Région AWS de déploiement"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "CIDR block du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Nombre de zones de disponibilité à utiliser"
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "Version d'EKS"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Types d'instance EC2 pour les worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Nombre minimum de nodes (autoscaling)"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Nombre maximum de nodes (autoscaling)"
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Nombre de nodes au démarrage"
  type        = number
  default     = 2
}
