# terraform-spotlight-slack

A Spotlight integration for a Slack app. A mention of the app opens a task, the task's questions are posted to Slack, and a reply in a question's thread answers it.

The module creates a `spotlight_integration` and, unless you keep them yourself, the two `spotlight_secret`s it uses: the app's signing secret, which verifies that deliveries come from Slack, and its bot token, bound to `slack.com`. The integration also gives agents and hooks a `post-message` tool.

```
Slack ──event (signed with the signing secret)──▶ webhook_url
                                                    │ verify, answer url_verification
                                                    ▼
                         app_mention  → opens a task at line_role / station, marked with its thread
                         thread reply → answers the question asked in that thread
                                                    │
task asks a question ──chat.postMessage (bot token)─┘ to the task's channel, or routes[line] otherwise
```

## Version constraints

Terraform 1.11 is the floor because `value_wo` on `spotlight_secret` is a **write-only** attribute: Terraform sends the secret to Spotlight but never stores it in the plan or the state. `signing_secret` and `bot_token` are ephemeral variables for the same reason. Spotlight only takes new values when `secret_version` changes.

Spotlight checks the integration's definition when you plan and apply, not the provider. If the definition format changes in a Spotlight release, update the module to the release that follows it.

## Usage

```hcl
module "slack" {
  source  = "usespotlightai/slack/spotlight"
  version = "~> 0.1"

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

A task opened from Slack posts its questions to the channel it was opened from. `routes` names the channel for questions from a line's other tasks, by line key.

By default a mention opens a task on the line whose role is `delivery`, at the station keyed `triage`, as on the built-in Delivery line. Set `line_role` and `station` to open it elsewhere.

### Prepare the Slack app

1. Give the app's bot the scopes `app_mentions:read`, `chat:write` and `channels:history`, and reinstall the app.
2. Copy the app's bot token and signing secret into `bot_token` and `signing_secret`.
3. Run `terraform apply`.
4. In the app's event subscriptions, turn events on and give `webhook_url` as the request URL. Slack sends a challenge, the integration responds to it, and Slack marks the address verified.
5. Subscribe the bot to the `app_mention` and `message.channels` events, save, and reinstall the app if Slack asks.

On a self-hosted Spotlight, set `spotlight_url` to your deployment's address so `webhook_url` is right.

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

To manage the secrets outside this module, for example read from AWS Secrets Manager, set `create_secrets = false` and give their names in `signing_secret_name` and `bot_token_name`. Bind the bot token's secret to `slack.com` in the `authorization` header, with the prefix `Bearer `.

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
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_spotlight"></a> [spotlight](#provider\_spotlight) | >= 0.1 |

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
| <a name="input_bot_token"></a> [bot\_token](#input\_bot\_token) | The Slack app's bot token (`xoxb-`). Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_bot_token_name"></a> [bot\_token\_name](#input\_bot\_token\_name) | The name of the workspace secret that holds the bot token. | `string` | `"SLACK_BOT_TOKEN"` | no |
| <a name="input_create"></a> [create](#input\_create) | Whether to create the integration and its secrets. False creates nothing. | `bool` | `true` | no |
| <a name="input_create_secrets"></a> [create\_secrets](#input\_create\_secrets) | Whether the module creates the two secrets from `signing_secret` and `bot_token`. False uses the workspace secrets named `signing_secret_name` and `bot_token_name`, which you keep yourself; the bot token's secret must then be bound to `slack.com` in the `authorization` header, with the prefix `Bearer `. | `bool` | `true` | no |
| <a name="input_integration"></a> [integration](#input\_integration) | The integration's name in the team. It is the last part of the webhook address, and the first part of every happening and mark kind the integration raises, as in `slack.app_mention`. Fixed for the integration's life. | `string` | `"slack"` | no |
| <a name="input_line_role"></a> [line\_role](#input\_line\_role) | The role of the line that a mention opens a task on. | `string` | `"delivery"` | no |
| <a name="input_name"></a> [name](#input\_name) | What the integration is called in the web app. | `string` | `"Slack"` | no |
| <a name="input_post_message_approval"></a> [post\_message\_approval](#input\_post\_message\_approval) | When set, each use of the `post-message` tool first asks a person, who is shown this text. Null lets agents and hooks post without asking. | `string` | `null` | no |
| <a name="input_routes"></a> [routes](#input\_routes) | The Slack channel ID for the questions of tasks that were not opened from Slack, by line key, as in `{ delivery = "C024BE91L" }`. A task opened from Slack posts its questions to the channel it was opened from. | `map(string)` | `{}` | no |
| <a name="input_secret_version"></a> [secret\_version](#input\_secret\_version) | Change it when `signing_secret` or `bot_token` changes, so Terraform sends the new values to Spotlight. | `number` | `1` | no |
| <a name="input_signing_secret"></a> [signing\_secret](#input\_signing\_secret) | The Slack app's signing secret. Needed when `create_secrets` is true. | `string` | `null` | no |
| <a name="input_signing_secret_name"></a> [signing\_secret\_name](#input\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. | `string` | `"SLACK_SIGNING_SECRET"` | no |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The address of your Spotlight, used only for the `webhook_url` output. Change it for a self-hosted Spotlight. | `string` | `"https://app.usespotlight.ai"` | no |
| <a name="input_station"></a> [station](#input\_station) | The key of the station that a task opened from a mention starts at. | `string` | `"triage"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The integration's address in the workspace, as in `core/slack`. |
| <a name="output_bot_token_name"></a> [bot\_token\_name](#output\_bot\_token\_name) | The name of the workspace secret that holds the bot token. |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises: `mentioned` when someone mentions the app, `replied` when someone replies in a thread. |
| <a name="output_id"></a> [id](#output\_id) | The integration's ID. |
| <a name="output_signing_secret_name"></a> [signing\_secret\_name](#output\_signing\_secret\_name) | The name of the workspace secret that holds the signing secret. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name, to the name a station or hook gives it by, as in `{ post-message = "slack.post-message" }`. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The request URL to give in the Slack app's event subscriptions. |
<!-- END_TF_DOCS -->

## License

Apache 2.0. See [LICENSE](LICENSE).
