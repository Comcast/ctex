defmodule CommonTest.Wait do
  @moduledoc """
  Macros for handling non-deterministic conditions in tests without waiting
  indefinitely.
  """

  @doc """
  Repeatedly attempts the given block until the given time (in
  milliseconds) runs out or the `do` block returns `true`. In between
  each attempt, the current process will sleep for 10 milliseconds. If
  all attempts fail, the `else` block will be executed.

  ## Example:

      wait_until 10_000 do
        receive do
          :hello -> true
        after 0 ->
           false
        end
      else
        :ct.fail(:was_not_greeted)
      end
  """
  defmacro wait_until(time, do: block, else: otherwise) do
    quote do
      result =
        fn -> unquote(block) end
        |> Stream.repeatedly()
        |> Enum.reduce_while(
          unquote(time),
          fn
            true, _count ->
              {:halt, true}

            false, count when count <= 0 ->
              {:halt, false}

            false, count ->
              :timer.sleep(10)
              {:cont, count - 10}
          end
        )

      if result do
        result
      else
        unquote(otherwise)
      end
    end
  end
end
