// Package server assembles the HTTP handler tree.
package server

import (
	"log"
	"net/http"
	"time"

	"github.com/sillygru/wispie/server/internal/auth"
	"github.com/sillygru/wispie/server/internal/config"
	"github.com/sillygru/wispie/server/internal/httpx"
	"github.com/sillygru/wispie/server/internal/store"
	syncsvc "github.com/sillygru/wispie/server/internal/sync"
)

type Server struct {
	Auth    *auth.Service
	Sync    *syncsvc.Service
	Handler http.Handler
}

func New(cfg config.Config, st *store.Store, now func() time.Time, logger *log.Logger) *Server {
	a := auth.New(st, cfg, now)
	sy := syncsvc.New(st, cfg, now, a)
	mux := http.NewServeMux()
	a.Routes(mux)
	sy.Routes(mux)
	h := a.GlobalLimit(mux)
	if logger != nil {
		h = httpx.Logging(logger, h)
	}
	return &Server{Auth: a, Sync: sy, Handler: h}
}

func HTTPServer(cfg config.Config, h http.Handler) *http.Server {
	return &http.Server{
		Addr:              cfg.Addr,
		Handler:           h,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      120 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    8 << 10,
	}
}
