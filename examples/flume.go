package main

import "fmt"

// Ast is a tiny expression tree with constant folding.
type Ast struct {
	Value *int
	Left  *Ast
	Right *Ast
}

func (expr Ast) Fold() (int, bool) {
	if expr.Value != nil {
		return *expr.Value, true
	}
	if expr.Left == nil || expr.Right == nil {
		return 0, false
	}
	left, leftOK := expr.Left.Fold()
	right, rightOK := expr.Right.Fold()
	return left + right, leftOK && rightOK
}

func main() {
	left, right := 40, 2
	expr := Ast{Left: &Ast{Value: &left}, Right: &Ast{Value: &right}}
	value, ok := expr.Fold()
	fmt.Printf("folded = %d (constant: %t)\n", value, ok)
}
