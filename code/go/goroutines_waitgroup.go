// Goroutines run concurrently; a WaitGroup waits for all of them, and a
// Mutex keeps their writes from colliding.

package main

import (
	"fmt"
	"sync"
	"time"
)

func main() {
	var wait sync.WaitGroup

	for worker := 1; worker <= 4; worker++ {
		wait.Add(1)
		go func(id int) {
			defer wait.Done()
			time.Sleep(time.Duration(id) * 20 * time.Millisecond)
			fmt.Printf("worker %d finished\n", id)
		}(worker)
	}

	wait.Wait()
	fmt.Println("all workers done")

	// Several goroutines writing to one map need a lock.
	var mutex sync.Mutex
	counts := make(map[string]int)
	words := []string{"amber", "cobalt", "amber", "emerald", "cobalt", "amber"}

	for _, word := range words {
		wait.Add(1)
		go func(word string) {
			defer wait.Done()
			mutex.Lock()
			defer mutex.Unlock()
			counts[word]++
		}(word)
	}
	wait.Wait()

	fmt.Println(counts)

	// sync.Once runs its function exactly once, whoever gets there first.
	var once sync.Once
	for i := 0; i < 3; i++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			once.Do(func() { fmt.Println("initialised once") })
		}()
	}
	wait.Wait()
}
