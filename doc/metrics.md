# Metrics

This project regularly generates Prometheus metrics for the [Release Management
dashboard] via [scheduled task].

## Development

In order to add a new metric or update an existing one, you'll probably want a
local [Pushgateway] to push metrics too, and a local [Prometheus] server to
query the metrics.

### Setup

See <https://prometheus.io/docs/introduction/first_steps/> for installing and
running Prometheus depending on your environment.

See <https://github.com/prometheus/pushgateway#run-it> for installing and
running the Pushgateway, as well as setting it up as a scraping endpoint.

### Adding a new metric

See the [existing metrics] to get an idea of the structure of a single metric.
The `METRIC`, `DESCRIPTION`, and `LABELS` constants are not required but are a
good practice.

The `initialize` method in each metric is usually pretty similar. You need a
**registry** to hold the metric(s), a **push gateway** to push the metric(s) to,
and one or more **metrics** to track the things you're monitoring.

Beyond that, the `execute` method performs the needed metric-gathering, and
pushes the registry at the end.

Finally, add a [task](https://gitlab.com/gitlab-org/release-tools/blob/master/lib/tasks/metrics.rake)
for your new metric so that it gets included in the regular `rake metrics` run.

### Testing locally

Provide the `PROMETHEUS_HOST` and `PUSHGATEWAY_URL` environment variables and execute your task:

```shell
$ PROMETHEUS_HOST='localhost:9090' PUSHGATEWAY_URL='http://localhost:9091' be rake metrics:my_new_metric
```

Note that depending on what your metric does, you may need to provide additional
[environment variables](./variables.md), for example if you need to interact
with the gitlab.com API.

[Release Management dashboard]: https://dashboards.gitlab.net/d/delivery-release_management/delivery-release-management
[scheduled task]: https://ops.gitlab.net/gitlab-org/release/tools/-/pipeline_schedules
[Pushgateway]: https://github.com/prometheus/pushgateway
[Prometheus]: https://prometheus.io/
[existing metrics]: https://gitlab.com/gitlab-org/release-tools/blob/master/lib/release_tools/metrics/

---

[Return to Documentation](../README.md#documentation)
