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

defmodule CommonTest.Network do
  @moduledoc "Helpers for working with the network inside a test suite."

  @doc "Acquires a random TCP port number that the local node or a child node could listen on."
  @spec random_port() :: {:ok, pos_integer()} | {:error, term()}
  def random_port do
    with {:ok, socket} <- :gen_tcp.listen(0, reuseaddr: true),
         {:ok, {_address, port}} <- :inet.sockname(socket),
         :ok <- :gen_tcp.close(socket),
         do: {:ok, port}
  end
end
