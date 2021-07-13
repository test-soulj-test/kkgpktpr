package logger

import (
	"context"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"

	"gitlab.com/gitlab-org/labkit/log"
)

type ctxKey string

const (
	logKey = ctxKey("logger")
)

// AccessLogMiddleware logs each requests
func AccessLogMiddleware(logger *logrus.Logger) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {
		return log.AccessLogger(next,
			log.WithAccessLogger(logger),
			log.WithFieldsExcluded(log.CorrelationID),
		)
	}
}

// InjectorMiddleware injects the logger into request context
// on a http.Handler we can get the logger using the Get function
func InjectorMiddleware(logger *logrus.Logger) mux.MiddlewareFunc {
	return func(next http.Handler) http.Handler {

		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx := context.WithValue(r.Context(), logKey, logger)
			req := r.WithContext(ctx)

			next.ServeHTTP(w, req)
		})
	}
}

// Get retrieves the logger from the given request
func Get(r *http.Request) *logrus.Logger {
	if logger, ok := r.Context().Value(logKey).(*logrus.Logger); ok {
		return logger
	}

	return nil
}
