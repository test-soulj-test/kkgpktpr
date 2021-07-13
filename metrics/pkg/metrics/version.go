package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	appInfo = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: namespace,
		Subsystem: "version",
		Name:      "info",
		Help:      "Version info metadata",
	}, []string{"build_date", "revision"})
)

// Init initializes the metrics package
func Init(buildDate, revision string) {
	appInfo.WithLabelValues(buildDate, revision).Add(0)
}
