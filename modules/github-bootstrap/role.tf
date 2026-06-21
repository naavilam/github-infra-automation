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

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_owner}/${var.github_repo}:ref:${var.github_ref}",
        "repo:${var.github_owner}/${var.github_repo}:environment:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-deployer"
  assume_role_policy = data.aws_iam_policy_document.assume_github.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions" {

  statement {
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration"
    ]

    resources = [
      "arn:aws:lambda:us-east-2:${data.aws_caller_identity.current.account_id}:function:*-dispatcher"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-deployer-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}