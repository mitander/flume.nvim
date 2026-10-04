defmodule Log do
  @moduledoc "A small log parser that keeps malformed lines explicit."
  @line ~r/^(?<level>info|warn|error) (?<message>.+)$/

  def parse(""), do: {:error, :empty_line}

  def parse(line) when is_binary(line) do
    case Regex.named_captures(@line, line) do
      %{"level" => level, "message" => message} ->
        {:ok, %{level: level, message: message}}

      nil ->
        {:error, :invalid_format}
    end
  end
end

lines = [
  "info Listener ready on port 8080",
  "warn Cache is nearly full",
  "info Connection accepted",
  "this is not a log entry",
  ""
]

# Count valid entries; errors remain available to other callers.
lines
|> Enum.map(&Log.parse/1)
|> Enum.flat_map(fn
  {:ok, %{level: level}} -> [level]
  {:error, _reason} -> []
end)
|> Enum.frequencies()
|> Enum.sort()
|> Enum.each(fn {level, count} -> IO.puts("#{level}: #{count}") end)

# info: 2
# warn: 1
