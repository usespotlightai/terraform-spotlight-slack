provider "spotlight" {
  url = var.spotlight_url
}

module "slack" {
  source = "../.."

  workspace     = "acme"
  team          = "core"
  spotlight_url = var.spotlight_url

  client_id      = var.slack_client_id
  client_secret  = var.slack_client_secret
  signing_secret = var.slack_signing_secret

  routes = {
    delivery = "C024BE91L"
  }

  post_message_approval = "The message is visible to everyone in the channel."
}

module "slack_disabled" {
  source = "../.."

  create = false

  workspace = "acme"
  team      = "core"
}
