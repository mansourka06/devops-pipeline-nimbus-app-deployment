variable "project_name" { type = string }
variable "environment" { type = string }
variable "kubernetes_version" { type = string }
variable "cluster_role_arn" { type = string }
variable "node_role_arn" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "node_instance_types" { type = list(string) }
variable "node_min_size" { type = number }
variable "node_max_size" { type = number }
variable "node_desired_size" { type = number }

locals {
  name = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Control plane EKS
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = "${local.name}-eks"
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Logs de contrôle utiles pour l'audit et le debug (visibles dans CloudWatch)
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = { Name = "${local.name}-eks" }
}

# ---------------------------------------------------------------------------
# Provider OIDC — nécessaire pour IRSA (IAM Roles for Service Accounts)
# ---------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# ---------------------------------------------------------------------------
# Node group managé — autoscaling min/max/desired
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-workers"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids   # workers dans les subnets privés uniquement

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "worker"
  }

  # Le Cluster Autoscaler s'appuie sur ce tag pour identifier quel ASG
  # correspond à quel cluster.
  tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${aws_eks_cluster.this.name}" = "owned"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]  # laisse l'autoscaler piloter desired_size
  }
}

# ---------------------------------------------------------------------------
# Add-ons EKS gérés (CNI, CoreDNS, kube-proxy, EBS CSI)
# ---------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"
  depends_on   = [aws_eks_node_group.this]
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  value = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}
