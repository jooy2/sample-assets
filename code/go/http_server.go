// A small HTTP server on the standard library alone: routing, JSON, and
// middleware.

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

type Station struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Zone int    `json:"zone"`
}

var stations = []Station{
	{ID: "ST-001", Name: "Alder Cross", Zone: 2},
	{ID: "ST-002", Name: "Quill Wharf", Zone: 3},
	{ID: "ST-003", Name: "Saltwick Halt", Zone: 5},
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Println("encode failed:", err)
	}
}

func listStations(w http.ResponseWriter, r *http.Request) {
	zone := r.URL.Query().Get("zone")
	if zone == "" {
		writeJSON(w, http.StatusOK, stations)
		return
	}

	filtered := make([]Station, 0, len(stations))
	for _, station := range stations {
		if fmt.Sprint(station.Zone) == zone {
			filtered = append(filtered, station)
		}
	}
	writeJSON(w, http.StatusOK, filtered)
}

// Go 1.22 patterns carry the method and the path variables.
func getStation(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	for _, station := range stations {
		if station.ID == id {
			writeJSON(w, http.StatusOK, station)
			return
		}
	}
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "no such station"})
}

// Middleware wraps a handler and returns another handler.
func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s in %v", r.Method, r.URL.Path, time.Since(started))
	})
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	mux.HandleFunc("GET /api/v1/stations", listStations)
	mux.HandleFunc("GET /api/v1/stations/{id}", getStation)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           logRequests(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Println("listening on http://localhost:8080/api/v1/stations")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
