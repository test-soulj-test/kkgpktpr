# ChatOps

While most of the functionality of release-tools is ultimately performed via
[Rake tasks](./rake-tasks.md), the preferred way to run tasks is via [GitLab
ChatOps][chatops].

Performing these tasks via ChatOps offers some important benefits:

- release-tools doesn't need to be configured with its required [CI
  Variables](./variables.md)
- Task runs won't be interrupted by spotty internet connections or
  random computer issues
- Anyone can follow the progress of a task by viewing its CI job
- The release manager doesn't need to switch away from Slack as frequently

[chatops]: https://gitlab.com/gitlab-com/chatops

## Preparation

Before you're able to run any ChatOps commands, your Slack account needs to be
authenticated to the ChatOps project. Run `/chatops` in Slack to introduce
yourself to the bot, who will help get you authenticated.

Once authenticated, you can run `/chatops help` to see a list of available
commands.

Commands implemented for release tools are all performed via `/chatops run
[command]`. All `run` commands take a `--help` flag that details their available
options.

Many commands take a `--security` flag which will perform the corresponding
security-related task rather than the "normal" task.

## Tasks

We won't attempt to document _every_ ChatOps command here, but rather outline
tasks that one may routinely be performing as a release manager.

### Preparing a new release

```sh
# Prepare a new patch release
/chatops run release prepare 12.8.7

# Prepare a new security release (note: verisons are determined automatically)
/chatops run release prepare --security
```

### Cherry-picking changes for an upcoming release

```sh
# Cherry-pick merge requests labeled `Pick into 12.8` into preparation branches
/chatops run release merge 12.8.7

# Merge pending security merge requests
/chatops run release merge --security
```

### Tag a new release

```sh
# Tag a normal release
/chatops run release tag 12.8.7

# Tag a security release
/chatops run release tag 12.7.5 --security
```

### Create a new auto-deploy branch

```sh
/chatops run auto_deploy prepare
```

### Tag a new auto-deploy

```sh
/chatops run auto_deploy tag
```

## Technical details

ChatOps commands are implemented in the [ChatOps project][chatops-commands].
Those commands use [triggers](https://docs.gitlab.com/ee/ci/triggers/) to
trigger the `chatops` job in this project, which runs
[`bin/chatops`](../bin/chatops), which triggers the appropriate [Rake
task](./rake-tasks.md).

[chatops-commands]: https://gitlab.com/gitlab-com/chatops/tree/master/lib/chatops/commands

---

[Return to Documentation](./README.md)
