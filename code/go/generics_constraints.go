// Type parameters with constraints: one implementation, many element types.

package main

import (
	"fmt"
	"strings"
)

type Number interface {
	~int | ~int64 | ~float64
}

type Ordered interface {
	~int | ~int64 | ~float64 | ~string
}

func Sum[T Number](values []T) T {
	var total T
	for _, value := range values {
		total += value
	}
	return total
}

func Max[T Ordered](values []T) (T, bool) {
	var best T
	if len(values) == 0 {
		return best, false
	}
	best = values[0]
	for _, value := range values[1:] {
		if value > best {
			best = value
		}
	}
	return best, true
}

func Map[In, Out any](values []In, transform func(In) Out) []Out {
	out := make([]Out, 0, len(values))
	for _, value := range values {
		out = append(out, transform(value))
	}
	return out
}

func Filter[T any](values []T, keep func(T) bool) []T {
	var out []T
	for _, value := range values {
		if keep(value) {
			out = append(out, value)
		}
	}
	return out
}

func GroupBy[T any, K comparable](values []T, key func(T) K) map[K][]T {
	groups := make(map[K][]T)
	for _, value := range values {
		groups[key(value)] = append(groups[key(value)], value)
	}
	return groups
}

// A named type whose underlying type is int still satisfies ~int.
type Zone int

func main() {
	fmt.Println(Sum([]int{1, 2, 3, 4}), Sum([]float64{1.5, 2.25}))
	fmt.Println(Sum([]Zone{1, 2, 3}))

	if largest, ok := Max([]string{"amber", "cobalt", "emerald"}); ok {
		fmt.Println("largest string:", largest)
	}

	stations := []string{"Alder Cross", "Quill Wharf", "Saltwick Halt", "Nether Gate"}
	fmt.Println(Map(stations, strings.ToUpper))
	fmt.Println(Map(stations, func(s string) int { return len(s) }))
	fmt.Println(Filter(stations, func(s string) bool { return strings.Contains(s, "a") }))

	grouped := GroupBy(stations, func(s string) string { return s[:1] })
	fmt.Println(grouped)
}
