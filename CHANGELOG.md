# Changelog

## [0.1.0-rc.11](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.10...v0.1.0-rc.11) (2026-11-14)


### Features

* choose what the app posts to Slack ([#23](https://github.com/usespotlightai/terraform-spotlight-slack/issues/23)) ([7d2e2f1](https://github.com/usespotlightai/terraform-spotlight-slack/commit/7d2e2f1d69196f36175b38c8fd7b0b193ddcd2f8))

## [0.1.0-rc.10](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.9...v0.1.0-rc.10) (2026-11-11)


### Bug Fixes

* list the task's pull requests when it finishes ([#21](https://github.com/usespotlightai/terraform-spotlight-slack/issues/21)) ([33ffc34](https://github.com/usespotlightai/terraform-spotlight-slack/commit/33ffc3433f6022770b6482050b447b080ba9ad2d))

## [0.1.0-rc.9](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.8...v0.1.0-rc.9) (2026-11-11)


### Features

* send the Slack mark as the integration's logo ([#19](https://github.com/usespotlightai/terraform-spotlight-slack/issues/19)) ([1a63e89](https://github.com/usespotlightai/terraform-spotlight-slack/commit/1a63e89e30cd25ddd3ba4d18243b122dcb3e3acb))

## [0.1.0-rc.8](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.7...v0.1.0-rc.8) (2026-11-08)


### Bug Fixes

* set the thread status on chat.run-assigned ([#17](https://github.com/usespotlightai/terraform-spotlight-slack/issues/17)) ([3098634](https://github.com/usespotlightai/terraform-spotlight-slack/commit/3098634d00c48b016709f40689b11cfc54430fca))

## [0.1.0-rc.7](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.6...v0.1.0-rc.7) (2026-11-03)


### Bug Fixes

* wait until Slack has processed a question's images before posting it ([#15](https://github.com/usespotlightai/terraform-spotlight-slack/issues/15)) ([448a780](https://github.com/usespotlightai/terraform-spotlight-slack/commit/448a7806eb2f6bb19ac2add6cc1082b5bb069dd3))

## [0.1.0-rc.6](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.5...v0.1.0-rc.6) (2026-11-03)


### Features

* show a question's images in its Slack message ([#13](https://github.com/usespotlightai/terraform-spotlight-slack/issues/13)) ([8384ce7](https://github.com/usespotlightai/terraform-spotlight-slack/commit/8384ce7edf861f19399c215599c71710a5dff7dc))

## [0.1.0-rc.5](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.4...v0.1.0-rc.5) (2026-11-02)


### ⚠ BREAKING CHANGES

* the module needs a Spotlight whose `on` takes a list of bindings. `acknowledge` reacts only to a mention that reopens a task. Turn on interactivity with `webhook_url` as the request URL for the buttons.

### Features

* show a thinking status, buttons and task reactions in Slack ([#11](https://github.com/usespotlightai/terraform-spotlight-slack/issues/11)) ([8d484ea](https://github.com/usespotlightai/terraform-spotlight-slack/commit/8d484ea350ff94d34d4e79d328359ee592f5a954))

## [0.1.0-rc.4](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.3...v0.1.0-rc.4) (2026-11-02)


### Features

* react to a mention that reopens a task ([#10](https://github.com/usespotlightai/terraform-spotlight-slack/issues/10)) ([1005858](https://github.com/usespotlightai/terraform-spotlight-slack/commit/10058584a5b663685a489703a74e4a9842e8b8a2))
* sign a reply with its Slack user and drop the leading mention ([#9](https://github.com/usespotlightai/terraform-spotlight-slack/issues/9)) ([70dd3c4](https://github.com/usespotlightai/terraform-spotlight-slack/commit/70dd3c4f8811e61328fa9ac197f4fc7e42006a3c))


### Bug Fixes

* bring the files of a mention and a reply to the agent ([#7](https://github.com/usespotlightai/terraform-spotlight-slack/issues/7)) ([4faa112](https://github.com/usespotlightai/terraform-spotlight-slack/commit/4faa112fe056352c2c547d0b4b66d079945a876a))

## [0.1.0-rc.3](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.2...v0.1.0-rc.3) (2026-11-02)


### ⚠ BREAKING CHANGES

* **SPO-268:** start an agent chat from a mention ([#4](https://github.com/usespotlightai/terraform-spotlight-slack/issues/4))

### Features

* **SPO-268:** start an agent chat from a mention ([#4](https://github.com/usespotlightai/terraform-spotlight-slack/issues/4)) ([54aefb8](https://github.com/usespotlightai/terraform-spotlight-slack/commit/54aefb8c73c25b08bbe28143c984610097f3b783))

## [0.1.0-rc.2](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.1...v0.1.0-rc.2) (2026-11-01)


### Bug Fixes

* require provider 0.1.0-rc.4 or later and pin exact versions in the usage example ([#2](https://github.com/usespotlightai/terraform-spotlight-slack/issues/2)) ([7fecfb3](https://github.com/usespotlightai/terraform-spotlight-slack/commit/7fecfb38896786e0d3522f7b88e747531e6e27c3))

## [0.1.0-rc.1](https://github.com/usespotlightai/terraform-spotlight-slack/compare/v0.1.0-rc.0...v0.1.0-rc.1) (2026-10-31)


### Features

* add the Slack integration module ([9a5c932](https://github.com/usespotlightai/terraform-spotlight-slack/commit/9a5c93256d6fb00fcba8c0c3258843fd1a7ff1b1))
* react to a mention with the acknowledge emoji ([621d04d](https://github.com/usespotlightai/terraform-spotlight-slack/commit/621d04d8e54dc3b59560c31c674747594cdb0a84))

## Changelog
