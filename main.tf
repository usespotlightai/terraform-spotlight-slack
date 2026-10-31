data "spotlight_workspace" "this" {
  count = var.create ? 1 : 0

  slug = var.workspace
}

data "spotlight_team" "this" {
  count = var.create ? 1 : 0

  workspace_id = data.spotlight_workspace.this[0].id
  key          = var.team
}

locals {
  signing_secret_name = try(spotlight_secret.signing[0].name, var.signing_secret_name)
  bot_token_name      = try(spotlight_secret.bot_token[0].name, var.bot_token_name)

  thread_mark  = "${var.integration}.thread"
  channel_mark = "${var.integration}.channel"
  message_mark = "${var.integration}.message"

  on_asked = merge(
    {
      action = "post-question"
      to = {
        channel = "$${{ task.marks[\"${local.channel_mark}\"] }}"
        thread  = "$${{ task.marks[\"${local.thread_mark}\"] }}"
      }
      mark = [
        { kind = local.thread_mark, value = "$${{ capture.thread }}" },
      ]
    },
    length(var.routes) > 0 ? { routes = var.routes } : {},
  )

  post_message_tool = merge(
    {
      action      = "post-message"
      description = "Post a message to a Slack channel."
      inputs = {
        channel = { type = "string", required = true, description = "The ID of the Slack channel, as in C024BE91L." }
        text    = { type = "string", required = true, description = "The message, in Slack mrkdwn." }
      }
    },
    var.post_message_approval == null ? {} : { approval = { because = var.post_message_approval } },
  )

  acknowledge_actions = var.acknowledge == null ? {} : {
    acknowledge = {
      request = {
        method = "POST"
        url    = "https://slack.com/api/reactions.add"
        auth   = { secrets = ["secret.${local.bot_token_name}"] }
        body   = "$${{ {\"channel\": target.channel, \"timestamp\": target.message, \"name\": \"${var.acknowledge}\"} }}"
        expect = { success = "$${{ response.ok }}" }
      }
    }
  }

  acknowledge_on = var.acknowledge == null ? {} : {
    "task.opened" = {
      action = "acknowledge"
      to = {
        channel = "$${{ \"${local.channel_mark}\" in task.marks && \"${local.message_mark}\" in task.marks ? task.marks[\"${local.channel_mark}\"] : \"\" }}"
        message = "$${{ \"${local.message_mark}\" in task.marks ? task.marks[\"${local.message_mark}\"] : \"\" }}"
      }
    }
  }
}

resource "spotlight_secret" "signing" {
  count = var.create && var.create_secrets ? 1 : 0

  workspace_id     = data.spotlight_workspace.this[0].id
  name             = var.signing_secret_name
  value_wo         = var.signing_secret
  value_wo_version = var.secret_version
}

resource "spotlight_secret" "bot_token" {
  count = var.create && var.create_secrets ? 1 : 0

  workspace_id = data.spotlight_workspace.this[0].id
  name         = var.bot_token_name
  bindings = [
    { host = "slack.com", location = "header", name = "authorization", prefix = "Bearer " },
  ]
  value_wo         = var.bot_token
  value_wo_version = var.secret_version
}

resource "spotlight_integration" "this" {
  count = var.create ? 1 : 0

  team_id = data.spotlight_team.this[0].id
  definition = {
    integration = var.integration
    name        = var.name

    webhook = {
      verify = {
        hmac = {
          algorithm = "sha256"
          secret    = "secret.${local.signing_secret_name}"
          header    = "x-slack-signature"
          prefix    = "v0="
          signed    = "$${{ \"v0:\" + headers[\"x-slack-request-timestamp\"] + \":\" + raw }}"
          freshness = {
            at     = "$${{ headers[\"x-slack-request-timestamp\"] }}"
            within = "300s"
          }
        }
      }
      respond = {
        when = "$${{ body.type == \"url_verification\" }}"
        body = "$${{ body.challenge }}"
      }
      ignoreWhen = "$${{ body.event.bot_id != \"\" }}"
      events = [
        {
          when = "$${{ body.event.type == \"app_mention\" }}"
          raise = {
            happening = "${var.integration}.app_mention"
            label     = "Mentioned"
            summary   = "Mentioned Spotlight in Slack."
            opens = {
              lineRole = var.line_role
              station  = var.station
              title    = "$${{ body.event.text }}"
            }
            marks = [
              { kind = local.thread_mark, value = "$${{ body.event.channel + \":\" + (has(body.event.thread_ts) ? body.event.thread_ts : body.event.ts) }}" },
              { kind = local.channel_mark, find = false, value = "$${{ body.event.channel }}" },
              { kind = local.message_mark, find = false, value = "$${{ body.event.ts }}" },
            ]
          }
        },
        {
          when = "$${{ body.event.type == \"message\" && body.event.thread_ts != \"\" }}"
          raise = {
            happening = "${var.integration}.message.replied"
            label     = "Replied"
            summary   = "Replied in a Slack thread."
            answers   = true
            message   = "$${{ body.event.text }}"
            marks = [
              { kind = local.thread_mark, value = "$${{ body.event.channel + \":\" + body.event.thread_ts }}" },
            ]
          }
        },
      ]
    }

    actions = merge({
      post-question = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/chat.postMessage"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": target.channel, \"text\": ask.body} }}"
          expect = { success = "$${{ response.ok }}" }
          capture = {
            thread = "$${{ target.channel + \":\" + response.ts }}"
          }
        }
      }
      post-message = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/chat.postMessage"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": inputs.channel, \"text\": inputs.text} }}"
          expect = { success = "$${{ response.ok }}" }
          capture = {
            ts = "$${{ response.ts }}"
          }
        }
      }
    }, local.acknowledge_actions)

    tools = {
      post-message = local.post_message_tool
    }

    on = merge({
      "task.asked" = local.on_asked
    }, local.acknowledge_on)
  }
}
