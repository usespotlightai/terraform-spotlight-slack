output "id" {
  description = "The integration's ID."
  value       = try(spotlight_integration.this[0].id, null)
}

output "address" {
  description = "The integration's address in the workspace, as in `core/slack`."
  value       = try(spotlight_integration.this[0].address, null)
}

output "tools" {
  description = "The integration's tools, by name, to the name a station or hook gives it by, as in `{ post-message = \"slack.post-message\" }`."
  value       = try(spotlight_integration.this[0].tools, {})
}

output "webhook_url" {
  description = "The request URL to give in the Slack app's event subscriptions."
  value       = var.create ? local.webhook_url : null
}

output "happenings" {
  description = "The happenings the integration raises: `mentioned` when someone mentions the app, `replied` when someone replies in a thread, `clicked` when someone clicks a button of the app."
  value = {
    mentioned = "${var.integration}.app_mention"
    replied   = "${var.integration}.message.replied"
    clicked   = "${var.integration}.block_actions"
  }
}

output "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  value       = var.create ? local.signing_secret_name : null
}

output "client_secret_name" {
  description = "The name of the workspace secret that holds the client secret."
  value       = var.create ? local.client_secret_name : null
}

output "callback_url" {
  description = "The redirect URL to give your Slack app, under OAuth & Permissions."
  value       = var.create ? local.callback_url : null
}

output "manifest" {
  description = "A Slack app manifest, as JSON, with the redirect URL, the bot scopes, the events and the interactivity that the integration needs. Paste it when you create the app from a manifest, or on the app's App Manifest page. Known also with `create` false, so you can create the app first."
  value = jsonencode({
    display_information = { name = var.name }
    features = {
      bot_user = { display_name = var.name, always_online = true }
    }
    oauth_config = {
      redirect_urls = [local.callback_url]
      scopes        = { bot = local.bot_scopes }
    }
    settings = {
      event_subscriptions = {
        request_url = local.webhook_url
        bot_events  = ["app_mention", "message.channels"]
      }
      interactivity = {
        is_enabled  = true
        request_url = local.webhook_url
      }
      org_deploy_enabled     = false
      socket_mode_enabled    = false
      token_rotation_enabled = false
    }
  })
}
