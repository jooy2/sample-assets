// defer schedules cleanup, panic unwinds the stack, and recover catches a
// panic at a boundary you choose.

package main

import (
	"errors"
	"fmt"
	"os"
)

func openAndClose(path string) error {
	file, err := os.CreateTemp("", path)
	if err != nil {
		return err
	}
	// Runs when the function returns, whichever way it returns.
	defer func() {
		name := file.Name()
		file.Close()
		os.Remove(name)
		fmt.Println("cleaned up", name)
	}()

	if _, err := file.WriteString("station,line,zone\n"); err != nil {
		return err
	}
	fmt.Println("wrote to", file.Name())
	return nil
}

// Deferred calls run last in, first out.
func ordering() {
	for i := 1; i <= 3; i++ {
		defer fmt.Println("deferred", i)
	}
	fmt.Println("body finished")
}

// A named return value lets a deferred function change what is returned.
func safeDivide(a, b int) (result int, err error) {
	defer func() {
		if recovered := recover(); recovered != nil {
			err = fmt.Errorf("recovered: %v", recovered)
		}
	}()
	return a / b, nil // panics when b is zero
}

func mustPositive(value int) {
	if value <= 0 {
		panic(errors.New("value must be positive"))
	}
}

func main() {
	if err := openAndClose("sample-assets-*.csv"); err != nil {
		fmt.Println("error:", err)
	}

	ordering()

	fmt.Println(safeDivide(12, 4))
	fmt.Println(safeDivide(12, 0))

	func() {
		defer func() {
			if recovered := recover(); recovered != nil {
				fmt.Println("caught a panic:", recovered)
			}
		}()
		mustPositive(-1)
		fmt.Println("never reached")
	}()

	fmt.Println("still running")
}
