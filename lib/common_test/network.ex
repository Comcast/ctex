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
