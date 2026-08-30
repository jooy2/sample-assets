// Building strings without allocating one per concatenation, and the
// strings package around it.

package main

import (
	"fmt"
	"strconv"
	"strings"
	"unicode"
)

func slugify(text string) string {
	var builder strings.Builder
	builder.Grow(len(text)) // one allocation instead of many

	previousDash := false
	for _, r := range strings.ToLower(text) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			builder.WriteRune(r)
			previousDash = false
		case !previousDash && builder.Len() > 0:
			builder.WriteByte('-')
			previousDash = true
		}
	}
	return strings.TrimSuffix(builder.String(), "-")
}

func main() {
	fmt.Println(slugify("  Alder Cross / Quill Wharf  "))
	fmt.Println(slugify("Sensor Readings 2025"))

	var report strings.Builder
	for zone := 1; zone <= 5; zone++ {
		report.WriteString("zone ")
		report.WriteString(strconv.Itoa(zone))
		if zone < 5 {
			report.WriteString(" -> ")
		}
	}
	fmt.Println(report.String())

	line := "Alder Cross,Amber,2,true"
	fields := strings.Split(line, ",")
	fmt.Printf("%d fields, last %q\n", len(fields), fields[len(fields)-1])

	fmt.Println(strings.Join(fields[:3], " | "))
	fmt.Println(strings.Repeat("-", 24))
	fmt.Println("contains 'Amber':", strings.Contains(line, "Amber"))
	fmt.Println("index of comma:", strings.Index(line, ","))
	fmt.Println("replaced:", strings.ReplaceAll(line, ",", "; "))
	fmt.Println("fields():", strings.Fields("  spaced   out   text "))
	fmt.Println("cut:", func() string {
		before, after, found := strings.Cut(line, ",")
		return fmt.Sprintf("%q + %q (found %t)", before, after, found)
	}())
	fmt.Println("title-ish:", strings.ToUpper(line[:1])+line[1:])
	fmt.Println("padded:", fmt.Sprintf("|%-20s|%20s|", "left", "right"))
}
