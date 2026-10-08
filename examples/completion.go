package main

import (
    "fmt"
    "strings"
)

type Palette struct {
    Name       string
    Background string
}

var palettes = []Palette{
    {Name: "dusk", Background: "#232136"},
    {Name: "opal", Background: "#f2eff7"},
    {Name: "mira", Background: "#24212f"},
    {Name: "mesa", Background: "#f3ede8"},
}

// FindPalette accepts names copied from a config file or terminal prompt.
func FindPalette(input string) (Palette, bool) {
    name := strings.TrimSpace(input)
    for _, palette := range palettes {
        if palette.Name == strings.ToLower(name) {
            return palette, true
        }
    }
    return Palette{}, false
}

func main() {
    palette, found := FindPalette(" dusk ")
    fmt.Println(palette.Name, found)
}
