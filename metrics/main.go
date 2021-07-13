package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"gitlab.com/gitlab-org/labkit/log"

	"gitlab.com/gitlab-org/release-tools/metrics/pkg/logger"
	"gitlab.com/gitlab-org/release-tools/metrics/pkg/metrics"
)

var (
	// BuildDate is injected at build time using -X main.BuildDate=value
	BuildDate = "Unknown"
	// Revision is injected at build time using -X main.Revision=$CI_COMMIT_SHORT_SHA
	Revision = "Development"
)

func main() {
	metrics.Init(BuildDate, Revision)

	/*******************************
	 *  flags and configuration    *
	 *******************************/

	var wait time.Duration
	var port int
	var logFormat string
	flag.DurationVar(&wait, "graceful-timeout", time.Second*10, "the duration for which the server gracefully wait for existing connections to finish - e.g. 15s or 1m")
	flag.IntVar(&port, "port", 2112, "listening port")
	flag.StringVar(&logFormat, "log-format", "text", "the log format. It can be text, json, or color")

	flag.Parse()

	logrus := log.New()
	closer, err := log.Initialize(
		log.WithLogger(logrus),
		log.WithFormatter(logFormat),
		log.WithLogLevel("info"),
		log.WithOutputName("stderr"),
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "FATAL: Logger initialization failed. %v\n", err)
		os.Exit(1)
	}
	defer closer.Close()

	logrus.WithField("revision", Revision).WithField("build_date", BuildDate).Info("Booting")

	/*******************************
	 *  HTTP server                *
	 *******************************/

	r := mux.NewRouter()
	r.Use(logger.AccessLogMiddleware(logrus))
	r.Handle("/metrics", promhttp.Handler())
	apiRouter := r.PathPrefix("/api").Subrouter()
	metrics.PlugRoutes(apiRouter, os.Getenv("AUTH_TOKEN"))

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%d", port),
		WriteTimeout: time.Second * 5,
		ReadTimeout:  time.Second * 5,
		IdleTimeout:  time.Second * 10,
		Handler:      r,
	}

	/*******************************
	 *  Graceful Shutdown          *
	 *******************************/

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Run our server in a goroutine so that it doesn't block.
	go func() {
		logrus.WithField("addr", srv.Addr).Info("Accepting incoming connections")

		if err := srv.ListenAndServe(); err != nil {
			logrus.WithError(err).Error("Server shutdown")
			cancel()
		}
	}()

	// We'll accept graceful shutdowns when quit via SIGINT
	// or SIGTERM (Kubernets termination signal)
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT)

	// Block until we receive our signal or the main context is Done
	select {
	case sig := <-sigs:
		logrus.WithField("signal", sig).Warn("Signal received")

		// Create a deadline to wait for
		ctxGrace, cancelGrace := context.WithTimeout(ctx, wait)
		defer cancelGrace()

		// Doesn't block if no connections, but will otherwise wait
		// until the timeout deadline.
		logrus.WithField("timeout", wait).Info("Begin graceful shutdown")
		if err := srv.Shutdown(ctxGrace); err != nil {
			logrus.WithError(err).Error("Graceful shutdown failed")
		}
	case <-ctx.Done():
		logrus.WithError(ctx.Err()).Info("Main context expired")
	}

	logrus.Error("Bye")
}
