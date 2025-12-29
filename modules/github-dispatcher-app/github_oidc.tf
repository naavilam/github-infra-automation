data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint muda raramente; você pode usar este valor comum,
  # mas o ideal é você validar/atualizar quando necessário.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Ajuste: repo "SEU_USER_OU_ORG/SEU_REPO_INFRA"
locals {
  gh_repo = "SEU_OWNER/SEU_REPO"
}

data "aws_iam_policy_document" "gh_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # restrinja pelo repo e branch
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${local.gh_repo}:ref:refs/heads/main",
        # se quiser permitir tags:
        # "repo:${local.gh_repo}:ref:refs/tags/*",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.gh_assume_role.json
}

data "aws_iam_policy_document" "github_actions_policy" {
  statement {
    sid = "ArtifactsBucketRW"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.artifact_bucket}",
      "arn:aws:s3:::${var.artifact_bucket}/*"
    ]
  }

  statement {
    sid = "StartCodeBuild"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = [aws_codebuild_project.lambda_builder.arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-deployer-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_policy.json
}

output "aws_role_to_assume" {
  value = aws_iam_role.github_actions.arn
}