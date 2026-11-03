package main

import "fmt"

type Queue[T any] struct {
	items []T
	limit int
}

// NewQueue keeps a bounded batch until the caller drains it.
func NewQueue[T any](limit int) *Queue[T] {
	return &Queue[T]{limit: limit}
}

func (q *Queue[T]) Push(item T) error {
	if len(q.items) >= q.limit {
		return fmt.Errorf("queue is full: limit %d", q.limit)
	}
	q.items = append(q.items, item)
	return nil
}

func (q *Queue[T]) Drain() []T {
	items := q.items
	q.items = nil
	return items
}

func main() {
	queue := NewQueue[string](2)
	for _, item := range []string{"read", "write", "close"} {
		if err := queue.Push(item); err != nil {
			fmt.Println(err)
		}
	}
	fmt.Printf("ready: %q\n", queue.Drain())
}
