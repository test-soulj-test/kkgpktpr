# delivery-metrics

This is a specialized Prometheus Pushgateway designed to be used from our CI jobs.

It can easily keep track of histograms implementing an HTTP API around Prometheus metrics.


## Architecture

`delivery-metrics` is a Go software exposing an HTTP endpoint, on the `/metrics` path we have a standard prometheus metrics,
on the `/api` path we have custom handlers to add data to our metrics.

### Deployment

`delivery-metrics` implements continous delivery using a bridge job to
trigger a [tanka deployment](https://gitlab.com/gitlab-com/gl-infra/k8s-workloads/tanka-deployments/-/tree/master/environments/delivery-metrics)
when a change in this directory is detected or when the
`BUILD_DELIVERY_METRICS` variable is set to `true` on an OPS pipeline.

### Access control

The `/api` path requires a token to allow write operations.
The token must be provided as an HTTP header named `X-Private-Token`.

The software compares the user provided token with the content of the `AUTH_TOKEN` environment variable.

### Working with histograms

It is possible to add values to an histogram making a `POST` request to the metric `observe` method.
The request is form-encoded and requires 2 parameters:

- **value**: the observed value
- **labels**: a comma-separated list of label values. Label values are positional.

**example**

``` shell
curl -X POST \
	-H "X-Private-Token: MYTEST" \
	-F value=18000 \
	-F "labels=coordinator_pipeline,success" \
	"http://127.0.0.1:2112/api/deployment_duration_seconds/observe"
```
