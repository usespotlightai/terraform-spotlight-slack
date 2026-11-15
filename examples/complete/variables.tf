variable "spotlight_url" {
  description = "The Spotlight the integration is created in."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "slack_signing_secret" {
  description = "The Slack app's signing secret."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "slack_bot_token" {
  description = "The Slack app's bot token."
  type        = string
  sensitive   = true
  ephemeral   = true
}
