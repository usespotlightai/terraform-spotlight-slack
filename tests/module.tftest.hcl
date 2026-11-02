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
    condition     = spotlight_integration.this[0].definition.on["chat.replied"][0].action == "post-reply" && spotlight_integration.this[0].definition.on["chat.refused"][0].action == "post-reply" && strcontains(spotlight_integration.this[0].definition.on["chat.replied"][0].to.thread, "chat.marks[\"slack.thread_ts\"]")
    error_message = "Replies and refusals are posted in the thread of the chat."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["chat.replied"][0].to.channel, "\"slack.channel\" in chat.marks") && strcontains(spotlight_integration.this[0].definition.on["chat.dispatched"][0].to.thread, "\"slack.thread_ts\" in chat.marks")
    error_message = "A chat without the integration's marks is not addressed, and no expression fails on it."
  }
}

run "signs_a_mention_and_a_reply_without_the_mention" {
  command = plan

  assert {
    condition     = alltrue([for each in slice(spotlight_integration.this[0].definition.webhook.events, 0, 2) : strcontains(each.raise.message, "body.event.text.startsWith(\"<@\" + body.authorizations[0].user_id + \">\")")])
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
    condition     = !contains(keys(spotlight_integration.this[0].definition.on["task.asked"][0]), "routes")
    error_message = "No routes are sent when none are given."
  }
}

run "routes_questions_by_line" {
  command = plan

  variables {
    routes = { delivery = "C024BE91L" }
  }

  assert {
    condition     = spotlight_integration.this[0].definition.on["task.asked"][0].routes.delivery == "C024BE91L"
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
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.asked"][0].to.channel, "task.marks[\"slackops.channel\"]")
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

run "shows_a_status_while_the_agent_works" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.actions["set-status"].request.url == "https://slack.com/api/assistant.threads.setStatus" && strcontains(spotlight_integration.this[0].definition.actions["set-status"].request.body, "\"status\": \"is thinking…\"")
    error_message = "The status is set with assistant.threads.setStatus."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.on["chat.dispatched"][0].action == "set-status" && !contains(keys(spotlight_integration.this[0].definition.on), "chat.started")
    error_message = "The status is set each time a run is dispatched for the chat, and nothing reacts to a mention that starts a chat."
  }
}

run "shows_no_status_when_off" {
  command = plan

  variables {
    status = null
  }

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.actions), "set-status") && !contains(keys(spotlight_integration.this[0].definition.on), "chat.dispatched")
    error_message = "No status is defined when status is null."
  }
}

run "refuses_a_status_with_a_double_quote" {
  command = plan

  variables {
    status = "is \"thinking\""
  }

  expect_failures = [var.status]
}

run "reacts_and_says_when_a_task_ends" {
  command = plan

  assert {
    condition     = [for each in spotlight_integration.this[0].definition.on["task.finished"] : each.action] == ["unreact", "react", "post-notice"] && [for each in spotlight_integration.this[0].definition.on["task.failed"] : each.action] == ["react"]
    error_message = "A failed run gets x. A finished task loses x, gets white_check_mark, then a message in its thread."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.finished"][0].to.emoji, "\"x\"") && strcontains(spotlight_integration.this[0].definition.on["task.finished"][1].to.emoji, "white_check_mark") && strcontains(spotlight_integration.this[0].definition.on["task.failed"][0].to.emoji, "\"x\"")
    error_message = "The reactions are x and white_check_mark."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["task.finished"][1].to.message, "task.marks[\"slack.thread\"].split(\":\")[1]") && strcontains(spotlight_integration.this[0].definition.on["task.finished"][1].to.message, "task.marks[\"slack.message\"]")
    error_message = "The reaction goes on the first message of the question thread, or else on the mention that started the chat."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.actions["react"].request.expect.success, "already_reacted") && strcontains(spotlight_integration.this[0].definition.actions["unreact"].request.expect.success, "no_reaction")
    error_message = "A reaction that is already there, or not there, is not a failure."
  }
}

run "only_says_when_a_task_ends_when_reactions_are_off" {
  command = plan

  variables {
    finished_reaction = null
    failed_reaction   = null
  }

  assert {
    condition     = [for each in spotlight_integration.this[0].definition.on["task.finished"] : each.action] == ["post-notice"] && !contains(keys(spotlight_integration.this[0].definition.on), "task.failed")
    error_message = "No reaction is defined when the reactions are null."
  }
}

run "refuses_a_status_that_breaks_the_expression" {
  command = plan

  variables {
    status = "is \\ thinking"
  }

  expect_failures = [var.status]
}

run "refuses_an_emoji_with_colons" {
  command = plan

  variables {
    finished_reaction = ":white_check_mark:"
  }

  expect_failures = [var.finished_reaction]
}

run "mentions_the_person_who_started_the_chat" {
  command = plan

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[0].raise.marks[4].kind == "slack.user" && spotlight_integration.this[0].definition.webhook.events[0].raise.marks[4].find == false
    error_message = "A mention marks the chat with the Slack user who wrote it."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.actions["post-question"].request.body, "\"<@\" + task.marks[\"slack.user\"]") && strcontains(spotlight_integration.this[0].definition.actions["post-notice"].request.body, "\"type\": \"mrkdwn\", \"text\": \"<@\" + task.marks[\"slack.user\"]")
    error_message = "A question and the end of a task mention the person who started the chat."
  }
}

run "offers_buttons" {
  command = plan

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.actions["post-reply"].request.body, "reply.proposals.map(p,") && strcontains(spotlight_integration.this[0].definition.actions["post-reply"].request.body, "\"value\": \"accept \" + string(p.number)")
    error_message = "A reply has an Accept and a Dismiss button for each open proposal."
  }

  assert {
    condition     = alltrue([for name in ["post-reply", "post-question", "post-notice"] : strcontains(spotlight_integration.this[0].definition.actions[name].request.body, "Open in Spotlight")])
    error_message = "Each message the app posts links to Spotlight with a button."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[2].raise.happening == "slack.block_actions" && spotlight_integration.this[0].definition.webhook.events[2].raise.message == "$${{ parseJson(body.payload).actions[0].value }}" && strcontains(spotlight_integration.this[0].definition.webhook.events[2].when, "\"value\" in parseJson(body.payload).actions[0]") && strcontains(spotlight_integration.this[0].definition.webhook.events[2].when, "parseJson(body.payload).container.type == \"message\"")
    error_message = "A click on a button with a value says that value in the chat, and a click on a link button says nothing."
  }

  assert {
    condition     = spotlight_integration.this[0].definition.webhook.events[2].lookup.request.query.user == "$${{ parseJson(body.payload).user.id }}" && spotlight_integration.this[0].definition.webhook.events[2].raise.author.email == "$${{ email }}"
    error_message = "A click is signed by the Slack user who clicked."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.webhook.ignoreWhen, "has(body.event)") && strcontains(spotlight_integration.this[0].definition.webhook.respond.when, "has(body.type)")
    error_message = "A click, which has no event, is neither ignored nor answered as a challenge."
  }
}

run "reacts_to_a_mention_that_reopens_a_task" {
  command = plan

  assert {
    condition     = [for each in spotlight_integration.this[0].definition.on["chat.acknowledged"] : each.action] == ["react", "unreact"]
    error_message = "A mention that reopens a task gets eyes, and the thread loses white_check_mark."
  }

  assert {
    condition     = strcontains(spotlight_integration.this[0].definition.on["chat.acknowledged"][0].to.emoji, "\"eyes\"") && strcontains(spotlight_integration.this[0].definition.on["chat.acknowledged"][0].to.message, "chat.marks[\"slack.message\"]") && strcontains(spotlight_integration.this[0].definition.on["chat.acknowledged"][1].to.emoji, "white_check_mark") && strcontains(spotlight_integration.this[0].definition.on["chat.acknowledged"][1].to.message, "chat.marks[\"slack.thread_ts\"]")
    error_message = "eyes goes on the mention, and white_check_mark comes off the first message of the thread."
  }
}

run "does_not_react_to_a_reopening_mention_when_off" {
  command = plan

  variables {
    acknowledge       = null
    finished_reaction = null
  }

  assert {
    condition     = !contains(keys(spotlight_integration.this[0].definition.on), "chat.acknowledged")
    error_message = "Nothing is bound to chat.acknowledged when both reactions are null."
  }
}
