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
  user_mark      = "${var.integration}.user"

  interaction = "parseJson(body.payload)"

  in_thread = {
    channel = "$${{ \"${local.channel_mark}\" in chat.marks && \"${local.thread_ts_mark}\" in chat.marks ? chat.marks[\"${local.channel_mark}\"] : \"\" }}"
    thread  = "$${{ \"${local.thread_ts_mark}\" in chat.marks ? chat.marks[\"${local.thread_ts_mark}\"] : \"\" }}"
  }

  reopened = concat(
    var.acknowledge == null ? [] : [{
      action = "react"
      to = {
        channel = "$${{ \"${local.channel_mark}\" in chat.marks && \"${local.message_mark}\" in chat.marks ? chat.marks[\"${local.channel_mark}\"] : \"\" }}"
        message = "$${{ \"${local.message_mark}\" in chat.marks ? chat.marks[\"${local.message_mark}\"] : \"\" }}"
        emoji   = "$${{ \"${var.acknowledge}\" }}"
      }
    }],
    var.finished_reaction == null ? [] : [{
      action = "unreact"
      to = {
        channel = local.in_thread.channel
        message = local.in_thread.thread
        emoji   = "$${{ \"${var.finished_reaction}\" }}"
      }
    }],
  )

  chat_on = merge(
    {
      "chat.replied" = [{ action = "post-reply", to = local.in_thread }]
      "chat.refused" = [{ action = "post-reply", to = local.in_thread }]
    },
    var.status == null ? {} : {
      "chat.dispatched" = [{ action = "set-status", to = local.in_thread }]
    },
    length(local.reopened) == 0 ? {} : {
      "chat.acknowledged" = local.reopened
    },
  )

  mentions_starter = "(\"${local.user_mark}\" in task.marks ? \"<@\" + task.marks[\"${local.user_mark}\"] + \"> \" : \"\")"
  mention_block    = "dyn(\"${local.user_mark}\" in task.marks ? [{\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"<@\" + task.marks[\"${local.user_mark}\"] + \">\"}}] : [])"

  task_root = {
    channel = "\"${local.thread_mark}\" in task.marks ? task.marks[\"${local.thread_mark}\"].split(\":\")[0] : \"${local.channel_mark}\" in task.marks ? task.marks[\"${local.channel_mark}\"] : \"\""
    message = "\"${local.thread_mark}\" in task.marks ? task.marks[\"${local.thread_mark}\"].split(\":\")[1] : \"${local.message_mark}\" in task.marks ? task.marks[\"${local.message_mark}\"] : \"\""
    thread  = "\"${local.thread_mark}\" in task.marks ? task.marks[\"${local.thread_mark}\"].split(\":\")[1] : \"${local.thread_ts_mark}\" in task.marks ? task.marks[\"${local.thread_ts_mark}\"] : \"\""
  }

  on_root = {
    channel = "$${{ ${local.task_root.channel} }}"
    message = "$${{ ${local.task_root.message} }}"
  }

  task_on = {
    "task.finished" = concat(
      var.failed_reaction == null ? [] : [{
        action = "unreact"
        to     = merge(local.on_root, { emoji = "$${{ \"${var.failed_reaction}\" }}" })
      }],
      var.finished_reaction == null ? [] : [{
        action = "react"
        to     = merge(local.on_root, { emoji = "$${{ \"${var.finished_reaction}\" }}" })
      }],
      [{
        action = "post-notice"
        to = {
          channel = local.on_root.channel
          thread  = "$${{ ${local.task_root.thread} }}"
          text    = "$${{ \"The task “\" + task.title + \"” is complete.\" + (task.pullRequest != null ? \" Pull request: \" + task.pullRequest : \"\") }}"
        }
      }],
    )
    "task.failed" = var.failed_reaction == null ? [] : [{
      action = "react"
      to     = merge(local.on_root, { emoji = "$${{ \"${var.failed_reaction}\" }}" })
    }]
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

  status_actions = var.status == null ? {} : {
    set-status = {
      request = {
        method = "POST"
        url    = "https://slack.com/api/assistant.threads.setStatus"
        auth   = { secrets = ["secret.${local.bot_token_name}"] }
        body   = "$${{ {\"channel_id\": target.channel, \"thread_ts\": target.thread, \"status\": \"${var.status}\"} }}"
        expect = { success = "$${{ response.ok }}" }
      }
    }
  }

  open_in_spotlight = "{\"type\": \"actions\", \"elements\": [{\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"Open in Spotlight\"}, \"url\": LINK}]}"

  shown = "{\"type\": \"markdown\", \"text\": TEXT.size() > 11000 ? TEXT.substring(0, 11000) + \"…\" : TEXT}"

  decisions = "{\"type\": \"actions\", \"elements\": [{\"type\": \"button\", \"style\": \"primary\", \"text\": {\"type\": \"plain_text\", \"text\": \"Accept \" + string(p.number)}, \"value\": \"accept \" + string(p.number)}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"Dismiss \" + string(p.number)}, \"value\": \"dismiss \" + string(p.number)}]}"

  blocks = {
    reply    = "dyn([${replace(local.shown, "TEXT", "reply.body")}]) + dyn(reply.proposals.map(p, ${local.decisions})) + dyn(reply.link != null ? [${replace(local.open_in_spotlight, "LINK", "reply.link")}] : [])"
    question = "${local.mention_block} + dyn([${replace(local.shown, "TEXT", "ask.body")}]) + dyn(ask.link != null ? [${replace(local.open_in_spotlight, "LINK", "ask.link")}] : [])"
    notice   = "${local.mention_block} + dyn([${replace(local.shown, "TEXT", "target.text")}]) + dyn(task.url != null ? [${replace(local.open_in_spotlight, "LINK", "task.url")}] : [])"
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

  sender = {
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

  clicker = {
    request = merge(local.sender.request, {
      query = { user = "$${{ ${local.interaction}.user.id }}" }
    })
    capture = local.sender.capture
  }

  unmentioned = "$${{ has(body.authorizations) && size(body.authorizations) > 0 && body.event.text.startsWith(\"<@\" + body.authorizations[0].user_id + \">\") ? body.event.text.substring(body.event.text.indexOf(\">\") + 1) : body.event.text }}"

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
        when = "$${{ has(body.type) && body.type == \"url_verification\" }}"
        body = "$${{ body.challenge }}"
      }
      ignoreWhen = "$${{ has(body.event) && has(body.event.bot_id) && body.event.bot_id != \"\" }}"
      events = [
        {
          when   = "$${{ has(body.event) && body.event.type == \"app_mention\" }}"
          lookup = local.sender
          raise = {
            happening = "${var.integration}.app_mention"
            label     = "Mentioned"
            summary   = "Mentioned Spotlight in Slack."
            message   = local.unmentioned
            author    = { email = "$${{ email }}" }
            opens = {
              chat = local.opens_chat
            }
            attachments = local.attachments
            marks = [
              { kind = local.thread_mark, value = "$${{ body.event.channel + \":\" + (has(body.event.thread_ts) ? body.event.thread_ts : body.event.ts) }}" },
              { kind = local.channel_mark, find = false, value = "$${{ body.event.channel }}" },
              { kind = local.message_mark, find = false, value = "$${{ body.event.ts }}" },
              { kind = local.thread_ts_mark, find = false, value = "$${{ has(body.event.thread_ts) ? body.event.thread_ts : body.event.ts }}" },
              { kind = local.user_mark, find = false, value = "$${{ body.event.user }}" },
            ]
          }
        },
        {
          when   = "$${{ has(body.event) && body.event.type == \"message\" && has(body.event.thread_ts) && body.event.thread_ts != \"\" }}"
          lookup = local.sender
          raise = {
            happening   = "${var.integration}.message.replied"
            label       = "Replied"
            summary     = "Replied in a Slack thread."
            answers     = true
            message     = local.unmentioned
            author      = { email = "$${{ email }}" }
            attachments = local.attachments
            marks = [
              { kind = local.thread_mark, value = "$${{ body.event.channel + \":\" + body.event.thread_ts }}" },
            ]
          }
        },
        {
          when   = "$${{ has(body.payload) && ${local.interaction}.type == \"block_actions\" && ${local.interaction}.container.type == \"message\" && size(${local.interaction}.actions) > 0 && \"value\" in ${local.interaction}.actions[0] }}"
          lookup = local.clicker
          raise = {
            happening = "${var.integration}.block_actions"
            label     = "Clicked"
            summary   = "Clicked a button in Slack."
            message   = "$${{ ${local.interaction}.actions[0].value }}"
            author    = { email = "$${{ email }}" }
            opens = {
              chat = local.opens_chat
            }
            marks = [
              { kind = local.thread_mark, value = "$${{ ${local.interaction}.container.channel_id + \":\" + (\"thread_ts\" in ${local.interaction}.message ? ${local.interaction}.message.thread_ts : ${local.interaction}.message.ts) }}" },
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
          body   = "$${{ {\"channel\": target.channel, \"text\": ${local.mentions_starter} + ask.body, \"blocks\": ${local.blocks.question}} }}"
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
          body   = "$${{ {\"channel\": target.channel, \"thread_ts\": target.thread, \"text\": reply.body, \"blocks\": ${local.blocks.reply}} }}"
          expect = { success = "$${{ response.ok }}" }
        }
      }
      post-notice = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/chat.postMessage"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": target.channel, \"thread_ts\": target.thread, \"text\": ${local.mentions_starter} + target.text, \"blocks\": ${local.blocks.notice}} }}"
          expect = { success = "$${{ response.ok }}" }
        }
      }
      unreact = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/reactions.remove"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": target.channel, \"timestamp\": target.message, \"name\": target.emoji} }}"
          expect = { success = "$${{ response.ok || response.error == \"no_reaction\" }}" }
        }
      }
      react = {
        request = {
          method = "POST"
          url    = "https://slack.com/api/reactions.add"
          auth   = { secrets = ["secret.${local.bot_token_name}"] }
          body   = "$${{ {\"channel\": target.channel, \"timestamp\": target.message, \"name\": target.emoji} }}"
          expect = { success = "$${{ response.ok || response.error == \"already_reacted\" }}" }
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
    }, local.status_actions)

    tools = {
      post-message = local.post_message_tool
    }

    on = merge({
      "task.asked" = [local.on_asked]
    }, local.chat_on, { for event, bindings in local.task_on : event => bindings if length(bindings) > 0 })
  }
}
