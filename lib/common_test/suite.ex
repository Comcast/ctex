defmodule CommonTest.Suite do
  @moduledoc """
  Useful functions for common_test suites
  """

  @doc """
  Prints a message to the common_test log and console. Normally, the console
  output is captured as well, and so it will not print to the screen.
  """
  @spec info!(List.Chars.t()) :: :ok
  def info!(msg) do
    msg
    |> to_charlist()
    |> :cthr.pal()
  end

  @doc """
  Formats a list of terms using the given format string and prints the result to
  the common_test log and console. Normally, the console output is captured as
  well, and so it will not print to the screen.
  """
  @spec info!(:io.format() | String.t(), [term()]) :: :ok
  def info!(format, terms) when is_binary(format) do
    format
    |> to_charlist()
    |> info!(terms)
  end

  def info!(format, terms) do
    :cthr.pal(format, terms)
  end

  @doc """
  Prints a message to the common_test log.
  """
  @spec info(List.Chars.t()) :: :ok
  def info(msg) do
    msg
    |> to_charlist()
    |> :ct.log()
  end

  @doc """
  Formats a list of terms using the given format string and prints the result to
  the common_test log.
  """
  @spec info(:io.format() | String.t(), [term()]) :: :ok
  def info(format, terms) when is_binary(format) do
    format
    |> to_charlist()
    |> info(terms)
  end

  def info(format, terms) do
    :ct.log(format, terms)
  end

  @doc """
  Terminates the current test with the given failure reason, which may be any term.
  """
  @spec fail!(term()) :: no_return()
  def fail!(reason) do
    :ct.fail(reason)
  end
end
