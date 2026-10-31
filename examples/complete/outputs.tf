output "webhook_url" {
  description = "The request URL to give in the Slack app's event subscriptions."
  value       = module.slack.webhook_url
}

output "tools" {
  description = "The integration's tools, by name."
  value       = module.slack.tools
}

output "happenings" {
  description = "The happenings the integration raises."
  value       = module.slack.happenings
}
