// Errors are values: wrap them to add context, and unwrap them to test
// what actually went wrong.

package main

import (
	"errors"
	"fmt"
	"strconv"
)

var ErrOutOfRange = errors.New("zone is outside 1-6")

// A custom error type carries structured detail alongside the message.
type ValidationError struct {
	Field string
	Value string
	Err   error
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("%s=%q: %v", e.Field, e.Value, e.Err)
}

func (e *ValidationError) Unwrap() error { return e.Err }

func parseZone(raw string) (int, error) {
	zone, err := strconv.Atoi(raw)
	if err != nil {
		return 0, &ValidationError{Field: "zone", Value: raw, Err: err}
	}
	if zone < 1 || zone > 6 {
		return 0, &ValidationError{Field: "zone", Value: raw, Err: ErrOutOfRange}
	}
	return zone, nil
}

func loadStation(raw string) (int, error) {
	zone, err := parseZone(raw)
	if err != nil {
		// %w keeps the chain intact for errors.Is and errors.As.
		return 0, fmt.Errorf("loading station: %w", err)
	}
	return zone, nil
}

func main() {
	for _, raw := range []string{"3", "9", "east"} {
		zone, err := loadStation(raw)
		if err == nil {
			fmt.Printf("%-6s -> zone %d\n", raw, zone)
			continue
		}

		fmt.Printf("%-6s -> %v\n", raw, err)

		// errors.Is compares against a sentinel anywhere in the chain.
		if errors.Is(err, ErrOutOfRange) {
			fmt.Println("         (the number was fine, the range was not)")
		}

		// errors.As pulls out a concrete type from anywhere in the chain.
		var validation *ValidationError
		if errors.As(err, &validation) {
			fmt.Printf("         field %q, raw value %q\n", validation.Field, validation.Value)
		}

		var numeric *strconv.NumError
		if errors.As(err, &numeric) {
			fmt.Printf("         strconv failed on %q\n", numeric.Num)
		}
	}

	joined := errors.Join(ErrOutOfRange, errors.New("and the platform count is missing"))
	fmt.Println("\njoined:", joined)
	fmt.Println("still matches:", errors.Is(joined, ErrOutOfRange))
}
