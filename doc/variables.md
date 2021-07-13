# release-tools CI variables

This project makes heavy use of [environment variables] for configuration. This
document aims to provide a reference for the most important ones, but is not
necessarily comprehensive.

## Instance tokens

| Variable Name                  | Deployment         | Token name\*  | Scopes       | User                                                      |
| ------------                   | ------------       | ------------  | ------------ | ------------                                              |
| `RELEASE_BOT_DEV_TOKEN`        | dev.gitlab.org     | release-tools | api          | [@gitlab-release-tools-bot][gitlab-release-tools-bot-dev] |
| `RELEASE_BOT_OPS_TOKEN`        | ops.gitlab.net     | Release token | api          | [@gitlab-release-tools-bot][gitlab-release-tools-bot-ops] |
| `RELEASE_BOT_PRODUCTION_TOKEN` | gitlab.com         | release-tools | api          | [@gitlab-release-tools-bot][gitlab-release-tools-bot-com] |
| `RELEASE_BOT_VERSION_TOKEN`    | version.gitlab.com | private token | api          | robert+release-tools@gitlab.com                           |

_* Token name refers to the name that was entered when the token was created_

## SSH private keys

Private keys are used to push to repositories via SSH, rather than
authenticating over HTTPS with an access token.

- `RELEASE_BOT_PRIVATE_KEY` -- Private key for
  [@gitlab-release-tools-bot][gitlab-release-tools-bot-com].

## Auto-deploy

- `AUTO_DEPLOY_BRANCH` -- The current auto-deploy branch. Gets updated via API
  by auto-deploy jobs and **should not be changed manually.**
- `AUTO_DEPLOY_TAG` -- When specified, overrides the tag used by the coordinated
  pipeline.
- `DEPLOYER_TRIGGER_TOKEN` -- The trigger token for the [Deployer][deployer].
- `HELM_BUILD_TRIGGER_TOKEN` -- Used to trigger an Helm charts auto-deploy tagging.
- `SENTRY_AUTH_TOKEN` -- Used to create releases and deploys in Sentry. Requires the `project:releases` API scope.
- `IGNORE_PRODUCTION_CHECKS` -- The reason for bypassing the production checks. If set to `false` checks will not be skipped.

## Feature flags

- `FEATURE_INSTANCE_URL` -- Unleash endpoint for project feature flags
- `FEATURE_INSTANCE_ID` -- Unleash instance ID for project feature flags

## Metrics

- `PROMETHEUS_HOST` -- The `hostname:port` to a Prometheus instance, used for
  gathering current host versions for GitLab environments.
- `PUSHGATEWAY_URL` -- The full URL to a Pushgateway, where metrics gathered by
  this project will be pushed.
- `DELIVERY_METRICS_URL` -- The full URL to the delivery-metrics pushgateway,
  where metrics gathered by this project will be pushed.
- `DELIVERY_METRICS_TOKEN` -- The authorization token for the delivery-token pushgateway.
- `BUILD_DELIVERY_METRICS` -- When `true` it forces a build and deployment for `delivery-metrics` (**only on OPS**)

See the [metrics documentation](./metrics.md) for more information.

## Production checks

This project is triggered by [ChatOps], [deployer], and [Woodhouse] to check on
the health of the production environment. Because this is being done via
triggers, configuration flags are passed in via environment variables.

| Variable                         | Source(s)   | Type    | Use                                                                              |
| --------                         | ---------   | ----    | ---                                                                              |
| `CHAT_CHANNEL`                   | [ChatOps]   | String  | Slack channel ID in which to respond                                             |
| `CHECK_PRODUCTION`               | [ChatOps], [deployer], [Woodhouse] | Boolean | Tells CI to run `auto_deploy:check_production`            |
| `DEPLOYER_PIPELINE_URL`          | [deployer]  | String  | Full URL to the deployer pipeline that triggered the check                       |
| `DEPLOYER_JOB_URL`               | [deployer]  | String  | Full URL to the deployer job that triggered the check                            |
| `DEPLOYMENT_CHECK`               | [deployer]  | Boolean | Indicates if we're performing a check from an ongoing deployment                 |
| `DEPLOYMENT_STEP`                | [deployer]  | String  | Current deployment step                                                          |
| `DEPLOY_VERSION`                 | [deployer]  | String  | Version being deployed                                                           |
| `GITLAB_PRODUCTION_PROJECT_PATH` | [Woodhouse] | String  | Alternate path for `PRODUCTION_ISSUE_IID` project                                |
| `FAIL_IF_NOT_SAFE`               | [ChatOps]   | Boolean | Indicates if the job should fail (raise an exception) if production is unhealthy |
| `PRODUCTION_ISSUE_IID`           | [Woodhouse] | String  | Issue IID for a production incident                                              |
| `SKIP_DEPLOYMENT_CHECK`          | [ChatOps]   | Boolean | Indicates if we should skip the "ongoing deployment" check, such as when modifying a feature flag |

## Miscellany

- `ELASTIC_URL` -- Full Elasticsearch URL for inbound release-tools logs.
- `SENTRY_DSN` -- DSN for the `release-tools` project on
  [Sentry](https://sentry.gitlab.net/gitlab/release-tools/).
- `SLACK_CHATOPS_URL` -- Full Slack webhook URL for ChatOps responses.
- `SLACK_TAG_URL` -- Full Slack webhook URL for tagging notifications.
- `SLACK_WRAPPER_URL` -- Endpoint for [`slack-wrapper`](https://ops.gitlab.net/gitlab-com/gl-infra/infra-automation-commons/slack-wrapper)
- `SLACK_WRAPPER_TOKEN` -- `slack-wrapper` access token

[environment variables]: https://ops.gitlab.net/gitlab-org/release/tools/-/settings/ci_cd
[gitlab-release-tools-bot-com]: https://gitlab.com/gitlab-release-tools-bot
[gitlab-release-tools-bot-dev]: https://dev.gitlab.org/gitlab-release-tools-bot
[gitlab-release-tools-bot-ops]: https://ops.gitlab.net/gitlab-release-tools-bot

## AutoDeploy Variables

Many variables are associated with how deployments are completed.  This list can
be found here:
<https://gitlab.com/gitlab-org/release/docs/-/blob/master/runbooks/variables.md>

---

[Return to Documentation](./README.md)

[ChatOps]: https://gitlab.com/gitlab-com/chatops
[deployer]: https://ops.gitlab.net/gitlab-com/gl-infra/deployer
[Woodhouse]: https://ops.gitlab.net/gitlab-com/gl-infra/woodhouse
