package main

import (
	"fmt"
	"load-balancer/src/config"
	"load-balancer/src/scheduler"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
)

func main() {
	logger := log.Default()

	cfg, err := config.LoadConfig("config.yaml")

	if err != nil {
		log.Fatal("Could not load configurations", err)
	}

	addr := fmt.Sprintf(":%d", cfg.Server.Port)

	addresses := cfg.Upstream.App.Backends
	backends := make([]*scheduler.Backend, 0, len(addresses))

	for _, addr := range addresses {
		u, err := url.Parse(addr)
		if err != nil {
			log.Fatal("Invalid url: ", addr)
		}

		backends = append(backends, &scheduler.Backend{Url: u})
	}

	scheduler := &scheduler.Scheduler{
		Backends: backends,
		FailureProps: scheduler.FailureProps{
			MaxFail:                int(cfg.Upstream.App.Fail.MaxFail),
			TimeoutDurationSeconds: int(cfg.Upstream.App.Fail.FailTimeout),
			FailureWindowSeconds:   int(cfg.Upstream.App.Fail.FailTimeframe),
		},
	}

	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			backend := scheduler.PickTarget()
			logger.Println("Forwarding request to: ", backend)

			req.URL.Scheme = backend.Scheme
			req.URL.Host = backend.Host
		},

		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			logger.Printf("Proxy error for %s: %v\n", r.URL, err)
			scheduler.RecordFailure(r.URL)
		},
	}

	log.Printf("Load balancer listening on http://localhost%s", addr)
	log.Fatal(http.ListenAndServe(addr, proxy))
}
