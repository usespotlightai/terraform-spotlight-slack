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
  value       = var.create ? "${trimsuffix(var.spotlight_url, "/")}/api/webhooks/w/${var.workspace}/t/${var.team}/${var.integration}" : null
}

output "happenings" {
  description = "The happenings the integration raises: `mentioned` when someone mentions the app, `replied` when someone replies in a thread."
  value = {
    mentioned = "${var.integration}.app_mention"
    replied   = "${var.integration}.message.replied"
  }
}

output "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  value       = var.create ? local.signing_secret_name : null
}

output "bot_token_name" {
  description = "The name of the workspace secret that holds the bot token."
  value       = var.create ? local.bot_token_name : null
}
