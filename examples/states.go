package main

import "fmt"

// Readable comments on active surfaces.
func greeting(name string) string {
    return fmt.Sprintf("Hello, %s", name)
}

func main() {
    name := "Flume"
    fmt.Println(greeting(name))
}
