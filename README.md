# terraform-spotlight-slack

A Spotlight integration for a Slack app. A mention of the app starts a chat with the team's agent. While the agent works, Slack shows "is thinking…" in the thread. The agent answers in the thread and can propose tasks, which you accept or dismiss with a button or a reply. A task's questions are posted to Slack and mention the person who started the chat, and a reply in a question's thread answers it. When the task is complete or fails, the app reacts to the thread and says so in it. The app can also post the requests that wait in the inbox and the team's notices.

The module creates a `spotlight_integration` and, unless you keep them yourself, the two `spotlight_secret`s it uses: the app's signing secret, which verifies that deliveries come from Slack, and its bot token, bound to `slack.com` and `files.slack.com`. The integration also gives agents and hooks a `post-message` tool.

```
Slack ──event (signed with the signing secret)──▶ webhook_url
                                                    │ verify, answer url_verification
                                                    ▼
                         app_mention  → starts a chat for the member who uses the Slack user's email
                                        (users.info), or adds to the chat of that thread;
                                        in the thread of a finished task, reopens the task
                                        and reacts to the mention with acknowledge (reactions.add)
                         thread reply → answers the question asked in that thread
                         button click → accepts or dismisses a proposal of the chat
                                                    │
the agent works ──assistant.threads.setStatus───────┤ "is thinking…" in the chat's thread
the chat answers ─────chat.postMessage (bot token)──┤ in the chat's thread, with buttons
task asks a question ──chat.postMessage (bot token)─┤ to the task's channel, or routes[line] otherwise
inbox request opens ───chat.postMessage (bot token)─┤ to the task's channel, or routes[line] otherwise
notice is raised ──────chat.postMessage (bot token)─┤ to notices_channel
run fails / task ends ──reactions + chat.postMessage┘ on and in the task's thread
```

## Version constraints

Terraform 1.11 is the floor because `value_wo` on `spotlight_secret` is a **write-only** attribute: Terraform sends the secret to Spotlight but never stores it in the plan or the state. `signing_secret` and `bot_token` are ephemeral variables for the same reason. Spotlight only takes new values when `secret_version` changes.

The module needs the Spotlight provider 0.1.0-rc.4 or later, the first release that calls the control plane's `/api/v1` resource API.

The module and the provider are release candidates. Terraform selects a release candidate only for an exact version, such as `version = "0.1.0-rc.4"`. It skips release candidates for `>=` and `~>`. Thus, pin the module and the provider to exact versions, as in [Usage](#usage).

Spotlight checks the integration's definition when you plan and apply, not the provider. If the definition format changes in a Spotlight release, update the module to the release that follows it.

## Usage

```hcl
terraform {
  required_providers {
    spotlight = {
      source  = "usespotlightai/spotlight"
      version = "0.1.0-rc.4"
    }
  }
}

module "slack" {
  source  = "usespotlightai/slack/spotlight"
  version = "0.1.0-rc.10" # x-release-please-version

  workspace = "acme"
  team      = "core"

  signing_secret = var.slack_signing_secret
  bot_token      = var.slack_bot_token

  routes = {
    delivery = "C024BE91L"
  }
}

output "slack_webhook_url" {
  value = module.slack.webhook_url
}
```

### Talk to the agent

A mention of the app starts a chat with the team's agent, for the Spotlight member who uses the email of the Slack user: as their sign-in email, or as an additional email they verified in Spotlight under Settings › Emails. See [Add another email to your account](https://docs.usespotlight.ai/docs/administration/add-another-email-to-your-account). The agent reads the repositories of the team's lines and answers in the thread. Files attached to a mention or a reply, such as screenshots, go to the agent with it. Spotlight downloads them with the bot token, which needs the `files:read` scope. Spotlight leaves behind a file larger than 25 MB, and a file that Slack gives no download address for. To continue the chat, mention the app again in the same thread. Only the person who started the chat can talk to it. The chat also shows on that person's Agent page in Spotlight.

When the agent proposes a task, its answer lists the open proposals, each with an **Accept** and a **Dismiss** button. Click **Accept** to create the task, or **Dismiss** to remove the proposal. You can also reply `@app accept` or `@app dismiss`. When more than one proposal is open, give its number, as in `@app accept 2`. Only a click of the person who started the chat acts. Another person gets a reply that says so. Each message of the app has an **Open in Spotlight** button.

A mention from a Slack user whose email is neither the sign-in email nor a verified email of a member gets a reply that says so, and starts no chat. The mention gets the same reply when the email cannot be read: the bot lacks the `users:read.email` scope, or the Slack user has no email, as for a bot or some guests. Set `harness` to choose the harness that answers, as in `codex`. By default, Spotlight uses its default harness.

A task created from a Slack chat posts its questions to the channel of that chat, each in a new thread, and mentions the person who started the chat. `routes` names the channel for the questions of a line's other tasks, by line key. A reply in the thread of a question answers it. In Spotlight, the reply shows the avatar of the member who uses the email of the Slack user, and a mention of the app at the start of the reply is removed.

A question shows the images attached to it, such as the screenshots of a handover, below its text. Slack shows PNG, JPEG and GIF images. Other files stay in Spotlight. The app uploads the images with the bot token, which needs the `files:write` scope. It waits up to 10 seconds until Slack has processed them, which it reads with the `files:read` scope. When an upload fails, an image is still not processed, or Slack refuses the images, the question is posted without them.

### Prepare the Slack app

1. Give the app's bot the scopes `app_mentions:read`, `chat:write`, `channels:history`, `files:read`, `files:write`, `reactions:write`, `users:read` and `users:read.email`, and reinstall the app. To show the status while the agent works, also turn on **Agents & AI Apps** in the app's settings.
2. Copy the app's bot token and signing secret into `bot_token` and `signing_secret`.
3. Run `terraform apply`.
4. In the app's event subscriptions, turn events on and give `webhook_url` as the request URL. Slack sends a challenge, the integration responds to it, and Slack marks the address verified.
5. Subscribe the bot to the `app_mention` and `message.channels` events, save, and reinstall the app if Slack asks.
6. In the app's interactivity settings, turn interactivity on and give `webhook_url` as the request URL. The buttons need it.

On a self-hosted Spotlight, set `spotlight_url` to your deployment's address so `webhook_url` is right.

### See what the agent does

While a run of the agent works on a chat, Slack shows the text in `status`, `is thinking…` by default, at the bottom of the chat's thread. Slack removes it when the app replies. Set `status` to `null` to turn it off.

When a run of a task from a Slack chat fails, the app reacts with the emoji in `failed_reaction`, `x` by default. The task stays open and asks its question as usual. When the task is complete, the app removes that reaction, reacts with the emoji in `finished_reaction`, `white_check_mark` by default, and says in the thread that the task is complete, with its pull request. The reactions go on the first message of the task's latest question thread. When the task asked no question, they go on the mention that started the chat. Set a reaction to `null` to turn it off. To turn off the message, remove `finished` from `notify`.

A mention in the thread of a finished task reopens the task. The app reacts to the mention with the emoji in `acknowledge`, `eyes` by default, and removes `finished_reaction` from the first message of the thread. Set `acknowledge` to `null` to turn that reaction off.

### Choose what the app posts

`notify` sets what the app posts to Slack. By default, it is `["questions", "finished"]`.

| Value | What the app posts | Where |
|---|---|---|
| `questions` | The questions of tasks | The channel of the task's Slack chat, or else `routes[line]` |
| `finished` | A message that the task is complete | The task's thread |
| `inbox_requests` | A request that waits for a person in the inbox: a run to grade, proposed memories, or a station alert | The channel of the task's Slack chat, or else `routes[line]` |
| `notices` | A notice of the team that is addressed to nobody, such as a config pull request that Spotlight opened | `notices_channel` |

Each post has an **Open in Spotlight** button. A notice that links to a pull request also has a button to it. When a request has no channel, because its task did not come from Slack and its line has no route, the app does not post it. A notice that is addressed to one person stays in that person's inbox. The app posts a request or a notice once, when it first opens. It does not post it again when it opens again.

```hcl
module "slack" {
  # ...

  notify          = ["questions", "finished", "inbox_requests", "notices"]
  notices_channel = "C024BE91L"

  routes = {
    delivery = "C024BE91L"
  }
}
```

`notices_channel` is needed when `notify` holds `notices`. Without `questions`, the app posts no questions, so nobody can answer them in Slack. The reactions in `finished_reaction` and `failed_reaction` do not depend on `notify`.

### Post from a hook or a station

Name the tool through the `tools` output, so a plan fails if the tool is renamed or removed:

```hcl
resource "spotlight_hook" "merges" {
  team_id = data.spotlight_team.core.id
  key     = "announce-merges"
  on      = "pull-request.merged"
  steps = [
    {
      name = "announce"
      call = module.slack.tools["post-message"]
      with = {
        channel = "C024BE91L"
        text    = "Merged $${{ event.url }}"
      }
    },
  ]
}
```

Set `post_message_approval` to make a person approve each post first.

### Keep the secrets yourself

To manage the secrets outside this module, for example read from AWS Secrets Manager, set `create_secrets = false` and give their names in `signing_secret_name` and `bot_token_name`. Bind the bot token's secret to `slack.com` and `files.slack.com` in the `authorization` header, with the prefix `Bearer `.

### Rotating the secrets

Give the new values in `signing_secret` and `bot_token`, and raise `secret_version`. Terraform sends both values again.

## Conditional creation

```hcl
module "slack" {
  source = "usespotlightai/slack/spotlight"

  create = false
  # ...
}
```

## Examples

- [complete](examples/complete)

## Testing

```sh
terraform init -backend=false
terraform test    # tests/*.tftest.hcl, against a mocked spotlight provider
```

## Contributing

Formatting, the generated sections of every README, tflint and `terraform validate` run through [pre-commit](https://pre-commit.com), which needs [terraform-docs](https://terraform-docs.io) and [tflint](https://github.com/terraform-linters/tflint) installed:

```sh
pre-commit install
pre-commit run --all-files
```

CI runs the same hooks and the tests on every pull request. Pull requests are squash-merged, and the title becomes the commit, so the title is a Conventional Commit with the Linear issue as the scope, as in `feat(SPO-123): Add a channel input`. Releases follow [semantic versioning](https://semver.org) and come from [release-please](https://github.com/googleapis/release-please): after each merge to `main` it updates one release pull request with the next version, the `version` in this README's usage example and the [CHANGELOG.md](CHANGELOG.md) entries. Merging that pull request tags the release and publishes it, and the Terraform Registry picks it up. `feat` and `fix` commits make a release. While `release-please-config.json` has `"prerelease": true`, each release is the next `-rc.N`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1.0-rc.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_spotlight"></a> [spotlight](#provider\_spotlight) | >= 0.1.0-rc.4 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [spotlight_integration.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/integration) | resource |
| [spotlight_secret.bot_token](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_secret.signing](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/resources/secret) | resource |
| [spotlight_team.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/team) | data source |
| [spotlight_workspace.this](https://registry.terraform.io/providers/usespotlightai/spotlight/latest/docs/data-sources/workspace) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_team"></a> [team](#input\_team) | The key of the team the integration belongs to, as in `core`. | `string` | n/a | yes |
| <a name="input_workspace"></a> [workspace](#input\_workspace) | The slug of the Spotlight workspace, as in `acme`. | `string` | n/a | yes |
| <a name="input_acknowledge"></a> [acknowledge](#input\_acknowledge) | The name of the emoji the app reacts with on a mention that reopens a finished task from its thread, as in `eyes`. The bot then needs the `reactions:write` scope. Null turns the reaction off. | `string` | `"eyes"` | no |
| <a name="input_bot_token"></a> [bot\_token](#input\_bot\_token) | The Slack app's bot token (`xoxb-`). Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_bot_token_name"></a> [bot\_token\_name](#input\_bot\_token\_name) | The name of the workspace secret that holds the bot token. | `string` | `"SLACK_BOT_TOKEN"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create the integration and its secrets. False creates nothing. | `bool` | `true` | no |
| <a name="input_create_secrets"></a> [create\_secrets](#input\_create\_secrets) | Whether the module creates the two secrets from `signing_secret` and `bot_token`. False uses the workspace secrets named `signing_secret_name` and `bot_token_name`, which you keep yourself; the bot token's secret must then be bound to `slack.com` and `files.slack.com` in the `authorization` header, with the prefix `Bearer `. | `bool` | `true` | no |
| <a name="input_failed_reaction"></a> [failed\_reaction](#input\_failed\_reaction) | The name of the emoji the app reacts with when a run of a task from Slack fails, as in `x`. It goes on the same message as `finished_reaction`, and comes off when the task is complete. Null turns the reaction off. | `string` | `"x"` | no |
| <a name="input_finished_reaction"></a> [finished\_reaction](#input\_finished\_reaction) | The name of the emoji the app reacts with when a task from Slack is complete, as in `white_check_mark`. It goes on the first message of the task's question thread, or on the mention that started the chat when the task asked nothing. The bot then needs the `reactions:write` scope. Null turns the reaction off. | `string` | `"white_check_mark"` | no |
| <a name="input_harness"></a> [harness](#input\_harness) | The harness that answers in a chat started from a mention, as in `codex`. Null uses Spotlight's default harness. | `string` | `null` | no |
| <a name="input_integration"></a> [integration](#input\_integration) | The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `slack.app_mention`. Fixed for the integration's life. | `string` | `"slack"` | no |
| <a name="input_logo"></a> [logo](#input\_logo) | The mark the web app shows for the integration, as a base64 data URI of an SVG, PNG, WebP or JPEG image or as an https address. By default, the mark of Slack. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | What the integration is called in the web app. | `string` | `"Slack"` | no |
| <a name="input_notices_channel"></a> [notices\_channel](#input\_notices\_channel) | The Slack channel ID for team notices, as in `C024BE91L`. Needed when `notify` holds `notices`, and not used otherwise. | `string` | `null` | no |
| <a name="input_notify"></a> [notify](#input\_notify) | What the app posts to Slack. `questions` posts the questions of tasks. `finished` says in the thread of a task that the task is complete. `inbox_requests` posts the requests that wait for a person in the inbox, such as a run to grade, proposed memories or a station alert, to the channel of their task, or else to `routes[line]`. `notices` posts the notices of the team that are addressed to nobody, such as a config pull request that Spotlight opened, to `notices_channel`. | `set(string)` | <pre>[<br/>  "questions",<br/>  "finished"<br/>]</pre> | no |
| <a name="input_post_message_approval"></a> [post\_message\_approval](#input\_post\_message\_approval) | When set, each use of the `post-message` tool first asks a person, who is shown this text. Null lets agents and hooks post without asking. | `string` | `null` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | The Slack channel ID for the questions and inbox requests of tasks that do not come from a Slack chat, by line key, as in `{ delivery = "C024BE91L" }`. A task created from a Slack chat posts its questions to the channel of that chat, in a new thread. | `map(string)` | `{}` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Change it when `signing_secret` or `bot_token` changes, so Terraform sends the new values to Spotlight. | `number` | `1` | no |
| <a name="input_signing_secret"></a> [signing\_secret](#input\_signing\_secret) | The Slack app's signing secret. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_signing_secret_name"></a> [signing\_secret\_name](#input\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. | `string` | `"SLACK_SIGNING_SECRET"` | no |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight. | `string` | `"https://app.usespotlight.ai"` | no |
| <a name="input_status"></a> [status](#input\_status) | The status Slack shows in a chat's thread while the agent works, as in `is thinking…`. Slack clears it when the app replies. The bot then needs the `assistant:write` or `chat:write` scope. Null turns the status off. | `string` | `"is thinking…"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The integration's address in the workspace, as in `core/slack`. |
| <a name="output_bot_token_name"></a> [bot\_token\_name](#output\_bot\_token\_name) | The name of the workspace secret that holds the bot token. |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises: `mentioned` when someone mentions the app, `replied` when someone replies in a thread, `clicked` when someone clicks a button of the app. |
| <a name="output_id"></a> [id](#output\_id) | The integration's ID. |
| <a name="output_signing_secret_name"></a> [signing\_secret\_name](#output\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name, to the name a station or hook gives it by, as in `{ post-message = "slack.post-message" }`. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The request URL to give in the Slack app's event subscriptions. |
<!-- END_TF_DOCS -->

## License

Apache 2.0. See [LICENSE](LICENSE).
