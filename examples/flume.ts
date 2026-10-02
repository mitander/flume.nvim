namespace Expressions {
    export type Ast =
        | { kind: "num"; value: number }
        | { kind: "add"; lhs: Ast; rhs: Ast };

    /** Fold a tiny expression tree. */
    export function fold(expr: Ast): number {
        switch (expr.kind) {
            case "num":
                return expr.value;
            case "add":
                return fold(expr.lhs) + fold(expr.rhs);
        }
    }
}

const expr: Expressions.Ast = {
    kind: "add",
    lhs: { kind: "num", value: 40 },
    rhs: { kind: "num", value: 2 },
};
console.log(`folded = ${Expressions.fold(expr)}`);
