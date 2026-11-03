# Changelog

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
