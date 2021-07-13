package metrics

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"

	"gitlab.com/gitlab-org/release-tools/metrics/pkg/logger"
)

func PlugRoutes(r *mux.Router, authToken string) {
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := r.Header.Get("X-Private-Token")
			if token != authToken {
				w.WriteHeader(http.StatusUnauthorized)
				answer(w, r, "Missing or wrong X-Private-Token")

				return
			}

			next.ServeHTTP(w, r)
		})
	})

	r.HandleFunc("/deployment_duration_seconds/observe", deploymentsHandlerFunc)
}

func getValue(r *http.Request) (float64, error) {
	raw := r.FormValue("value")

	return strconv.ParseFloat(raw, 64)
}

func getLabels(r *http.Request) []string {
	labels := r.FormValue("labels")

	return strings.Split(labels, ",")
}

func badRequest(w http.ResponseWriter, r *http.Request, reason string) {
	w.WriteHeader(http.StatusBadRequest)
	answer(w, r, reason)
}

func answer(w http.ResponseWriter, r *http.Request, message string) {
	_, err := w.Write([]byte(message))
	if err != nil {
		log := logger.Get(r)
		log.WithError(err).Error("Cannot write the HTTP answer")
	}
}
