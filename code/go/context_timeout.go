// A context carries a deadline and a cancel signal down a call chain, so
// slow work can be abandoned.

package main

import (
	"context"
	"errors"
	"fmt"
	"time"
)

func fetch(ctx context.Context, name string, takes time.Duration) (string, error) {
	select {
	case <-time.After(takes):
		return name + " ready", nil
	case <-ctx.Done():
		// ctx.Err() says whether it was a deadline or an explicit cancel.
		return "", fmt.Errorf("fetching %s: %w", name, ctx.Err())
	}
}

func main() {
	// Finishes inside the deadline.
	fast, cancelFast := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancelFast()

	if value, err := fetch(fast, "cached-report", 20*time.Millisecond); err == nil {
		fmt.Println(value)
	}

	// Runs past the deadline.
	slow, cancelSlow := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancelSlow()

	if _, err := fetch(slow, "full-export", 300*time.Millisecond); err != nil {
		fmt.Println("error:", err)
		fmt.Println("deadline exceeded:", errors.Is(err, context.DeadlineExceeded))
	}

	// Cancelled by hand, from somewhere else.
	manual, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(30 * time.Millisecond)
		cancel()
	}()

	if _, err := fetch(manual, "live-feed", time.Second); err != nil {
		fmt.Println("error:", err)
		fmt.Println("cancelled:", errors.Is(err, context.Canceled))
	}

	// Values travel with the context, for request-scoped data only.
	type keyType string
	const requestID keyType = "request-id"

	ctx := context.WithValue(context.Background(), requestID, "req-4821")
	fmt.Println("request id:", ctx.Value(requestID))
}
