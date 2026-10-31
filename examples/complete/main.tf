provider "spotlight" {
  url = var.spotlight_url
}

module "slack" {
  source = "../.."

  workspace     = "acme"
  team          = "core"
  spotlight_url = var.spotlight_url

  signing_secret = var.slack_signing_secret
  bot_token      = var.slack_bot_token

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
