data "terraform_remote_state" "app" {
  for_each = toset([
    "academic-codex",
    "high-energy",
    "quantum-computing",
    "quantum-materials",
  ])

  backend = "remote"
  config = {
    organization = "GitHub-Space"
    workspaces = { name = each.key }
  }
}

locals {
  backends = {
    for k, st in data.terraform_remote_state.app :
    k => {
      invoke_arn     = st.outputs.dispatcher_invoke_arn
      function_name  = st.outputs.dispatcher_function_name
    }
  }
}