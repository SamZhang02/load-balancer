package scheduler

import (
	"errors"
	"log"
	"net/url"
	"sync"
	"time"
)

type Backend struct {
	Url *url.URL

	Fails []time.Time // FIFO queue
	UnhealthyUntil time.Time
}

type FailureProps struct {
	MaxFail int
	FailureWindowSeconds int
	TimeoutDurationSeconds int
}

type Scheduler struct {
	Backends  []*Backend
	FailureProps FailureProps
	currentAddrIndex int
	mu sync.Mutex
}

func urlsEqual(a, b *url.URL) bool {
	if a == nil || b == nil {
		return false
	}

	return a.Scheme == b.Scheme &&
		a.Host == b.Host 
}

func (s *Scheduler) getBackend(u *url.URL) (*Backend, error) {
	for _, backend := range s.Backends {
		if urlsEqual(u, backend.Url) {
			return backend, nil
		}
	}
	return nil, errors.New("No backend found")
}

func (s *Scheduler) PickTarget() *url.URL {
	s.mu.Lock()
	if s.currentAddrIndex == len(s.Backends)-1 {
		s.currentAddrIndex = 0
	} else {
		s.currentAddrIndex++
	}

	for time.Now().Before(s.Backends[s.currentAddrIndex].UnhealthyUntil) {
	if s.currentAddrIndex == len(s.Backends)-1 {
			s.currentAddrIndex = 0
	} else {
		s.currentAddrIndex++ 
		}
	}

	s.mu.Unlock()

	return s.Backends[s.currentAddrIndex].Url
}

func (s *Scheduler) RecordFailure(url *url.URL) {
	logger := log.Default()
	now := time.Now()
	backend, err := s.getBackend(url)

	if err != nil {
		logger.Printf("Could not find backend for url %s", url)
		return 
	}

	window := time.Duration(s.FailureProps.FailureWindowSeconds) * time.Second

	for len(backend.Fails) > 0 &&
			backend.Fails[0].Before(now.Add(-window)) {
		backend.Fails = backend.Fails[1:]
	}

	backend.Fails = append(backend.Fails, now)

	if len(backend.Fails) >= s.FailureProps.MaxFail {
		s.markAsUnhealthy(backend)
	}
}

func (s *Scheduler) markAsUnhealthy(backend *Backend) {
	log.Printf("Marking %s as unhealthy, timing out for %d seconds", backend.Url, s.FailureProps.TimeoutDurationSeconds)

	now := time.Now()
	backend.UnhealthyUntil = now.Add(time.Duration(s.FailureProps.TimeoutDurationSeconds) * time.Second)
}
