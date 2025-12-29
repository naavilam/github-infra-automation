variable "github_owner" { type = string }  # ex: "naavilam" ou sua org
variable "github_repo"  { type = string }  # ex: "infra-automation"
variable "github_ref"   { type = string }  # ex: "refs/heads/main"


data "aws_iam_policy_document" "assume_github" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # restringe a origem (repo + ref)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:ref:${var.github_ref}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.assume_github.json
}