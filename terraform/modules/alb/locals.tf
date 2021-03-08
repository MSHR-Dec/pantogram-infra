locals {
  kube_config = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${var.eks_endpoint}
    certificate-authority-data: ${var.eks_cacert}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${var.eks_name}"
      env:
        - name: AWS_PROFILE
          value: "${var.aws_profile}"
KUBECONFIG
}

resource "local_file" "kube_config" {
  filename        = "./.kube/config.yaml"
  file_permission = "0644"
  content         = local.kube_config
}
