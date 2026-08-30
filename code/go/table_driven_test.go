// The Go convention for tests: one table of cases, one loop, one subtest
// per row. Run it with `go test table_driven_test.go`.

package main

import (
	"strings"
	"testing"
)

// The function under test, kept in the same file so the sample stands alone.
func FizzBuzz(n int) string {
	switch {
	case n%15 == 0:
		return "FizzBuzz"
	case n%3 == 0:
		return "Fizz"
	case n%5 == 0:
		return "Buzz"
	default:
		return strings.TrimSpace(itoa(n))
	}
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	negative := n < 0
	if negative {
		n = -n
	}
	var digits []byte
	for n > 0 {
		digits = append([]byte{byte('0' + n%10)}, digits...)
		n /= 10
	}
	if negative {
		return "-" + string(digits)
	}
	return string(digits)
}

func TestFizzBuzz(t *testing.T) {
	cases := []struct {
		name string
		in   int
		want string
	}{
		{"plain number", 1, "1"},
		{"divisible by three", 9, "Fizz"},
		{"divisible by five", 20, "Buzz"},
		{"divisible by fifteen", 45, "FizzBuzz"},
		{"two digits", 22, "22"},
		{"zero is divisible by everything", 0, "FizzBuzz"},
	}

	for _, testCase := range cases {
		t.Run(testCase.name, func(t *testing.T) {
			got := FizzBuzz(testCase.in)
			if got != testCase.want {
				t.Errorf("FizzBuzz(%d) = %q, want %q", testCase.in, got, testCase.want)
			}
		})
	}
}

func TestItoaRoundTrip(t *testing.T) {
	for _, n := range []int{0, 7, 42, 1234, -99} {
		if got := itoa(n); got == "" {
			t.Fatalf("itoa(%d) returned an empty string", n)
		}
	}
}

func BenchmarkFizzBuzz(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FizzBuzz(i % 100)
	}
}
