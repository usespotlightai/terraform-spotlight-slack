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

  thread_mark    = "${var.integration}.thread"
  channel_mark   = "${var.integration}.channel"
  message_mark   = "${var.integration}.message"
  thread_ts_mark = "${var.integration}.thread_ts"

  in_thread = {
    channel = "$${{ \"${local.channel_mark}\" in chat.marks && \"${local.thread_ts_mark}\" in chat.marks ? chat.marks[\"${local.channel_mark}\"] : \"\" }}"
    thread  = "$${{ \"${local.thread_ts_mark}\" in chat.marks ? chat.marks[\"${local.thread_ts_mark}\"] : \"\" }}"
  }

  chat_on = {
    "chat.replied" = { action = "post-reply", to = local.in_thread }
    "chat.refused" = { action = "post-reply", to = local.in_thread }
  }

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
    "chat.started" = {
      action = "acknowledge"
      to = {
        channel = "$${{ \"${local.channel_mark}\" in chat.marks && \"${local.message_mark}\" in chat.marks ? chat.marks[\"${local.channel_mark}\"] : \"\" }}"
        message = "$${{ \"${local.message_mark}\" in chat.marks ? chat.marks[\"${local.message_mark}\"] : \"\" }}"
      }
    }
  }

  attachments = {
    each = "$${{ has(body.event.files) ? body.event.files.filter(file, has(file.url_private_download)) : [] }}"
    name = "$${{ has(file.name) ? file.name : \"\" }}"
    type = "$${{ has(file.mimetype) ? file.mimetype : \"\" }}"
    size = "$${{ has(file.size) ? file.size : -1 }}"
    fetch = {
      method = "GET"
      url    = "$${{ file.url_private_download }}"
      auth   = { secrets = ["secret.${local.bot_token_name}"] }
      expect = { success = "$${{ status >= 200 && status < 300 && ((has(file.mimetype) && file.mimetype.lowerAscii() == \"text/html\") || !(\"content-type\" in headers) || !headers[\"content-type\"].lowerAscii().startsWith(\"text/html\")) }}" }
    }
  }

  opens_chat = merge(
    { by = { email = "$${{ email }}" } },
    var.harness == null ? {} : { harness = var.harness },
  )
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
    { host = "files.slack.com", location = "header", name = "authorization", prefix = "Bearer " },
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
          lookup = {
            request = {
              method = "GET"
              url    = "https://slack.com/api/users.info"
              query  = { user = "$${{ body.event.user }}" }
              auth   = { secrets = ["secret.${local.bot_token_name}"] }
              expect = { success = "$${{ response.ok }}" }
            }
            capture = {
              email = "$${{ response.user.profile.email }}"
            }
          }
          raise = {
            happening = "${var.integration}.app_mention"
            label     = "Mentioned"
            summary   = "Mentioned Spotlight in Slack."
            message   = "$${{ body.event.text.startsWith(\"<@\") ? body.event.text.substring(body.event.text.indexOf(\">\") + 1) : body.event.text }}"
            opens = {
              chat = local.opens_chat
            }
            attachments = local.attachments
            marks = [
              { kind = local.thread_mark, value = "$${{ body.event.channel + \":\" + (has(body.event.thread_ts) ? body.event.thread_ts : body.event.ts) }}" },
              { kind = local.channel_mark, find = false, value = "$${{ body.event.channel }}" },
              { kind = local.message_mark, find = false, value = "$${{ body.event.ts }}" },
              { kind = local.thread_ts_mark, find = false, value = "$${{ has(body.event.thread_ts) ? body.event.thread_ts : body.event.ts }}" },
            ]
          }
        },
        {
          when = "$${{ body.event.type == \"message\" && body.event.thread_ts != \"\" }}"
          raise = {
            happening   = "${var.integration}.message.replied"
            label       = "Replied"
            summary     = "Replied in a Slack thread."
            answers     = true
            message     = "$${{ body.event.text }}"
            attachments = local.attachments
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
      post-reply = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/chat.postMessage"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": target.channel, \"thread_ts\": target.thread, \"text\": reply.link != null ? reply.body + \"\\n\\n<\" + reply.link + \"|Open in Spotlight>\" : reply.body} }}"
          expect = { success = "$${{ response.ok }}" }
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
    }, local.chat_on, local.acknowledge_on)
  }
}
