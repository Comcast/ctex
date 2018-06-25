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

defmodule CommonTest.Cluster do
  @moduledoc """
  Functions for working with Erlang distribution and child nodes in common_test.
  """

  @base_apps [:kernel, :stdlib, :compiler, :elixir, :mix, :hex]

  import CommonTest.Wait, only: :macros
  alias CommonTest.Suite
  alias :ct_slave, as: Child
  alias :rpc, as: RPC

  @doc """
  Ensures the local node is ready to run a test with a cluster of child nodes.
  """
  @spec start() :: :ok
  def start() do
    start_epmd()
    start_runner()
  end

  @doc """
  Starts epmd so that a cluster's nodes can talk to one another.
  """
  @spec start_epmd() :: :ok | no_return()
  def start_epmd do
    with epmd when is_binary(epmd) <- System.find_executable("epmd"),
         _ <- System.cmd(epmd, ~w(-daemon)) do
      :ok
    else
      nil -> Suite.fail!("No epmd on path!")
    end
  end

  @doc """
  Shuts down a node in the cluster by name. If the node does not stop within 10
  seconds, the suite is failed with the reason `{:node_stop_failed, name}`.
  """
  @spec stop_node(node()) :: true | no_return()
  def stop_node(name) do
    wait_until 10_000 do
      case Child.stop(name) do
        {:error, :stop_timeout, _} ->
          false

        {:error, :not_connected, name} ->
          _ = Node.connect(name)
          false

        _ ->
          true
      end
    else
      Suite.fail!({:node_stop_failed, name})
    end
  end

  @doc """
  Starts a child node with the given name and the common_test configuration.
  """
  @spec start_node(node(), CommonTest.config()) :: term()
  def start_node(name, config) do
    ## TODO: provide node-specific configuration?
    node_config = Keyword.get(config, :child_config, child_config())

    with {:start, {:ok, anode}} <- {:start, Child.start(name, node_config)},
         {:connect, true} <- {:connect, Node.connect(anode)} do
      boot_node(anode, config)
    else
      {:start, {:error, reason, name}} ->
        Suite.fail!({:cannot_start_node, name, reason})

      {:connect, false} ->
        Suite.fail!({:cannot_connect_node, name})
    end
  end

  @doc """
  Stops user-initiated applications on a node without shutting it down.
  """
  @spec stop_applications(node()) :: :ok
  def stop_applications(anode) do
    apps = RPC.call(anode, Application, :started_applications, [])

    for {app, _, _} <- apps, not (app in @base_apps) do
      :ok = RPC.call(anode, Application, :stop, [app])
    end

    :ok
  end

  @doc """
  Loads and boots requested applications on a node. This is called automatically
  by `start_node/2`.
  """
  @spec boot_node(node(), CommonTest.config()) :: :ok
  def boot_node(_name, _config) do
    # TODO
    :ok
  end

  #####################
  ### Private functions
  #####################

  defp start_runner do
    case Node.start(runner_name(), :shortnames) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      error ->
        Suite.fail!({:start_distribution, error})
    end
  end

  ## Runner name.
  defp runner_name() do
    {:ok, hostname} = :inet.gethostname()
    String.to_atom("runner@#{hostname}")
  end

  ## Generate node configuration for the slave nodes.
  defp child_config() do
    [
      monitor_master: true,
      startup_functions: [{:code, :set_path, [:code.get_path()]}]
    ]
  end
end
