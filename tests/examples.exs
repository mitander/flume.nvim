ExUnit.start()
Code.require_file("../examples/flume.ex", __DIR__)

defmodule LogExampleTest do
  use ExUnit.Case, async: true

  test "named captures become a structured event" do
    assert Log.parse("warn Cache is nearly full") ==
             {:ok, %{level: "warn", message: "Cache is nearly full"}}
  end

  test "empty and malformed lines have distinct reasons" do
    assert Log.parse("") == {:error, :empty_line}
    assert Log.parse("debug Unknown level") == {:error, :invalid_format}
    assert Log.parse("info ") == {:error, :invalid_format}
  end
end
