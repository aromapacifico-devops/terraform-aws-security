# Calls the module from the parent directory.
module "this" {
  source = "../"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  keys  = local.keys
  roles = local.roles
}
