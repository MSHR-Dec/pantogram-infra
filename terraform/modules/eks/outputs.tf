data "aws_eks_cluster_auth" "aws_iam_authenticator" {
  name = aws_eks_cluster.cluster.name
}

output "eks_name" {
  value = aws_eks_cluster.cluster.name
}
output "eks_endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}
output "eks_cacert" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}
output "eks_token" {
  value = data.aws_eks_cluster_auth.aws_iam_authenticator.token
}
output "eks_oidc" {
  value = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
