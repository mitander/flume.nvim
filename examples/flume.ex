defmodule Ast do
  @moduledoc "A tiny expression tree with constant folding."
  defstruct [:value, :lhs, :rhs]

  def fold(%__MODULE__{value: value}) when is_integer(value), do: value

  def fold(%__MODULE__{lhs: lhs, rhs: rhs}) do
    fold(lhs) + fold(rhs)
  end

  def sample do
    %__MODULE__{lhs: %__MODULE__{value: 40}, rhs: %__MODULE__{value: 2}}
  end
end

expr = Ast.sample()
result = expr |> Ast.fold() |> Integer.to_string()
IO.puts("folded = #{result}")
