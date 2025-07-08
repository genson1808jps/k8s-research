package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/gorilla/mux"
)

type Server struct {
	port      string
	version   string
	env       string
	dbURL     string
	secret    string
	startTime time.Time
}

func NewServer() *Server {
	port := getEnv("PORT", "8080")
	version := getEnv("APP_VERSION", "v1.0.0")
	env := getEnv("ENVIRONMENT", "development")
	dbURL := getEnv("DATABASE_URL", "localhost:5432")
	secret := getEnv("API_SECRET", "default-secret")

	return &Server{
		port:      port,
		version:   version,
		env:       env,
		dbURL:     dbURL,
		secret:    secret,
		startTime: time.Now(),
	}
}

func (s *Server) setupRoutes() *mux.Router {
	router := mux.NewRouter()

	// Health checks
	router.HandleFunc("/health", s.healthHandler).Methods("GET")
	router.HandleFunc("/ready", s.readinessHandler).Methods("GET")

	// Main endpoints
	router.HandleFunc("/", s.homeHandler).Methods("GET")
	router.HandleFunc("/api/info", s.infoHandler).Methods("GET")
	router.HandleFunc("/api/config", s.configHandler).Methods("GET")
	router.HandleFunc("/api/metrics", s.metricsHandler).Methods("GET")
	router.HandleFunc("/api/load", s.loadHandler).Methods("GET")

	return router
}

func (s *Server) homeHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	response := fmt.Sprintf(`
		<h1>Kubernetes Demo App</h1>
		<p><strong>Version:</strong> %s</p>
		<p><strong>Environment:</strong> %s</p>
		<p><strong>Hostname:</strong> %s</p>
		<p><strong>Uptime:</strong> %v</p>
		<hr>
		<h3>Available Endpoints:</h3>
		<ul>
			<li><a href="/health">/health</a> - Health check</li>
			<li><a href="/ready">/ready</a> - Readiness probe</li>
			<li><a href="/api/info">/api/info</a> - App info</li>
			<li><a href="/api/config">/api/config</a> - Configuration</li>
			<li><a href="/api/metrics">/api/metrics</a> - Metrics</li>
			<li><a href="/api/load">/api/load</a> - Load test</li>
		</ul>
	`, s.version, s.env, hostname, time.Since(s.startTime))

	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
}

func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	response := fmt.Sprintf(`{"status":"healthy","timestamp":"%s"}`, time.Now().Format(time.RFC3339))
	w.Write([]byte(response))
}

func (s *Server) readinessHandler(w http.ResponseWriter, r *http.Request) {
	// Simulate readiness check - ready after 10 seconds
	if time.Since(s.startTime) < 10*time.Second {
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"status":"not ready","message":"starting up"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ready"}`))
}

func (s *Server) infoHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	pid := os.Getpid()

	w.Header().Set("Content-Type", "application/json")
	response := fmt.Sprintf(`{
		"version": "%s",
		"environment": "%s",
		"hostname": "%s",
		"pid": %d,
		"uptime": "%v",
		"timestamp": "%s"
	}`, s.version, s.env, hostname, pid, time.Since(s.startTime), time.Now().Format(time.RFC3339))

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
}

func (s *Server) configHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	response := fmt.Sprintf(`{
		"port": "%s",
		"database_url": "%s",
		"environment": "%s",
		"version": "%s",
		"has_secret": %t
	}`, s.port, s.dbURL, s.env, s.version, s.secret != "default-secret")

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
}

func (s *Server) metricsHandler(w http.ResponseWriter, r *http.Request) {
	// Simple metrics simulation
	uptime := time.Since(s.startTime).Seconds()

	w.Header().Set("Content-Type", "text/plain")
	response := fmt.Sprintf(`# HELP app_uptime_seconds Application uptime in seconds
# TYPE app_uptime_seconds counter
app_uptime_seconds %.2f

# HELP app_version_info Application version info
# TYPE app_version_info gauge
app_version_info{version="%s",environment="%s"} 1
`, uptime, s.version, s.env)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
}

func (s *Server) loadHandler(w http.ResponseWriter, r *http.Request) {
	// CPU intensive task để test HPA
	iterations := 1000000
	if iter := r.URL.Query().Get("iterations"); iter != "" {
		if i, err := strconv.Atoi(iter); err == nil {
			iterations = i
		}
	}

	start := time.Now()
	sum := 0
	for i := 0; i < iterations; i++ {
		sum += i
	}
	duration := time.Since(start)

	w.Header().Set("Content-Type", "application/json")
	response := fmt.Sprintf(`{
		"message": "Load test completed",
		"iterations": %d,
		"result": %d,
		"duration_ms": %.2f
	}`, iterations, sum, duration.Seconds()*1000)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))
}

func (s *Server) Start() error {
	router := s.setupRoutes()

	srv := &http.Server{
		Handler:      router,
		Addr:         ":" + s.port,
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("Server starting on port %s", s.port)
		log.Printf("Version: %s, Environment: %s", s.version, s.env)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed to start: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	server := NewServer()
	if err := server.Start(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
