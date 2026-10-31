# Complete Slack integration

A Slack integration on the `core` team of the `acme` workspace that creates its two secrets, posts the questions of the delivery line's other tasks to one channel, and asks a person before each use of the `post-message` tool. A second instance shows `create = false`, which creates nothing.

## Usage

Prepare the Slack app first (see [Prepare the Slack app](../../README.md#prepare-the-slack-app)), then:

```bash
terraform init
terraform plan
terraform apply
```

Give the `webhook_url` output as the request URL in the Slack app's event subscriptions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_spotlight"></a> [spotlight](#requirement\_spotlight) | >= 0.1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_slack"></a> [slack](#module\_slack) | ../.. | n/a |
| <a name="module_slack_disabled"></a> [slack\_disabled](#module\_slack\_disabled) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_slack_bot_token"></a> [slack\_bot\_token](#input\_slack\_bot\_token) | The Slack app's bot token. | `string` | n/a | yes |
| <a name="input_slack_signing_secret"></a> [slack\_signing\_secret](#input\_slack\_signing\_secret) | The Slack app's signing secret. | `string` | n/a | yes |
| <a name="input_spotlight_url"></a> [spotlight\_url](#input\_spotlight\_url) | The Spotlight the integration is created in. | `string` | `"https://app.usespotlight.ai"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_happenings"></a> [happenings](#output\_happenings) | The happenings the integration raises. |
| <a name="output_tools"></a> [tools](#output\_tools) | The integration's tools, by name. |
| <a name="output_webhook_url"></a> [webhook\_url](#output\_webhook\_url) | The request URL to give in the Slack app's event subscriptions. |
<!-- END_TF_DOCS -->
