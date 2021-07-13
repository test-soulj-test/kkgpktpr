# Releases using the API

The namespace `ReleaseTools::PublicRelease` defines a variety of types used to
perform GitLab releases using the GitLab API, instead of using a locally cloned
Git repository. Using the API brings several benefits:

1. It's faster because we don't need to clone many Git repositories
1. It's easier to use compared to the API provided by libgit2/rugged and the Git
   CLI
1. It's easier to make the release steps idempotent
1. It's less fragile as we don't have to deal with escaping input when executing
   shell commands

The API release code uses and depends on the GitLab.com API. It's not possible
to perform the API release tasks on dev.gitlab.org.

For every component to release there exists a class. For example, GitLab CE and
EE releases are handled by the class
`ReleaseTools::PublicRelease::GitlabRelease`. Using a separate class for
components makes it easier to understand, maintain, and test the code when
compared to an approach that involves multiple components being released by the
same code.

In addition, release steps within a component are handled by separate methods
where possible. For example, for Gitaly we use the method `create_target_branch`
to create the target/stable branch, and the method `compile_changelog` to
compile the changelog. This separation again makes it easier to work with the
code, as you can tackle release steps one at a time.

Perhaps the most important part of the code layout is that we don't rely on
inheritance, instead using composition using Ruby modules. Prior to the
introduction of the API based release code we did use inheritance for our
release classes. This resulted in release code being spread across many files
and inheritance chains, making it difficult to work with the code. For example,
changing the way how tags are created would immediately affect all projects;
even when the change only matters to a limited number of projects.

The rationale behind the API based setup is further explained in
[this epic](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/236),
[this comment](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/113#note_329004701),
[and this comment](https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/690#note_302629704)

The mapping of component to class is as follows (the class names are relative to
the `ReleaseTools::PublicRelease` namespace):

| Component        | Class
|:-----------------|:--------------------------------------------
| GitLab CE        | `GitlabRelease`
| GitLab EE        | `GitlabRelease`
| Gitaly           | `GitalyMonthlyRelease`, `GitalyMasterRelease`
| Omnibus          | `OmnibusGitlabRelease`
| CNG              | `CNGImageRelease`
| Helm charts      | `HelmGitlabRelease`

The class `GitalyMasterRelease` is used by the Gitaly team to create RCs,
without the need for involving a release manager.

For GitLab CE and EE we do use a single class, as the release process for GitLab
CE is heavily tied into the release process of GitLab EE.

The use of the namespace `ReleaseTools::PublicRelease` is deliberate: we needed
a way to signal this code is only used for releases meant for public
consumption, such as patch releases (it's not used for auto-deploys). Using
`PublicRelease` felt like the most obvious way of signaling this, without having
to rely on lengthly namespace names.

## Class layout

While the classes follow a similar layout (e.g. they all have to implement the
`execute` method), this layout is only loosely enforced. For example, classes
define their own `initialize` methods and not all use the same method signature,
giving them full control over their input; instead of being limited by an
`initialize` method from a parent class.

## Stable branch creation

The API release code automatically creates stable branches from the right source
commit. For some projects this is the `master` branch, while for others its the
last deployed commit. If the stable branch already exists, it's used as-is.

These sources can be overwritten by setting the STABLE_BRANCH_SOURCE_COMMITS
environment variable to a SHA to use for a specific project. For example, to
release Gitaly from SHA 123abc and GitLab from SHA 456def you'd set this
variable as follows:

    STABLE_BRANCH_SOURCE_COMMITS='gitaly=123abc,gitlab=456def' rake release:tag[...]

The following keys in this variable are valid:

* gitaly
* gitlab
* omnibus
* cng
* helm

## Managing Helm charts

The release code (`HelmGitlabRelease`) for our Helm charts only supports
`Chart.yaml` files that it explicitly lists in its source code. If this code
encounters a Chart file it doesn't recognise, it will raise an error. This
ensures that we never make the wrong decision about how to manage Chart files
(e.g. by updating it to the wrong version). When an unrecognised Chart file is
found, the error will include details on how to resolve the problem.

## Releasing a single component

A unique feature of the API based setup is that you can run the release of a
single component, without having to clone any Git repositories. This can be
useful if a component was not release properly, but you don't want to re-release
everything else.

For this to work, you need to run a Pry console in the Release Tools project and
have at least the following environment variables set:

* `SLACK_TAG_URL`
* `RELEASE_BOT_DEV_TOKEN`
* `RELEASE_BOT_PRODUCTION_TOKEN`
* `RELEASE_BOT_OPS_TOKEN`

The values for these variables can be found [in the variables
settings](https://ops.gitlab.net/gitlab-org/release/tools/-/settings/ci_cd) of
the Release Tools ops.gitlab.net mirror.

You can then start a console as follows:

```bash
env SLACK_TAG_URL='...' \
    RELEASE_BOT_DEV_TOKEN='...' \
    RELEASE_BOT_PRODUCTION_TOKEN='...' \
    RELEASE_BOT_OPS_TOKEN='...' \
    bundle exec pry --gem
```

We can then run a release as follows:

```ruby
helm_ver = ReleaseTools::Version.new('50.0.0')
gl_ver = ReleaseTools::Version.new('43.0.0')

ReleaseTools::PublicRelease::HelmGitlabRelease.new(helm_ver, gl_ver).execute
```

This would then trigger a release of Helm version 50.0.0, mapped to GitLab
version 43.0.0.

**NOTE:** The exact arguments/order/etc may vary per class, to make sure to pass
the right arguments.

**NOTE:** As the API release code is idempotent, it's often easier to just
re-run the entire release process. Any work that has already been performed
won't be performed again.

## Annotated tags

All tags created must be annotated tags, as various components (e.g. Omnibus)
depend on tags being annotated; instead of being regular tags.

---

[Return to Documentation](./README.md)
