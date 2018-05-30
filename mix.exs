defmodule Ctex.MixProject do
  use Mix.Project

  def project do
    [
      app: :ctex,
      description: description(),
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:mix, :common_test]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cth_readable, "~> 1.4.0"},
      {:ex_doc, "~> 0.18.3", only: :dev}
    ]
  end

  defp description do
    "A Mix task and helpers for running common_test suites"
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      maintainers: ["Sean Cribbs", "Zeeshan Lakhani"],
      files: ["lib", "README*", "mix.exs", "CONTRIBUTING", "NOTICE", "LICENSE"],
      links: %{
        # TODO: Update this link
        "Github" => "https://github.com/Comcast/ctex"
      }
    ]
  end

  def docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
