variable "create" {
  description = "Whether to create the integration and its secrets. False creates nothing."
  type        = bool
  default     = true
}

variable "workspace" {
  description = "The slug of the Spotlight workspace, as in `acme`."
  type        = string
}

variable "team" {
  description = "The key of the team the integration belongs to, as in `core`."
  type        = string
}

variable "integration" {
  description = "The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `slack.app_mention`. Fixed for the integration's life."
  type        = string
  default     = "slack"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.integration)) && var.integration != "catalog"
    error_message = "integration is one word of lowercase letters and digits, and not catalog."
  }
}

variable "name" {
  description = "What the integration is called in the web app."
  type        = string
  default     = "Slack"
}

variable "spotlight_url" {
  description = "The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight."
  type        = string
  default     = "https://app.usespotlight.ai"
}

variable "line_role" {
  description = "The role of the line that a mention opens a task on."
  type        = string
  default     = "delivery"
}

variable "station" {
  description = "The key of the station that a task opened from a mention starts at."
  type        = string
  default     = "triage"
}

variable "routes" {
  description = "The Slack channel ID for the questions of tasks that were not opened from Slack, by line key, as in `{ delivery = \"C024BE91L\" }`. A task opened from Slack posts its questions to the channel it was opened from."
  type        = map(string)
  default     = {}
}

variable "post_message_approval" {
  description = "When set, each use of the `post-message` tool first asks a person, who is shown this text. Null lets agents and hooks post without asking."
  type        = string
  default     = null
}

variable "acknowledge" {
  description = "The name of the emoji the app reacts with on a mention, once the mention has opened a task, as in `eyes`. The bot then needs the `reactions:write` scope. Null turns the reaction off."
  type        = string
  default     = "eyes"

  validation {
    condition     = var.acknowledge == null || can(regex("^[a-z0-9_+'-]+$", var.acknowledge))
    error_message = "acknowledge is an emoji name without colons, as in eyes."
  }
}

variable "create_secrets" {
  description = "Whether the module creates the two secrets from `signing_secret` and `bot_token`. False uses the workspace secrets named `signing_secret_name` and `bot_token_name`, which you keep yourself; the bot token's secret must then be bound to `slack.com` in the `authorization` header, with the prefix `Bearer `."
  type        = bool
  default     = true
}

variable "signing_secret" {
  description = "The Slack app's signing secret. Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "bot_token" {
  description = "The Slack app's bot token (`xoxb-`). Needed when `create_secrets` is true."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true

  validation {
    condition     = !var.create_secrets || (var.signing_secret != null && var.bot_token != null)
    error_message = "Give signing_secret and bot_token, or set create_secrets to false."
  }
}

variable "secret_version" {
  description = "Change it when `signing_secret` or `bot_token` changes, so Terraform sends the new values to Spotlight."
  type        = number
  default     = 1
}

variable "signing_secret_name" {
  description = "The name of the workspace secret that holds the signing secret."
  type        = string
  default     = "SLACK_SIGNING_SECRET"
}

variable "bot_token_name" {
  description = "The name of the workspace secret that holds the bot token."
  type        = string
  default     = "SLACK_BOT_TOKEN"
}
