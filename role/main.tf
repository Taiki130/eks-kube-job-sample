variable "name" {
  description = "IAM role name"
  type        = string
  nullable    = false
}

variable "iam_policies" {
  description = "IAM Policies to attach"
  type        = set(any)
  default     = []
}

variable "iam_tags" {
  description = "Tags to Attach to IAM Role"
  type        = map(any)
  default     = {}
}

variable "eks_oidc_provider_arn" {
  description = "IRSA を利用する EKS の oidc_provider_arn"
  type        = string
  nullable    = false
}

variable "kubernetes_namespace" {
  description = "IRSA を利用する Pod が所属する NameSpace 名"
  type        = string
  nullable    = false
}

variable "kubernetes_service_account" {
  description = "IRSA を利用する Pod にアタッチされた ServiceAccount 名"
  type        = string
  nullable    = false
}

resource "aws_iam_role" "this" {
  name        = var.name
  description = "AWS IAM Role for the Kubernetes service account ${var.kubernetes_service_account}"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringLike = {
              "${replace(var.eks_oidc_provider_arn, "/.*:oidc-provider//", "")}:aud" = "sts.amazonaws.com"
              "${replace(var.eks_oidc_provider_arn, "/.*:oidc-provider//", "")}:sub" = "system:serviceaccount:${var.kubernetes_namespace}:${var.kubernetes_service_account}"
            }
          }
          Effect = "Allow"
          Principal = {
            Federated = var.eks_oidc_provider_arn
          }
        },
      ]
      Version = "2012-10-17"
    }
  )

  force_detach_policies = true
  max_session_duration  = 3600

  tags = try(var.iam_tags, null)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.iam_policies

  role       = aws_iam_role.this.name
  policy_arn = data.aws_iam_role.this[each.value].arn
}

data "aws_iam_role" "this" {
  name = aws_iam_role.this.name
}
