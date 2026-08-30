// An interface is satisfied by any type with the right methods; nothing
// has to declare that it implements one.

package main

import (
	"fmt"
	"math"
	"sort"
)

type Shape interface {
	Area() float64
	Perimeter() float64
}

// Named returns a label, and is embedded into Shape users below.
type Named interface {
	Name() string
}

type Circle struct{ Radius float64 }

func (c Circle) Area() float64      { return math.Pi * c.Radius * c.Radius }
func (c Circle) Perimeter() float64 { return 2 * math.Pi * c.Radius }
func (c Circle) Name() string       { return "circle" }

type Rectangle struct{ Width, Height float64 }

func (r Rectangle) Area() float64      { return r.Width * r.Height }
func (r Rectangle) Perimeter() float64 { return 2 * (r.Width + r.Height) }
func (r Rectangle) Name() string       { return "rectangle" }

// Stringer is satisfied implicitly, so fmt picks it up.
func (r Rectangle) String() string { return fmt.Sprintf("%gx%g", r.Width, r.Height) }

func describe(shape Shape) string {
	// A type switch recovers the concrete type when it matters.
	switch value := shape.(type) {
	case Rectangle:
		if value.Width == value.Height {
			return "a square"
		}
		return "a rectangle"
	case Circle:
		if value.Radius > 10 {
			return "a large circle"
		}
		return "a circle"
	default:
		return "some other shape"
	}
}

func main() {
	shapes := []Shape{Circle{2}, Rectangle{4, 4}, Rectangle{3, 6}, Circle{12}}

	sort.Slice(shapes, func(i, j int) bool { return shapes[i].Area() < shapes[j].Area() })

	total := 0.0
	for _, shape := range shapes {
		total += shape.Area()
		label := "unnamed"
		if named, ok := shape.(Named); ok { // a type assertion, checked
			label = named.Name()
		}
		fmt.Printf("%-10s %-14s area %7.2f perimeter %6.2f\n",
			label, describe(shape), shape.Area(), shape.Perimeter())
	}
	fmt.Printf("total area %.2f\n", total)
	fmt.Println("Stringer in action:", Rectangle{3, 6})
}
