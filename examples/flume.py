from dataclasses import dataclass
from pathlib import Path


@dataclass
class Ast:
    """A tiny expression tree with constant folding."""

    value: int | None = None
    lhs: "Ast | None" = None
    rhs: "Ast | None" = None

    def fold(self) -> int | None:
        if self.value is not None:
            return self.value
        if self.lhs is None or self.rhs is None:
            return None
        left, right = self.lhs.fold(), self.rhs.fold()
        return None if left is None or right is None else left + right


expr = Ast(lhs=Ast(40), rhs=Ast(2))
print(f"{Path(__file__).stem} folded = {expr.fold()}")
