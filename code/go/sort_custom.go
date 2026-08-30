// Sorting by several keys, with sort.Slice and with the sort.Interface
// methods.

package main

import (
	"fmt"
	"sort"
	"strings"
)

type Station struct {
	Name      string
	Line      string
	Zone      int
	Platforms int
}

// ByZoneThenName implements sort.Interface the long way.
type ByZoneThenName []Station

func (s ByZoneThenName) Len() int      { return len(s) }
func (s ByZoneThenName) Swap(i, j int) { s[i], s[j] = s[j], s[i] }
func (s ByZoneThenName) Less(i, j int) bool {
	if s[i].Zone != s[j].Zone {
		return s[i].Zone < s[j].Zone
	}
	return s[i].Name < s[j].Name
}

func main() {
	stations := []Station{
		{"Quill Wharf", "Cobalt", 3, 4},
		{"Alder Cross", "Amber", 2, 2},
		{"Saltwick Halt", "Amber", 5, 1},
		{"Nether Gate", "Emerald", 2, 3},
		{"Bramble Fields", "Cobalt", 3, 2},
	}

	sort.Sort(ByZoneThenName(stations))
	fmt.Println("by zone, then name:")
	for _, station := range stations {
		fmt.Printf("  zone %d  %-15s %s\n", station.Zone, station.Name, station.Line)
	}

	// sort.Slice takes the comparison inline; no type needed.
	sort.Slice(stations, func(i, j int) bool { return stations[i].Platforms > stations[j].Platforms })
	fmt.Println("\nbusiest first:", stations[0].Name, stations[0].Platforms)

	// SliceStable keeps equal elements in their original order.
	sort.SliceStable(stations, func(i, j int) bool { return stations[i].Line < stations[j].Line })
	fmt.Println("\ngrouped by line, ties untouched:")
	for _, station := range stations {
		fmt.Printf("  %-8s %s\n", station.Line, station.Name)
	}

	// Sorting plain slices, and searching a sorted one.
	names := make([]string, len(stations))
	for i, station := range stations {
		names[i] = station.Name
	}
	sort.Strings(names)

	target := "Nether Gate"
	at := sort.SearchStrings(names, target)
	fmt.Printf("\n%q sits at %d (found: %t)\n", target, at, at < len(names) && names[at] == target)
	fmt.Println("sorted:", strings.Join(names, " | "))
	fmt.Println("is sorted:", sort.StringsAreSorted(names))
}
