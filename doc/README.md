# Documentation

- [Rake tasks](./rake-tasks.md) contained in this project
- [ChatOps triggers](./chatops.md) available from this project
- [Issue templates](../templates) used for creating the release task lists
- [CI variables](./variables.md) used by this project
- [Metrics](./metrics.md) contains information on developing metrics gathered
  by this project
- [Releases using the API](./api-releases.md) provides information about the
  code used for performing releases using the API

## Development

### Retrying API requests with Retriable

Developers should program defensively when interacting with the GitLab API by
retrying requests that fail due to timeouts or other intermittent failures.

This project utilizes the [Retriable][] gem to make this easier, and a context
has been added to simplify this common use case:

```ruby
# Automatically retry the request in the event of a `Timeout::Error`,
# `Errno::ECONNRESET`, or `Gitlab::Error::ResponseError` exception
Retriable.with_context(:api) do
  # ...
end

# Contexts support all additional Retriable parameters
Retriable.with_context(:api, retries: 10, on: StandardError) do
  # ...
end

# WARNING: Supplying `on` to `with_context` will *override* the exception list
#
# This block will only retry on `SomeRareException` and nothing else!
Retriable.with_context(:api, on: SomeRareException) do
  # ...
end
```

[Retriable]: https://github.com/kamui/retriable

## Testing

Project changes must be made via [merge requests] and go through code review by
members of the Delivery team.

The project has a [fairly comprehensive][coverage] RSpec-based test suite. New
functionality should be covered by automated testing.

[merge requests]: https://gitlab.com/gitlab-org/release-tools/-/merge_requests
[coverage]: http://gitlab-org.gitlab.io/release-tools/coverage/

### Running tests

To run the full test suite, use `bundle exec rspec`. This project includes the
[Fuubar formatter](https://github.com/thekompanee/fuubar) for rapid failure
feedback:

```sh
bundle exec rspec -f Fuubar
```

Targeted tests can be executed by passing a specific file to test, and even a
specific line:

```
bundle exec rspec -f Fuubar -- spec/lib/release_tools/my_class_spec.rb:5
```
