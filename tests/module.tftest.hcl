mock_provider "spotlight" {
  mock_data "spotlight_workspace" {
    defaults = {
      id = "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57"
    }
  }

  mock_data "spotlight_team" {
    defaults = {
      id = "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    }
  }
}

variables {
  workspace      = "acme"
  team           = "core"
  signing_secret = "8f742231b10e8888abcd99yyyzzz85a5"
  bot_token      = "xoxb-test"
}

run "creates_the_secrets_and_the_integration" {
  assert {
    condition     = spotlight_secret.signing[0].workspace_id == "5b1e9d2c-7a43-4f8e-b6c0-3d9a8e1f2b57" && spotlight_secret.signing[0].name == "SLACK_SIGNING_SECRET"
    error_message = "The signing secret goes in the workspace, as SLACK_SIGNING_SECRET."
  }

  assert {
    condition     = length(spotlight_secret.signing[0].bindings) == 0
    error_message = "The signing secret is never sent anywhere."
  }

  assert {
    condition     = [for each in spotlight_secret.bot_token[0].bindings : each.host] == ["slack.com", "files.slack.com"] && alltrue([for each in spotlight_secret.bot_token[0].bindings : each.prefix == "Bearer "])
    error_message = "The bot token goes only to slack.com and files.slack.com, as a bearer token."
  }

  assert {
    condition     = spotlight_integration.this[0].team_id == "3f8a1c2e-6b4d-4e7a-9c1f-0d2b5e8a7c63"
    error_message = "The integration belongs to the team."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.SLACK_SIGNING_SECRET"
    error_message = "Deliveries are verified with the signing secret."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.actions["post-question"].request.auth.secrets == ["secret.SLACK_BOT_TOKEN"] && spotlight_integration.this[0].definition.actions["post-message"].request.auth.secrets == ["secret.SLACK_BOT_TOKEN"]
    error_message = "Both actions authenticate with the bot token."
  }

  assert {
    condition     = output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/slack"
    error_message = "The webhook address is the team's address for the integration."
  }
}

run "starts_a_chat_from_a_mention" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.opens.chat.by.email == "$${{ email }}" && !contains(keys(spotlight_integration.this[0].definition.webhook.events[0].raise.opens.chat), "harness")
    error_message = "A mention starts a chat for the person with the email of the Slack user, on the default harness."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].lookup.request.url == "https://slack.com/api/users.info" && spotlight_integration.this[0].definition.webhook.events[0].lookup.request.auth.secrets == ["secret.SLACK_BOT_TOKEN"]
    error_message = "The email comes from users.info, read with the bot token."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.marks[3].kind == "slack.thread_ts" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[3].find == false
    error_message = "A mention keeps the root of its thread, for the replies."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.on["chat.replied"].action == "post-reply" && spotlight_integration.this[0].definition.on["chat.refused"].action == "post-reply" && strcontains(spotlight_integration.this[0].definition.on["chat.replied"].to.thread, "chat.marks[\"slack.thread_ts\"]")
    error_message = "Replies and refusals are posted in the thread of the chat."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["chat.replied"].to.channel, "\"slack.channel\" in chat.marks") && strcontains(spotlight_integration.this[0].definition.on["chat.started"].to.message, "\"slack.message\" in chat.marks")
    error_message = "A chat without the integration's marks is not addressed, and no expression fails on it."
  }
}

run "signs_a_mention_and_a_reply_without_the_mention" {
  command = plan

  assert {
    condition     = alltrue([for each in spotlight_integration.this[0].definition.webhook.events : strcontains(each.raise.message, "body.event.text.startsWith(\"<@\" + body.authorizations[0].user_id + \">\")")])
    error_message = "A mention and a reply drop only a leading mention of the app itself."
  }

  assert {
    condition     = alltrue([for each in spotlight_integration.this[0].definition.webhook.events : each.lookup.request.url == "https://slack.com/api/users.info" && each.lookup.capture.email == "$${{ response.user.profile.email }}" && each.raise.author.email == "$${{ email }}"])
    error_message = "A mention and a reply name their author by the email of the Slack user."
  }
}

run "brings_the_files_of_a_mention_and_a_reply" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.attachments == spotlight_integration.this[0].definition.webhook.events[1].raise.attachments
    error_message = "A mention and a reply bring their files the same way."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.attachments.each == "$${{ has(body.event.files) ? body.event.files.filter(file, has(file.url_private_download)) : [] }}"
    error_message = "Only the files Slack gives a download address for are brought."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.attachments.fetch.method == "GET" && spotlight_integration.this[0].definition.webhook.events[0].raise.attachments.fetch.url == "$${{ file.url_private_download }}" && spotlight_integration.this[0].definition.webhook.events[0].raise.attachments.fetch.auth.secrets == ["secret.SLACK_BOT_TOKEN"]
    error_message = "Each file is downloaded with the bot token."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.attachments.fetch.expect.success == "$${{ status >= 200 && status < 300 && ((has(file.mimetype) && file.mimetype.lowerAscii() == \"text/html\") || !(\"content-type\" in headers) || !headers[\"content-type\"].lowerAscii().startsWith(\"text/html\")) }}"
    error_message = "A Slack sign-in page is not kept as the file, unless the file is itself HTML."
  }
}

run "starts_chats_on_the_given_harness" {
  command = plan

  variables {
    harness = "codex"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.opens.chat.harness == "codex"
    error_message = "A mention starts a chat on the given harness."
  }
}

run "refuses_a_harness_that_is_not_a_key" {
  command = plan

  variables {
    harness = "Claude Code"
  }

  expect_failures = [var.harness]
}

run "routes_questions_only_when_given" {
  command = plan

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.on["task.asked"]), "routes")
    error_message = "No routes are sent when none are given."
  }
}

run "routes_questions_by_line" {
  command = plan

  variables {
    routes = { delivery = "C024BE91L" }
  }

  assert {
    condition     = spotlight_integration.this[0].definition.on["task.asked"].routes.delivery == "C024BE91L"
    error_message = "Questions from the delivery line go to the given channel."
  }
}

run "names_everything_after_the_integration" {
  command = plan

  variables {
    integration = "slackops"
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.happening == "slackops.app_mention" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[0].kind == "slackops.thread"
    error_message = "Happenings and mark kinds start with the integration's name."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.asked"].to.channel, "task.marks[\"slackops.channel\"]")
    error_message = "Questions find the channel by the integration's own mark."
  }

  assert {
    condition     = output.webhook_url == "https://app.usespotlight.ai/api/webhooks/w/acme/t/core/slackops"
    error_message = "The webhook address ends with the integration's name."
  }
}

run "asks_before_posting_when_set" {
  command = plan

  variables {
    post_message_approval = "The message is visible to everyone in the channel."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.tools["post-message"].approval.because == "The message is visible to everyone in the channel."
    error_message = "The post-message tool asks a person first."
  }
}

run "posts_without_asking_by_default" {
  command = plan

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.tools["post-message"]), "approval")
    error_message = "The post-message tool has no approval by default."
  }
}

run "uses_existing_secrets" {
  command = plan

  variables {
    create_secrets      = false
    signing_secret      = null
    bot_token           = null
    signing_secret_name = "ACME_SLACK_SIGNING"
    bot_token_name      = "ACME_SLACK_BOT"
  }

  assert {
    condition     = length(spotlight_secret.signing) == 0 && length(spotlight_secret.bot_token) == 0
    error_message = "No secrets are created."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.verify.hmac.secret == "secret.ACME_SLACK_SIGNING" && spotlight_integration.this[0].definition.actions["post-message"].request.auth.secrets == ["secret.ACME_SLACK_BOT"]
    error_message = "The integration names the existing secrets."
  }
}

run "creates_nothing_when_disabled" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = length(spotlight_integration.this) == 0 && length(spotlight_secret.signing) == 0 && length(spotlight_secret.bot_token) == 0
    error_message = "A disabled module creates no resources."
  }

  assert {
    condition     = output.id == null && output.webhook_url == null && output.tools == {}
    error_message = "A disabled module's resource outputs are null."
  }
}

run "refuses_missing_secret_values" {
  command = plan

  variables {
    bot_token = null
  }

  expect_failures = [var.bot_token]
}

run "refuses_an_integration_name_with_a_dash" {
  command = plan

  variables {
    integration = "slack-ops"
  }

  expect_failures = [var.integration]
}

run "reacts_with_eyes_by_default" {
  command = plan

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.actions["acknowledge"].request.body, "\"name\": \"eyes\"") && spotlight_integration.this[0].definition.actions["acknowledge"].request.url == "https://slack.com/api/reactions.add"
    error_message = "A mention gets the eyes reaction."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.on["chat.started"].action == "acknowledge" && !contains(keys(spotlight_integration.this[0].definition.on["chat.started"]), "routes")
    error_message = "The reaction runs when the chat starts, and never falls back to a route."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.marks[2].kind == "slack.message" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[2].find == false
    error_message = "A mention marks the chat with its own message."
  }
}

run "reacts_with_the_given_emoji" {
  command = plan

  variables {
    acknowledge = "white_check_mark"
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.actions["acknowledge"].request.body, "\"name\": \"white_check_mark\"")
    error_message = "The reaction uses the given emoji."
  }
}

run "does_not_react_when_off" {
  command = plan

  variables {
    acknowledge = null
  }

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.actions), "acknowledge") && !contains(keys(spotlight_integration.this[0].definition.on), "chat.started")
    error_message = "No reaction is defined when acknowledge is null."
  }
}

run "refuses_an_emoji_with_colons" {
  command = plan

  variables {
    acknowledge = ":eyes:"
  }

  expect_failures = [var.acknowledge]
}
