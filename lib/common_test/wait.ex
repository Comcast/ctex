# Copyright 2018 Comcast Cable Communications Management, LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
