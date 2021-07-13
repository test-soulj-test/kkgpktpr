package metrics

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	deploymentDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Namespace: namespace,
		Subsystem: "deployment",
		Name:      "duration_seconds",
		Help:      "Duration of the coordinated deployment pipeline, from staging to production",
		Buckets:   prometheus.LinearBuckets(12_600, 30*60, 6), // 6 buckets of 30 minutes starting at 3.5 hrs
	}, []string{"deployment_type", "status"})
)

func deploymentsHandlerFunc(w http.ResponseWriter, r *http.Request) {
	duration, err := getValue(r)
	if err != nil {
		badRequest(w, r, "Missing or wrong value parameter")

		return
	}

	labels := getLabels(r)
	if len(labels) != 2 {
		badRequest(w, r, "Two labels expected")

		return
	}

	deploymentDuration.WithLabelValues(labels...).Observe(duration)

	answer(w, r, "New deployment recorded")
}
