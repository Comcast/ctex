defmodule CommonTest do
  @moduledoc "Elixir integration for common_test suites."

  @type config() :: Keyword.t()

  defmacro __using__(_opts) do
    quote do
      import CommonTest.Suite
      import CommonTest.Wait
      import CommonTest.Cluster
      import CommonTest.Network
    end
  end
end
