// Slices share their backing array; maps are unordered. Both surprise
// people, so this shows exactly how.

package main

import (
	"fmt"
	"sort"
)

func main() {
	numbers := []int{1, 2, 3, 4, 5, 6, 7, 8}
	fmt.Printf("len %d cap %d %v\n", len(numbers), cap(numbers), numbers)

	// A slice of a slice looks at the same memory.
	window := numbers[2:5]
	window[0] = 99
	fmt.Println("after writing through the window:", numbers)

	// Appending past the capacity copies; below it, it overwrites.
	small := make([]int, 3, 8)
	alias := append(small, 1)
	alias[0] = 42
	fmt.Println("shared backing array:", small[0] == 42)

	// copy() is the explicit way to get an independent slice.
	independent := make([]int, len(numbers))
	copy(independent, numbers)
	independent[0] = -1
	fmt.Println("original untouched:", numbers[0])

	// Deleting element 3 while keeping the order.
	index := 3
	trimmed := append(numbers[:index:index], numbers[index+1:]...)
	fmt.Println("without index 3:", trimmed)

	// Maps: the zero value comes back for a missing key, so use the
	// two-value form to tell "absent" from "present but zero".
	zones := map[string]int{"Alder Cross": 2, "Quill Wharf": 3, "Saltwick Halt": 5}
	fmt.Println("missing key reads as", zones["Nether Gate"])

	if zone, ok := zones["Nether Gate"]; !ok {
		fmt.Println("Nether Gate is not on the network")
	} else {
		fmt.Println("zone", zone)
	}

	delete(zones, "Quill Wharf")
	fmt.Println("after delete:", len(zones))

	// Iteration order is deliberately random, so sort the keys to be stable.
	keys := make([]string, 0, len(zones))
	for key := range zones {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		fmt.Printf("  %-14s zone %d\n", key, zones[key])
	}

	// A map of slices needs no initialisation per key: append handles nil.
	byZone := map[int][]string{}
	for station, zone := range zones {
		byZone[zone] = append(byZone[zone], station)
	}
	fmt.Println(byZone)
}
