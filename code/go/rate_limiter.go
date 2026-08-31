// rate_limiter.go — four rate limiters and a harness that compares them.
//
// A token bucket, a fixed window, a sliding window log, and a sliding window
// counter, all behind one interface, plus a per-key registry with eviction, a
// context-aware blocking waiter, and a middleware that applies a limiter to a
// stream of requests.
//
//	go run rate_limiter.go
//	go vet rate_limiter.go
//
// The clock is injected throughout, so the comparison at the bottom is
// deterministic rather than dependent on how fast the machine happens to be.
//
// One file, standard library only.
package main

import (
	"context"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"
	"time"
)

// ------------------------------------------------------------------- clock

// Clock is the only source of time in this file. A real deployment passes
// realClock; the demonstration passes a fake one it can wind forward.
type Clock interface {
	Now() time.Time
	Sleep(context.Context, time.Duration) error
}

type realClock struct{}

func (realClock) Now() time.Time { return time.Now() }

func (realClock) Sleep(ctx context.Context, d time.Duration) error {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// fakeClock advances only when told to, which makes every result below
// reproducible.
type fakeClock struct {
	mu  sync.Mutex
	now time.Time
}

func newFakeClock() *fakeClock {
	return &fakeClock{now: origin}
}

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.now
}

func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = c.now.Add(d)
}

// Set winds the clock back to a known instant so each comparison below starts
// from the same place. It goes through the mutex like every other access;
// assigning the field directly would be a race the day something reads it
// from another goroutine.
func (c *fakeClock) Set(t time.Time) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.now = t
}

// origin is the instant every demonstration starts from.
var origin = time.Date(2027, 9, 2, 9, 0, 0, 0, time.UTC)

func (c *fakeClock) Sleep(ctx context.Context, d time.Duration) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	c.Advance(d)
	return nil
}

// ------------------------------------------------------------------ errors

var (
	// ErrLimited is returned when a request is refused.
	ErrLimited = errors.New("rate limited")
	// ErrWouldExceedDeadline is returned when waiting would outlast the
	// context's deadline, so the caller is told immediately instead of
	// blocking and failing later.
	ErrWouldExceedDeadline = errors.New("waiting would exceed the deadline")
)

// Decision is what a limiter answers with.
type Decision struct {
	Allowed    bool
	Remaining  int
	RetryAfter time.Duration
	Limit      int
	ResetsAt   time.Time
}

// Headers renders the decision the way an HTTP API conventionally would.
func (d Decision) Headers() map[string]string {
	headers := map[string]string{
		"RateLimit-Limit":     fmt.Sprint(d.Limit),
		"RateLimit-Remaining": fmt.Sprint(d.Remaining),
		"RateLimit-Reset":     fmt.Sprint(int(math.Ceil(d.RetryAfter.Seconds()))),
	}
	if !d.Allowed {
		headers["Retry-After"] = fmt.Sprint(int(math.Ceil(d.RetryAfter.Seconds())))
	}
	return headers
}

// Limiter is what every algorithm below implements.
type Limiter interface {
	// Allow reports whether one unit of work may proceed now.
	Allow() Decision
	// AllowN is the same for n units at once.
	AllowN(n int) Decision
	// Name identifies the algorithm in a report.
	Name() string
}

// ------------------------------------------------------------ token bucket

// TokenBucket refills continuously and allows a burst up to its capacity.
// It is the algorithm most people mean when they say "rate limit".
type TokenBucket struct {
	mu sync.Mutex

	capacity   float64
	perSecond  float64
	tokens     float64
	lastRefill time.Time
	clock      Clock
}

// NewTokenBucket allows `rate` units per second, bursting up to `burst`.
func NewTokenBucket(rate float64, burst int, clock Clock) *TokenBucket {
	return &TokenBucket{
		capacity:   float64(burst),
		perSecond:  rate,
		tokens:     float64(burst),
		lastRefill: clock.Now(),
		clock:      clock,
	}
}

func (b *TokenBucket) Name() string {
	return fmt.Sprintf("token bucket (%.0f/s, burst %.0f)", b.perSecond, b.capacity)
}

// refill must be called with the mutex held.
func (b *TokenBucket) refill(now time.Time) {
	elapsed := now.Sub(b.lastRefill).Seconds()
	if elapsed <= 0 {
		return
	}
	b.tokens = math.Min(b.capacity, b.tokens+elapsed*b.perSecond)
	b.lastRefill = now
}

func (b *TokenBucket) Allow() Decision { return b.AllowN(1) }

func (b *TokenBucket) AllowN(n int) Decision {
	b.mu.Lock()
	defer b.mu.Unlock()

	now := b.clock.Now()
	b.refill(now)

	needed := float64(n)
	if b.tokens >= needed {
		b.tokens -= needed
		return Decision{
			Allowed:   true,
			Remaining: int(b.tokens),
			Limit:     int(b.capacity),
			ResetsAt:  now.Add(b.timeToFull()),
		}
	}

	// How long until enough tokens have accumulated.
	shortfall := needed - b.tokens
	wait := time.Duration(shortfall / b.perSecond * float64(time.Second))
	return Decision{
		Allowed:    false,
		Remaining:  int(b.tokens),
		RetryAfter: wait,
		Limit:      int(b.capacity),
		ResetsAt:   now.Add(wait),
	}
}

func (b *TokenBucket) timeToFull() time.Duration {
	missing := b.capacity - b.tokens
	if missing <= 0 {
		return 0
	}
	return time.Duration(missing / b.perSecond * float64(time.Second))
}

// Wait blocks until a token is available, or the context ends first.
func (b *TokenBucket) Wait(ctx context.Context) error {
	for {
		decision := b.AllowN(1)
		if decision.Allowed {
			return nil
		}

		if deadline, ok := ctx.Deadline(); ok {
			if b.clock.Now().Add(decision.RetryAfter).After(deadline) {
				return fmt.Errorf("waiting %v: %w", decision.RetryAfter,
					ErrWouldExceedDeadline)
			}
		}
		if err := b.clock.Sleep(ctx, decision.RetryAfter); err != nil {
			return err
		}
	}
}

// ------------------------------------------------------------ fixed window

// FixedWindow counts requests in aligned windows. Simple, cheap, and it lets
// twice the limit through across a window boundary -- which is the reason the
// sliding variants below exist.
type FixedWindow struct {
	mu sync.Mutex

	limit     int
	window    time.Duration
	count     int
	windowKey int64
	clock     Clock
}

func NewFixedWindow(limit int, window time.Duration, clock Clock) *FixedWindow {
	return &FixedWindow{limit: limit, window: window, clock: clock}
}

func (w *FixedWindow) Name() string {
	return fmt.Sprintf("fixed window (%d per %v)", w.limit, w.window)
}

func (w *FixedWindow) Allow() Decision { return w.AllowN(1) }

func (w *FixedWindow) AllowN(n int) Decision {
	w.mu.Lock()
	defer w.mu.Unlock()

	now := w.clock.Now()
	key := now.UnixNano() / int64(w.window)
	if key != w.windowKey {
		w.windowKey = key
		w.count = 0
	}

	resetsAt := time.Unix(0, (key+1)*int64(w.window))

	if w.count+n <= w.limit {
		w.count += n
		return Decision{
			Allowed:   true,
			Remaining: w.limit - w.count,
			Limit:     w.limit,
			ResetsAt:  resetsAt,
		}
	}

	return Decision{
		Allowed:    false,
		Remaining:  w.limit - w.count,
		RetryAfter: resetsAt.Sub(now),
		Limit:      w.limit,
		ResetsAt:   resetsAt,
	}
}

// ------------------------------------------------------- sliding window log

// SlidingWindowLog keeps a timestamp per request. Exact, and its memory grows
// with the limit, which is the trade nobody mentions until it matters.
type SlidingWindowLog struct {
	mu sync.Mutex

	limit  int
	window time.Duration
	times  []time.Time
	clock  Clock
}

func NewSlidingWindowLog(limit int, window time.Duration, clock Clock) *SlidingWindowLog {
	return &SlidingWindowLog{
		limit:  limit,
		window: window,
		times:  make([]time.Time, 0, limit),
		clock:  clock,
	}
}

func (l *SlidingWindowLog) Name() string {
	return fmt.Sprintf("sliding log (%d per %v)", l.limit, l.window)
}

func (l *SlidingWindowLog) Allow() Decision { return l.AllowN(1) }

func (l *SlidingWindowLog) AllowN(n int) Decision {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.clock.Now()
	cutoff := now.Add(-l.window)

	// Drop everything that has fallen out of the window. The slice is in
	// order, so this is a prefix.
	keep := 0
	for keep < len(l.times) && !l.times[keep].After(cutoff) {
		keep++
	}
	l.times = l.times[keep:]

	if len(l.times)+n <= l.limit {
		for i := 0; i < n; i++ {
			l.times = append(l.times, now)
		}
		return Decision{
			Allowed:   true,
			Remaining: l.limit - len(l.times),
			Limit:     l.limit,
			ResetsAt:  now.Add(l.window),
		}
	}

	// The next slot frees when the oldest entry leaves the window.
	wait := l.times[0].Add(l.window).Sub(now)
	return Decision{
		Allowed:    false,
		Remaining:  0,
		RetryAfter: wait,
		Limit:      l.limit,
		ResetsAt:   now.Add(wait),
	}
}

// --------------------------------------------------- sliding window counter

// SlidingWindowCounter interpolates between the previous window's count and
// the current one. Nearly as smooth as the log, at constant memory, and the
// approximation is what most production limiters actually run.
type SlidingWindowCounter struct {
	mu sync.Mutex

	limit        int
	window       time.Duration
	currentKey   int64
	currentCount int
	previous     int
	clock        Clock
}

func NewSlidingWindowCounter(limit int, window time.Duration, clock Clock) *SlidingWindowCounter {
	return &SlidingWindowCounter{limit: limit, window: window, clock: clock}
}

func (c *SlidingWindowCounter) Name() string {
	return fmt.Sprintf("sliding counter (%d per %v)", c.limit, c.window)
}

func (c *SlidingWindowCounter) Allow() Decision { return c.AllowN(1) }

func (c *SlidingWindowCounter) AllowN(n int) Decision {
	c.mu.Lock()
	defer c.mu.Unlock()

	now := c.clock.Now()
	key := now.UnixNano() / int64(c.window)

	switch {
	case key == c.currentKey:
		// same window, nothing to roll
	case key == c.currentKey+1:
		c.previous = c.currentCount
		c.currentCount = 0
		c.currentKey = key
	default:
		c.previous = 0
		c.currentCount = 0
		c.currentKey = key
	}

	elapsed := now.Sub(time.Unix(0, key*int64(c.window)))
	weight := 1 - float64(elapsed)/float64(c.window)
	estimate := float64(c.previous)*weight + float64(c.currentCount)

	resetsAt := time.Unix(0, (key+1)*int64(c.window))

	if estimate+float64(n) <= float64(c.limit) {
		c.currentCount += n
		return Decision{
			Allowed:   true,
			Remaining: c.limit - int(math.Ceil(estimate)) - n,
			Limit:     c.limit,
			ResetsAt:  resetsAt,
		}
	}

	return Decision{
		Allowed:    false,
		Remaining:  0,
		RetryAfter: resetsAt.Sub(now),
		Limit:      c.limit,
		ResetsAt:   resetsAt,
	}
}

// ---------------------------------------------------------------- registry

// Registry hands out one limiter per key and forgets keys nothing has used
// for a while, so a limiter per client does not become a memory leak per
// client that ever connected.
type Registry struct {
	mu    sync.Mutex
	build func() Limiter
	idle  time.Duration
	clock Clock

	entries map[string]*entry
}

type entry struct {
	limiter Limiter
	lastUse time.Time
}

func NewRegistry(build func() Limiter, idle time.Duration, clock Clock) *Registry {
	return &Registry{
		build:   build,
		idle:    idle,
		clock:   clock,
		entries: make(map[string]*entry),
	}
}

func (r *Registry) For(key string) Limiter {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := r.clock.Now()
	found, ok := r.entries[key]
	if !ok {
		found = &entry{limiter: r.build()}
		r.entries[key] = found
	}
	found.lastUse = now
	return found.limiter
}

// Evict removes limiters unused for longer than the idle period and returns
// how many went.
func (r *Registry) Evict() int {
	r.mu.Lock()
	defer r.mu.Unlock()

	cutoff := r.clock.Now().Add(-r.idle)
	removed := 0
	for key, found := range r.entries {
		if found.lastUse.Before(cutoff) {
			delete(r.entries, key)
			removed++
		}
	}
	return removed
}

func (r *Registry) Size() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.entries)
}

// -------------------------------------------------------------- middleware

// Request is a stand-in for whatever is being limited.
type Request struct {
	Client string
	Path   string
	Cost   int
}

// Outcome records what happened to one request.
type Outcome struct {
	Request  Request
	Decision Decision
	At       time.Time
}

// Gate applies a per-client limiter to a sequence of requests.
type Gate struct {
	registry *Registry
	clock    Clock
	outcomes []Outcome
	mu       sync.Mutex
}

func NewGate(registry *Registry, clock Clock) *Gate {
	return &Gate{registry: registry, clock: clock}
}

func (g *Gate) Handle(request Request) Decision {
	cost := request.Cost
	if cost < 1 {
		cost = 1
	}
	decision := g.registry.For(request.Client).AllowN(cost)

	g.mu.Lock()
	g.outcomes = append(g.outcomes, Outcome{request, decision, g.clock.Now()})
	g.mu.Unlock()

	return decision
}

func (g *Gate) Summary() string {
	g.mu.Lock()
	defer g.mu.Unlock()

	allowed := map[string]int{}
	refused := map[string]int{}
	for _, outcome := range g.outcomes {
		if outcome.Decision.Allowed {
			allowed[outcome.Request.Client]++
		} else {
			refused[outcome.Request.Client]++
		}
	}

	clients := make([]string, 0, len(allowed)+len(refused))
	seen := map[string]bool{}
	for _, source := range []map[string]int{allowed, refused} {
		for client := range source {
			if !seen[client] {
				seen[client] = true
				clients = append(clients, client)
			}
		}
	}
	sort.Strings(clients)

	var builder strings.Builder
	for _, client := range clients {
		fmt.Fprintf(&builder, "  %-12s %3d allowed, %3d refused\n",
			client, allowed[client], refused[client])
	}
	return builder.String()
}

// --------------------------------------------------------------------- main

func compare(clock *fakeClock, limiters []Limiter) {
	// The same traffic through every limiter: a burst of ten, a pause, then
	// one request per second.
	type step struct {
		advance time.Duration
		count   int
		label   string
	}
	steps := []step{
		{0, 10, "burst of 10 at t=0"},
		{500 * time.Millisecond, 5, "5 more at t=0.5s"},
		{500 * time.Millisecond, 5, "5 more at t=1.0s"},
		{2 * time.Second, 5, "5 more at t=3.0s"},
		{7 * time.Second, 10, "10 more at t=10.0s"},
	}

	results := make(map[string][]string, len(limiters))

	for _, limiter := range limiters {
		// Each limiter gets its own run over the same script, from the same
		// starting time.
		clock.Set(origin)
		var lines []string

		for _, s := range steps {
			clock.Advance(s.advance)
			allowed := 0
			for i := 0; i < s.count; i++ {
				if limiter.Allow().Allowed {
					allowed++
				}
			}
			lines = append(lines, fmt.Sprintf("%2d/%2d", allowed, s.count))
		}
		results[limiter.Name()] = lines
	}

	names := make([]string, 0, len(results))
	for name := range results {
		names = append(names, name)
	}
	sort.Strings(names)

	fmt.Printf("  %-34s", "algorithm")
	for _, s := range steps {
		fmt.Printf(" %-7s", strings.SplitN(s.label, " at ", 2)[1])
	}
	fmt.Println()
	fmt.Printf("  %s\n", strings.Repeat("-", 34+len(steps)*8))

	for _, name := range names {
		fmt.Printf("  %-34s", name)
		for _, cell := range results[name] {
			fmt.Printf(" %-7s", cell)
		}
		fmt.Println()
	}
}

func main() {
	clock := newFakeClock()

	fmt.Println("--- one token bucket, step by step ---")
	bucket := NewTokenBucket(2, 5, clock)
	for i := 1; i <= 8; i++ {
		decision := bucket.Allow()
		verdict := "allowed"
		if !decision.Allowed {
			verdict = fmt.Sprintf("refused, retry in %v", decision.RetryAfter.Round(time.Millisecond))
		}
		fmt.Printf("  request %d: %-34s remaining %d\n", i, verdict, decision.Remaining)
	}

	fmt.Println("\n  after two seconds of refill:")
	clock.Advance(2 * time.Second)
	for i := 9; i <= 12; i++ {
		decision := bucket.Allow()
		verdict := "allowed"
		if !decision.Allowed {
			verdict = "refused"
		}
		fmt.Printf("  request %d: %-34s remaining %d\n", i, verdict, decision.Remaining)
	}

	fmt.Println("\n--- the headers a response would carry ---")
	refused := bucket.AllowN(10)
	headers := refused.Headers()
	keys := make([]string, 0, len(headers))
	for key := range headers {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		fmt.Printf("  %-22s %s\n", key+":", headers[key])
	}

	fmt.Println("\n--- the same traffic through four algorithms ---")
	compare(clock, []Limiter{
		NewTokenBucket(5, 10, clock),
		NewFixedWindow(10, time.Second, clock),
		NewSlidingWindowLog(10, time.Second, clock),
		NewSlidingWindowCounter(10, time.Second, clock),
	})
	fmt.Println("\n  The fixed window lets fifteen through across the t=0.5/t=1.0")
	fmt.Println("  boundary, which is exactly the burst the sliding variants avoid.")

	fmt.Println("\n--- waiting rather than failing ---")
	clock.Set(origin)
	waiter := NewTokenBucket(4, 2, clock)
	started := clock.Now()
	ctx := context.Background()
	for i := 1; i <= 6; i++ {
		if err := waiter.Wait(ctx); err != nil {
			fmt.Printf("  request %d: %v\n", i, err)
			break
		}
		fmt.Printf("  request %d proceeded at t=%v\n", i,
			clock.Now().Sub(started).Round(time.Millisecond))
	}

	fmt.Println("\n--- a deadline the wait cannot meet ---")
	tight, cancel := context.WithDeadline(context.Background(),
		clock.Now().Add(100*time.Millisecond))
	defer cancel()
	slow := NewTokenBucket(1, 1, clock)
	slow.Allow() // drain the single token
	err := slow.Wait(tight)
	fmt.Printf("  %v\n", err)
	fmt.Printf("  errors.Is(err, ErrWouldExceedDeadline): %v\n",
		errors.Is(err, ErrWouldExceedDeadline))

	fmt.Println("\n--- a limiter per client ---")
	clock.Set(origin)
	registry := NewRegistry(
		func() Limiter { return NewSlidingWindowLog(5, time.Second, clock) },
		30*time.Second,
		clock,
	)
	gate := NewGate(registry, clock)

	traffic := []Request{}
	for i := 0; i < 8; i++ {
		traffic = append(traffic, Request{"198.51.100.24", "/api/routes", 1})
	}
	for i := 0; i < 3; i++ {
		traffic = append(traffic, Request{"203.0.113.7", "/api/routes", 1})
	}
	traffic = append(traffic, Request{"192.0.2.9", "/api/sailings", 4})
	traffic = append(traffic, Request{"192.0.2.9", "/api/sailings", 4})

	for _, request := range traffic {
		gate.Handle(request)
	}
	fmt.Print(gate.Summary())
	fmt.Printf("  the registry holds %d client(s)\n", registry.Size())

	fmt.Println("\n--- eviction ---")
	clock.Advance(45 * time.Second)
	registry.For("198.51.100.24") // keep this one warm
	removed := registry.Evict()
	fmt.Printf("  evicted %d idle client(s), %d remain\n", removed, registry.Size())

	fmt.Println("\n--- concurrent use ---")
	clock.Set(origin)
	shared := NewTokenBucket(1000, 100, clock)
	var group sync.WaitGroup
	var mu sync.Mutex
	allowed := 0

	for worker := 0; worker < 20; worker++ {
		group.Add(1)
		go func() {
			defer group.Done()
			local := 0
			for i := 0; i < 20; i++ {
				if shared.Allow().Allowed {
					local++
				}
			}
			mu.Lock()
			allowed += local
			mu.Unlock()
		}()
	}
	group.Wait()
	fmt.Printf("  20 goroutines x 20 requests against a burst of 100: %d allowed\n", allowed)
	fmt.Printf("  exactly the burst, never more: %v\n", allowed == 100)
}
