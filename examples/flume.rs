use std::fmt;

/// A tiny expression tree with constant folding.
enum Ast {
    Num(i64),
    Add(Box<Ast>, Box<Ast>),
}

impl Ast {
    fn fold(&self) -> Option<i64> {
        match self {
            Self::Num(value) => Some(*value),
            Self::Add(lhs, rhs) => Some(lhs.fold()? + rhs.fold()?),
        }
    }
}

impl fmt::Display for Ast {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{:?}", self.fold())
    }
}

fn main() {
    let expr = Ast::Add(Box::new(Ast::Num(40)), Box::new(Ast::Num(2)));
    println!("{expr} folded = {:?}", expr.fold());
}
