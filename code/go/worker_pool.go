// A fixed number of workers pulling jobs off one channel and writing
// results to another.

package main

import (
	"fmt"
	"sort"
	"sync"
	"time"
)

type job struct {
	ID    int
	Limit int
}

type result struct {
	JobID  int
	Primes int
	Took   time.Duration
}

func countPrimes(limit int) int {
	composite := make([]bool, limit+1)
	found := 0

	for candidate := 2; candidate <= limit; candidate++ {
		if composite[candidate] {
			continue
		}
		found++
		for multiple := candidate * candidate; multiple <= limit; multiple += candidate {
			composite[multiple] = true
		}
	}
	return found
}

func worker(id int, jobs <-chan job, results chan<- result, wait *sync.WaitGroup) {
	defer wait.Done()

	for next := range jobs {
		started := time.Now()
		results <- result{JobID: next.ID, Primes: countPrimes(next.Limit), Took: time.Since(started)}
	}
}

func main() {
	const workers = 4

	jobs := make(chan job)
	results := make(chan result)

	var wait sync.WaitGroup
	for id := 1; id <= workers; id++ {
		wait.Add(1)
		go worker(id, jobs, results, &wait)
	}

	// Closing `results` once every worker has finished lets the range below end.
	go func() {
		wait.Wait()
		close(results)
	}()

	go func() {
		for id, limit := range []int{50000, 120000, 30000, 200000, 90000, 10000} {
			jobs <- job{ID: id + 1, Limit: limit}
		}
		close(jobs)
	}()

	var collected []result
	for r := range results {
		collected = append(collected, r)
	}

	sort.Slice(collected, func(i, j int) bool { return collected[i].JobID < collected[j].JobID })
	for _, r := range collected {
		fmt.Printf("job %d: %6d primes in %v\n", r.JobID, r.Primes, r.Took.Round(time.Microsecond))
	}
}
