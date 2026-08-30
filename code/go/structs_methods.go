// Structs, embedding, and the difference between value and pointer
// receivers.

package main

import (
	"fmt"
	"strings"
)

type Address struct {
	City    string
	Country string
	Postal  string
}

func (a Address) String() string {
	return fmt.Sprintf("%s, %s %s", a.City, a.Country, a.Postal)
}

type User struct {
	Address // embedded: its fields and methods are promoted
	ID      int
	First   string
	Last    string
	visits  int // unexported, so only this package can touch it
}

// A value receiver works on a copy.
func (u User) FullName() string {
	return strings.TrimSpace(u.First + " " + u.Last)
}

// A pointer receiver can change the original.
func (u *User) Visit() {
	u.visits++
}

func (u User) Visits() int { return u.visits }

func main() {
	user := User{
		Address: Address{City: "Harrowgate", Country: "Kestrand", Postal: "KE-8256"},
		ID:      1,
		First:   "Imogen",
		Last:    "Hawthorne",
	}

	fmt.Println(user.FullName())
	fmt.Println(user.City, "->", user.Address) // promoted field, embedded String()

	user.Visit()
	user.Visit()
	fmt.Println("visits:", user.Visits())

	// Assignment copies the struct, so the copy has its own counter.
	copied := user
	copied.Visit()
	fmt.Printf("original %d, copy %d\n", user.Visits(), copied.Visits())

	// A pointer shares it.
	shared := &user
	shared.Visit()
	fmt.Printf("original %d, through the pointer %d\n", user.Visits(), shared.Visits())

	// Anonymous structs are handy for one-off shapes.
	summary := struct {
		Name string
		Zone int
	}{Name: user.FullName(), Zone: 2}
	fmt.Printf("%+v\n", summary)
}
