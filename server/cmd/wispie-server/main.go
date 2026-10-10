package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sillygru/wispie/server/internal/config"
	"github.com/sillygru/wispie/server/internal/server"
	"github.com/sillygru/wispie/server/internal/store"
)

func main() {
	cmd := "serve"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}
	cfg, err := config.FromOS()
	if err != nil {
		fatal(err)
	}
	switch cmd {
	case "serve":
		fatal(serve(cfg))
	case "stats":
		st, err := store.Open(cfg.DataDir)
		if err != nil {
			fatal(err)
		}
		defer st.Close()
		s, err := st.Stats()
		if err != nil {
			fatal(err)
		}
		fmt.Printf("accounts: %d, storage: %.1f MiB\n", s.Accounts, float64(s.StorageBytes)/(1<<20))
	default:
		fmt.Fprintln(os.Stderr, "usage: wispie-server [serve|stats]")
		os.Exit(2)
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}

func serve(cfg config.Config) error {
	st, err := store.Open(cfg.DataDir)
	if err != nil {
		return err
	}
	defer st.Close()
	logger := log.New(os.Stdout, "", log.LstdFlags|log.LUTC)
	srv := server.New(cfg, st, time.Now, logger)
	hs := server.HTTPServer(cfg, srv.Handler)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				if err := srv.Sync.GC(time.Now()); err != nil {
					logger.Printf("gc failed: %v", err)
				}
			}
		}
	}()
	go func() {
		<-ctx.Done()
		sc, c := context.WithTimeout(context.Background(), 10*time.Second)
		defer c()
		_ = hs.Shutdown(sc)
	}()
	logger.Printf("wispie-server listening on %s", cfg.Addr)
	if err := hs.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}
