package logger

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

func TestLoggerInjection(t *testing.T) {
	logger := logrus.New()

	mux := mux.NewRouter()
	mux.Use(InjectorMiddleware(logger))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log := Get(r)
		if log == nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
	})

	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	// Check the status code is what we expect.
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("logger was not injected")
	}
}
