// Channels carry values between goroutines; select waits on whichever one
// is ready first.

package main

import (
	"fmt"
	"time"
)

func produce(name string, count int, gap time.Duration) <-chan string {
	out := make(chan string)

	go func() {
		defer close(out) // closing tells the receiver there is no more
		for i := 1; i <= count; i++ {
			time.Sleep(gap)
			out <- fmt.Sprintf("%s %d", name, i)
		}
	}()
	return out
}

func main() {
	// An unbuffered channel blocks until both sides are ready.
	done := make(chan struct{})
	go func() {
		fmt.Println("working")
		close(done)
	}()
	<-done

	// A buffered channel accepts values up to its capacity without a receiver.
	buffered := make(chan int, 3)
	buffered <- 1
	buffered <- 2
	fmt.Printf("buffered holds %d of %d\n", len(buffered), cap(buffered))

	// Ranging over a channel stops when it is closed.
	for value := range produce("tick", 3, 10*time.Millisecond) {
		fmt.Println(value)
	}

	// select takes whichever case is ready, with a timeout as the fallback.
	fast := produce("fast", 3, 15*time.Millisecond)
	slow := produce("slow", 3, 40*time.Millisecond)

	for fast != nil || slow != nil {
		select {
		case value, ok := <-fast:
			if !ok {
				fast = nil // a nil channel is never ready again
				continue
			}
			fmt.Println("from fast:", value)
		case value, ok := <-slow:
			if !ok {
				slow = nil
				continue
			}
			fmt.Println("from slow:", value)
		case <-time.After(200 * time.Millisecond):
			fmt.Println("timed out")
			return
		}
	}
}
