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

defmodule Mix.Tasks.Ct do
  use Mix.Task

  alias Kernel.ParallelRequire, as: PR

  # TODO: Rename config options, nest under :common_test key, use get_in/2 to
  # find config keys

  @moduledoc """
  Runs common_test suites.

  Suite modules should follow the common_test naming convention of
  ending in `_SUITE`. All other discovered Elixir sources will be
  treated as helper modules.

  ## Configuration

    * `:ct_log_dir` - where to put common_test output within the build
      directory, defaults to `"logs"`

    * `:ct_verbosity` - set the verbosity of common_test logs,
      defaults to `100`

    * `:ct_paths` - paths within which to search for suites and
      helper modules, defaults to `["ct"]`

    * `:ct_pattern` - file pattern of suites and helper modules,
      defaults `"*.exs"`

  ## Command line options

    * `--no-compile`           - disable compilation of your source files
    * `--verbosity=VERBOSITY`  - set the verbosity level of common_test logs

  """
  @shortdoc "Runs common_test suites"
  @recursive true
  @preferred_cli_env :test

  @switches [
    compile: :boolean,
    verbosity: :integer
  ]
  def run(args) do
    args
    |> validate_args_and_env
    |> prepare_mix
    |> load_common_test
    |> load_suites_and_helpers
    |> run_common_test
  end

  defp validate_args_and_env(args) do
    {opts, argv, []} = OptionParser.parse(args, switches: @switches)
    debug(%{args => {opts, argv}})

    unless System.get_env("MIX_ENV") || Mix.env() == :test do
      Mix.raise(
        "\"mix ct\" is running on environment \"#{Mix.env()}\". If you are " <>
          "running common_test suites along another task, please set MIX_ENV explicitly"
      )
    end

    %{opts: opts, args: args, argv: argv, project: Mix.Project.config()}
  end

  defp prepare_mix(%{opts: opts, args: args} = config) do
    # Set up the load paths
    Mix.Task.run("loadpaths", args)

    # Ensure that the project is compiled
    if Keyword.get(opts, :compile, true) do
      Mix.Project.compile(args)
    end

    # Print the project we're in
    Mix.shell().print_app

    config
  end

  defp load_common_test(%{opts: opts, project: project} = config) do
    # Ensure common_test is loaded
    load_app(:common_test)
    load_app(:cth_readable)

    # Ensure that common_test doesn't try to recompile our suites!
    Application.put_env(:common_test, :auto_compile, false)

    # Configure CT settings
    ct_log_dir = project[:ct_log_dir] || "logs"
    verbosity = opts[:verbosity] || project[:ct_verbosity] || 100

    config
    |> Map.put(:log_dir, ct_log_dir)
    |> Map.put(:verbosity, verbosity)
  end

  defp load_suites_and_helpers(%{project: project, argv: argv} = config) do
    # Set up some configuration
    suite_paths = project[:ct_paths] || ["ct"]
    suite_pattern = project[:ct_pattern] || "*.exs"

    # Find suites and helpers to load
    matched_files = Mix.Utils.extract_files(suite_paths, suite_pattern)
    debug(matched_files)

    # Partition into helpers and suites
    {helper_files, suite_files} =
      matched_files
      |> Enum.split_with(&String.ends_with?(&1, "_helper.exs"))

    debug({helper_files, suite_files})

    # Load the helpers
    helpers = PR.files(helper_files)
    debug(helpers)

    # Load the files
    modules = PR.files(suite_files)
    debug(modules)

    # Extract the *_SUITE modules and group them by directory, using
    # the spec format for common_test ({:suites, path, [module ...]})
    ct_suites =
      modules
      |> Enum.filter(&suite_module?/1)
      |> Enum.filter(&(Enum.empty?(argv) or Enum.member?(argv, inspect(&1))))
      |> Enum.group_by(&mod_dir/1)
      |> Enum.map(&{:suites, elem(&1, 0), elem(&1, 1)})

    debug(ct_suites)

    config
    |> Map.put(:suites, ct_suites)
  end

  defp run_common_test(%{suites: []} = config) do
    Mix.shell().info("No suites to run!")
    config
  end

  defp run_common_test(%{suites: suites, log_dir: log_dir, verbosity: verbosity}) do
    log_dir = ensure_log_dir(log_dir)
    log_file = Path.join(log_dir, "ct.latest.log")

    ct_spec =
      [
        ct_hooks: [:cth_readable_failonly, :cth_readable_shell],
        logdir: log_dir,
        verbosity: [default: verbosity]
      ] ++ suites

    debug(%{logdir: log_dir, logfile: log_file, spec: ct_spec})

    runner =
      Task.async(fn ->
        File.open(log_file, [:write], fn log ->
          # This ensures common_test doesn't spew all over the console
          :erlang.group_leader(log, self())
          :ct.run_testspec(ct_spec)
        end)
      end)

    {:ok, results} = Task.await(runner, :infinity)
    debug(%{results: results})
    Mix.shell().info("Console output written to: #{log_file}")

    report_results(results)
  end

  defp report_results({:error, reason}) do
    Mix.raise("common_test terminated with error #{inspect(reason)}")
  end

  defp report_results({passed, 0, {0, 0}}) do
    Mix.shell().info("All #{passed} tests passed.")
  end

  defp report_results({passed, failed, skipped}) do
    if passed > 0 do
      Mix.shell().info("Passed #{passed} tests.")
    end

    if failed > 0 do
      Mix.shell().error("Failed #{failed} tests!")
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end

    if skipped != {0, 0} do
      {user, auto} = skipped
      Mix.shell().info("Skipped #{user + auto} tests. (#{user} by user, #{auto} automatically)")
    end
  end

  ### Helper functions
  defp suite_module?(mod) do
    mod
    |> Atom.to_string()
    |> String.ends_with?("_SUITE")
  end

  defp mod_dir(mod) do
    :compile
    |> mod.__info__
    |> Keyword.get(:source)
    |> Path.dirname()
    |> String.to_charlist()
  end

  defp ensure_log_dir(dir) do
    absolute_dir =
      case Path.type(dir) do
        :absolute -> dir
        :relative -> Path.join(Mix.Project.build_path(), dir)
      end

    File.mkdir_p!(absolute_dir)
    String.to_charlist(absolute_dir)
  end

  defp debug(msg) when is_binary(msg) do
    if Mix.debug?(), do: Mix.shell().info(msg)
  end

  defp debug(term) do
    debug(inspect(term, pretty: true))
  end

  defp load_app(app) do
    case Application.load(app) do
      :ok ->
        :ok

      {:error, {:already_loaded, ^app}} ->
        :ok

      err ->
        Mix.raise("#{inspect(app)} is not on the code path! Loading failed with #{inspect(err)}")
    end
  end
end
