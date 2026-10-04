package main

import (
	"context"
	"fmt"
)

// Count stops even when nobody is receiving from its output.
func Count(ctx context.Context, start int) (<-chan int, <-chan struct{}) {
	values := make(chan int)
	done := make(chan struct{})
	go func() {
		defer close(done)
		defer close(values)
		for n := start; ; n++ {
			select {
			case <-ctx.Done():
				return
			case values <- n:
			}
		}
	}()
	return values, done
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	values, done := Count(ctx, 40)

	for range 3 {
		fmt.Printf("received: %d\n", <-values)
	}
	cancel()
	<-done // Wait for cleanup, not an arbitrary sleep.
	_, open := <-values
	fmt.Printf("channel open: %t\n", open)
	// received: 40, 41, 42; channel open: false
}
