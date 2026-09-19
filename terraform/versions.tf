terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }

  # Backend distant recommandé pour tout usage réel (state partagé + verrou).
  # Décommenter et adapter après avoir créé le bucket S3 + table DynamoDB
  # (voir README.md, section "Bootstrap du backend").
  #
  # backend "s3" {
  #   bucket         = "devops-complete-project-tfstate"
  #   key            = "envs/dev/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "devops-complete-project-tf-locks"
  #   encrypt        = true
  # }
}
