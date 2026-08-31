// event_store.go — an append-only event store with projections.
//
// Generics with type constraints, interfaces satisfied implicitly, error
// wrapping with errors.Is and errors.As, a mutex-guarded store safe for
// concurrent use, functional options, contexts for cancellation, and
// table-driven verification at the bottom.
//
//	go run event_store.go
//	go vet event_store.go
//
// One file, standard library only. Every stream, actor, and figure below is
// invented.
package main

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
)

// ------------------------------------------------------------------ errors

// ErrConcurrency and friends are sentinels, so callers compare with errors.Is
// rather than by matching on message text.
var (
	ErrStreamNotFound = errors.New("stream not found")
	ErrEmptyStream    = errors.New("stream has no events")
	ErrClosed         = errors.New("store is closed")
)

// ConflictError carries enough detail for the caller to retry sensibly, which
// a sentinel could not.
type ConflictError struct {
	Stream   string
	Expected int
	Actual   int
}

func (e *ConflictError) Error() string {
	return fmt.Sprintf("stream %q: expected version %d, found %d",
		e.Stream, e.Expected, e.Actual)
}

// Is lets errors.Is(err, ErrConflict) work against any ConflictError.
func (e *ConflictError) Is(target error) bool { return target == ErrConflict }

// ErrConflict is the sentinel a caller tests against.
var ErrConflict = errors.New("optimistic concurrency conflict")

// ValidationError wraps whatever a handler rejected.
type ValidationError struct {
	Field  string
	Reason string
	inner  error
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("%s: %s", e.Field, e.Reason)
}

func (e *ValidationError) Unwrap() error { return e.inner }

// ------------------------------------------------------------------ events

// Event is what the store keeps. The payload is deliberately an interface:
// the store does not care what the events mean.
type Event struct {
	Stream   string
	Version  int
	Type     string
	At       time.Time
	Payload  any
	Metadata map[string]string
}

func (e Event) String() string {
	return fmt.Sprintf("%s@%d %s", e.Stream, e.Version, e.Type)
}

// Payload types. Each names itself, so the store can record a type without
// reflection and a projection can switch on it.
type named interface{ EventType() string }

type SailingScheduled struct {
	Route   string
	Departs string
	Seats   int
}

func (SailingScheduled) EventType() string { return "SailingScheduled" }

type SeatsBooked struct {
	Seats     int
	Reference string
}

func (SeatsBooked) EventType() string { return "SeatsBooked" }

type SeatsReleased struct {
	Seats     int
	Reference string
}

func (SeatsReleased) EventType() string { return "SeatsReleased" }

type SailingCancelled struct {
	Reason string
}

func (SailingCancelled) EventType() string { return "SailingCancelled" }

type SailingDelayed struct {
	Minutes int
	Reason  string
}

func (SailingDelayed) EventType() string { return "SailingDelayed" }

// ------------------------------------------------------------------- store

// Option configures a Store at construction. Functional options keep the
// constructor's signature stable as settings are added.
type Option func(*Store)

// WithClock replaces time.Now, which is what makes the tests deterministic.
func WithClock(clock func() time.Time) Option {
	return func(s *Store) { s.now = clock }
}

// WithSubscriberBuffer sets how many events a slow subscriber may fall behind
// before it is dropped.
func WithSubscriberBuffer(size int) Option {
	return func(s *Store) { s.buffer = size }
}

// Store is an append-only log, partitioned into streams, safe for concurrent
// use by multiple goroutines.
type Store struct {
	mu          sync.RWMutex
	streams     map[string][]Event
	all         []Event
	subscribers map[int]chan Event
	nextSub     int
	closed      bool

	now    func() time.Time
	buffer int
}

// NewStore builds a store. Options are applied in the order given.
func NewStore(options ...Option) *Store {
	store := &Store{
		streams:     make(map[string][]Event),
		subscribers: make(map[int]chan Event),
		now:         time.Now,
		buffer:      16,
	}
	for _, option := range options {
		option(store)
	}
	return store
}

// Append writes events to a stream. expectedVersion is the version the caller
// believes the stream is at; pass -1 to append unconditionally.
func (s *Store) Append(stream string, expectedVersion int, payloads ...named) ([]Event, error) {
	if stream == "" {
		return nil, &ValidationError{Field: "stream", Reason: "must not be empty"}
	}
	if len(payloads) == 0 {
		return nil, &ValidationError{Field: "payloads", Reason: "nothing to append"}
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	if s.closed {
		return nil, ErrClosed
	}

	existing := s.streams[stream]
	current := len(existing)

	if expectedVersion >= 0 && expectedVersion != current {
		return nil, fmt.Errorf("appending to %s: %w", stream, &ConflictError{
			Stream:   stream,
			Expected: expectedVersion,
			Actual:   current,
		})
	}

	written := make([]Event, 0, len(payloads))
	at := s.now()
	for index, payload := range payloads {
		event := Event{
			Stream:  stream,
			Version: current + index + 1,
			Type:    payload.EventType(),
			At:      at.Add(time.Duration(index) * time.Millisecond),
			Payload: payload,
		}
		written = append(written, event)
	}

	s.streams[stream] = append(existing, written...)
	s.all = append(s.all, written...)

	// Publish without blocking: a subscriber that cannot keep up is dropped
	// rather than stalling every writer in the process.
	//
	// The labelled break matters. Closing the channel and carrying on round
	// the inner loop would send on a closed channel, which panics, and it
	// would only happen under load -- the worst way to find a bug.
	for id, channel := range s.subscribers {
	publish:
		for _, event := range written {
			select {
			case channel <- event:
			default:
				close(channel)
				delete(s.subscribers, id)
				break publish
			}
		}
	}

	return written, nil
}

// Read returns a copy of one stream's events, from version onwards.
func (s *Store) Read(stream string, fromVersion int) ([]Event, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	events, found := s.streams[stream]
	if !found {
		return nil, fmt.Errorf("reading %s: %w", stream, ErrStreamNotFound)
	}
	if len(events) == 0 {
		return nil, fmt.Errorf("reading %s: %w", stream, ErrEmptyStream)
	}

	out := make([]Event, 0, len(events))
	for _, event := range events {
		if event.Version >= fromVersion {
			out = append(out, event)
		}
	}
	return out, nil
}

// All returns every event in the store, in the order it was written.
func (s *Store) All() []Event {
	s.mu.RLock()
	defer s.mu.RUnlock()

	out := make([]Event, len(s.all))
	copy(out, s.all)
	return out
}

// Version reports how many events a stream holds.
func (s *Store) Version(stream string) int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.streams[stream])
}

// Streams lists every stream name, sorted.
func (s *Store) Streams() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	names := make([]string, 0, len(s.streams))
	for name := range s.streams {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// Subscribe returns a channel of future events and a function to stop.
// The channel is closed when the subscription ends or the subscriber falls
// too far behind.
func (s *Store) Subscribe(ctx context.Context) (<-chan Event, func()) {
	s.mu.Lock()
	id := s.nextSub
	s.nextSub++
	channel := make(chan Event, s.buffer)
	s.subscribers[id] = channel
	s.mu.Unlock()

	stop := func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		if existing, found := s.subscribers[id]; found {
			close(existing)
			delete(s.subscribers, id)
		}
	}

	// Cancelling the context ends the subscription without the caller having
	// to remember to call stop.
	go func() {
		<-ctx.Done()
		stop()
	}()

	return channel, stop
}

// Close ends every subscription and refuses further appends.
func (s *Store) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.closed {
		return
	}
	s.closed = true
	for id, channel := range s.subscribers {
		close(channel)
		delete(s.subscribers, id)
	}
}

// -------------------------------------------------------------- projections

// Projection folds a stream of events into a value of type T. The constraint
// is `any` because a projection's state can be anything at all.
type Projection[T any] interface {
	Initial() T
	Apply(state T, event Event) T
}

// Fold runs a projection over a slice of events.
func Fold[T any](projection Projection[T], events []Event) T {
	state := projection.Initial()
	for _, event := range events {
		state = projection.Apply(state, event)
	}
	return state
}

// SailingState is what the sailing projection produces.
type SailingState struct {
	Route     string
	Departs   string
	Capacity  int
	Booked    int
	Cancelled bool
	Reason    string
	DelayedBy int
	Bookings  map[string]int
}

func (s SailingState) Available() int { return s.Capacity - s.Booked }

func (s SailingState) String() string {
	if s.Cancelled {
		return fmt.Sprintf("%s %s CANCELLED (%s)", s.Route, s.Departs, s.Reason)
	}
	delay := ""
	if s.DelayedBy > 0 {
		delay = fmt.Sprintf(" +%dmin", s.DelayedBy)
	}
	return fmt.Sprintf("%s %s%s  %d/%d booked, %d free",
		s.Route, s.Departs, delay, s.Booked, s.Capacity, s.Available())
}

// SailingProjection rebuilds one sailing's state from its events.
type SailingProjection struct{}

func (SailingProjection) Initial() SailingState {
	return SailingState{Bookings: map[string]int{}}
}

func (SailingProjection) Apply(state SailingState, event Event) SailingState {
	// A type switch over the payload: each case binds a concrete type.
	switch payload := event.Payload.(type) {
	case SailingScheduled:
		state.Route = payload.Route
		state.Departs = payload.Departs
		state.Capacity = payload.Seats

	case SeatsBooked:
		state.Booked += payload.Seats
		state.Bookings[payload.Reference] = payload.Seats

	case SeatsReleased:
		state.Booked -= payload.Seats
		delete(state.Bookings, payload.Reference)

	case SailingDelayed:
		state.DelayedBy += payload.Minutes

	case SailingCancelled:
		state.Cancelled = true
		state.Reason = payload.Reason
	}
	return state
}

// CountByType is a projection with a much simpler state, to show that the
// generic Fold does not care.
type CountByType struct{}

func (CountByType) Initial() map[string]int { return map[string]int{} }

func (CountByType) Apply(state map[string]int, event Event) map[string]int {
	state[event.Type]++
	return state
}

// OccupancyReport is a projection across every stream at once.
type OccupancyReport struct{}

type occupancy struct {
	Capacity int
	Booked   int
	Sailings int
}

func (OccupancyReport) Initial() map[string]*occupancy {
	return map[string]*occupancy{}
}

func (OccupancyReport) Apply(state map[string]*occupancy, event Event) map[string]*occupancy {
	switch payload := event.Payload.(type) {
	case SailingScheduled:
		entry, found := state[payload.Route]
		if !found {
			entry = &occupancy{}
			state[payload.Route] = entry
		}
		entry.Capacity += payload.Seats
		entry.Sailings++

	case SeatsBooked:
		// The route is not on this event, so it is recovered from the stream
		// name, which is where it was encoded on the way in.
		route := strings.SplitN(event.Stream, "-", 2)[0]
		if entry, found := state[route]; found {
			entry.Booked += payload.Seats
		}
	}
	return state
}

// ------------------------------------------------------------------ helpers

// Filter is a small generic over any slice.
func Filter[T any](items []T, keep func(T) bool) []T {
	out := make([]T, 0, len(items))
	for _, item := range items {
		if keep(item) {
			out = append(out, item)
		}
	}
	return out
}

// Map converts a slice to a slice of something else.
func Map[T, U any](items []T, convert func(T) U) []U {
	out := make([]U, 0, len(items))
	for _, item := range items {
		out = append(out, convert(item))
	}
	return out
}

// Number is a constraint over the types the sum below accepts.
type Number interface {
	~int | ~int64 | ~float64
}

func Sum[T Number](values []T) T {
	var total T
	for _, value := range values {
		total += value
	}
	return total
}

// --------------------------------------------------------------------- main

func fixedClock() func() time.Time {
	moment := time.Date(2027, 9, 2, 6, 0, 0, 0, time.UTC)
	return func() time.Time {
		moment = moment.Add(time.Minute)
		return moment
	}
}

func main() {
	store := NewStore(WithClock(fixedClock()), WithSubscriberBuffer(4))
	defer store.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// A subscriber that records what it sees, running alongside the writes.
	events, stop := store.Subscribe(ctx)
	var seen []string
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for event := range events {
			seen = append(seen, event.String())
		}
	}()

	fmt.Println("--- appending ---")
	appends := []struct {
		stream   string
		expected int
		payloads []named
	}{
		{"HRB-1", 0, []named{SailingScheduled{"HRB", "06:20", 380}}},
		{"HRB-1", 1, []named{SeatsBooked{40, "BK-1001"}, SeatsBooked{12, "BK-1002"}}},
		{"HRB-1", 3, []named{SeatsReleased{12, "BK-1002"}}},
		{"HRB-2", 0, []named{SailingScheduled{"HRB", "06:40", 380}}},
		{"HRB-2", 1, []named{SeatsBooked{310, "BK-1003"}, SailingDelayed{15, "berth"}}},
		{"KSP-1", 0, []named{SailingScheduled{"KSP", "07:00", 240}}},
		{"KSP-1", 1, []named{SeatsBooked{88, "BK-1004"}}},
		{"HLW-1", 0, []named{SailingScheduled{"HLW", "08:05", 120}}},
		{"HLW-1", 1, []named{SailingCancelled{"weather: swell"}}},
	}

	for _, item := range appends {
		written, err := store.Append(item.stream, item.expected, item.payloads...)
		if err != nil {
			fmt.Printf("  %-8s failed: %v\n", item.stream, err)
			continue
		}
		names := Map(written, func(e Event) string { return e.Type })
		fmt.Printf("  %-8s v%d  %s\n", item.stream, written[len(written)-1].Version,
			strings.Join(names, ", "))
	}

	fmt.Println("\n--- optimistic concurrency ---")
	_, err := store.Append("HRB-1", 1, SeatsBooked{5, "BK-9999"})
	fmt.Printf("  error: %v\n", err)
	fmt.Printf("  errors.Is(err, ErrConflict): %v\n", errors.Is(err, ErrConflict))

	var conflict *ConflictError
	if errors.As(err, &conflict) {
		fmt.Printf("  the stream is at %d, the caller thought %d\n",
			conflict.Actual, conflict.Expected)
		written, retryErr := store.Append(conflict.Stream, conflict.Actual,
			SeatsBooked{5, "BK-9999"})
		if retryErr == nil {
			fmt.Printf("  retried at the right version: %s\n", written[0])
		}
	}

	fmt.Println("\n--- other failures ---")
	failures := []struct {
		label string
		call  func() error
	}{
		{"empty stream name", func() error {
			_, e := store.Append("", -1, SeatsBooked{1, "x"})
			return e
		}},
		{"nothing to append", func() error {
			_, e := store.Append("HRB-1", -1)
			return e
		}},
		{"reading an unknown stream", func() error {
			_, e := store.Read("NOPE-1", 1)
			return e
		}},
	}
	for _, failure := range failures {
		e := failure.call()
		fmt.Printf("  %-26s %v", failure.label, e)
		var validation *ValidationError
		switch {
		case errors.As(e, &validation):
			fmt.Printf("   [ValidationError on %q]", validation.Field)
		case errors.Is(e, ErrStreamNotFound):
			fmt.Print("   [ErrStreamNotFound]")
		}
		fmt.Println()
	}

	fmt.Println("\n--- projections ---")
	for _, stream := range store.Streams() {
		history, readErr := store.Read(stream, 1)
		if readErr != nil {
			continue
		}
		state := Fold[SailingState](SailingProjection{}, history)
		fmt.Printf("  %-8s %s\n", stream, state)
	}

	fmt.Println("\n--- events by type ---")
	counts := Fold[map[string]int](CountByType{}, store.All())
	types := make([]string, 0, len(counts))
	for name := range counts {
		types = append(types, name)
	}
	sort.Strings(types)
	for _, name := range types {
		fmt.Printf("  %-20s %d\n", name, counts[name])
	}

	fmt.Println("\n--- occupancy by route ---")
	report := Fold[map[string]*occupancy](OccupancyReport{}, store.All())
	routes := make([]string, 0, len(report))
	for route := range report {
		routes = append(routes, route)
	}
	sort.Strings(routes)
	for _, route := range routes {
		entry := report[route]
		percent := 0.0
		if entry.Capacity > 0 {
			percent = float64(entry.Booked) / float64(entry.Capacity) * 100
		}
		fmt.Printf("  %-4s %d sailing(s), %4d/%4d seats, %5.1f%%\n",
			route, entry.Sailings, entry.Booked, entry.Capacity, percent)
	}

	fmt.Println("\n--- generic helpers ---")
	bookings := Filter(store.All(), func(e Event) bool { return e.Type == "SeatsBooked" })
	seats := Map(bookings, func(e Event) int { return e.Payload.(SeatsBooked).Seats })
	fmt.Printf("  %d booking event(s), %d seat(s) in total\n", len(bookings), Sum(seats))
	fmt.Printf("  mean booking size: %.1f\n", float64(Sum(seats))/float64(len(seats)))

	fmt.Println("\n--- concurrent appends ---")
	concurrent := NewStore(WithClock(fixedClock()))
	var group sync.WaitGroup
	for worker := 0; worker < 8; worker++ {
		group.Add(1)
		go func(id int) {
			defer group.Done()
			for attempt := 0; attempt < 25; attempt++ {
				// Append unconditionally, so contention is on the mutex
				// rather than on the version.
				_, appendErr := concurrent.Append("shared", -1,
					SeatsBooked{1, fmt.Sprintf("W%d-%d", id, attempt)})
				if appendErr != nil {
					return
				}
			}
		}(worker)
	}
	group.Wait()
	fmt.Printf("  8 goroutines x 25 appends -> version %d\n", concurrent.Version("shared"))

	versions := Map(concurrent.All(), func(e Event) int { return e.Version })
	sorted := true
	for i := 1; i < len(versions); i++ {
		if versions[i] != versions[i-1]+1 {
			sorted = false
			break
		}
	}
	fmt.Printf("  versions are contiguous and in order: %v\n", sorted)
	concurrent.Close()

	stop()
	wg.Wait()
	total := len(store.All())
	fmt.Printf("\n--- the subscriber saw %d of %d event(s) ---\n", len(seen), total)
	for _, line := range seen {
		fmt.Printf("  %s\n", line)
	}
	if len(seen) < total {
		fmt.Println("  it fell behind the four-event buffer and was dropped")
	} else {
		fmt.Println("  it kept up, so nothing was dropped")
	}
}
