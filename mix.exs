defmodule Lamina.MixProject do
  use Mix.Project
  @moduledoc false

  @version "0.2.0"
  @description "Dynamic, runtime configuration for your Elixir app"

  def project do
    [
      app: :lamina,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: @description,
      deps: deps(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def package do
    [
      maintainers: ["James Harton <james@harton.nz>"],
      licenses: ["Hippocratic"],
      links: %{
        "Source" => "https://gitlab.com/jimsy/lamina"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Lamina.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.5"},
      {:ex_doc, ">= 0.0.0", only: ~w[dev test]a},
      {:ex_machina, "~> 2.7", only: ~w[dev test]a},
      {:faker, "~> 0.16.0", only: ~w[dev test]a},
      {:git_ops, "~> 2.3", only: ~w[dev test]a, runtime: false},
      {:mimic, "~> 1.5", only: ~w[dev test]a},
      {:plug_cowboy, "~> 2.5", only: ~w[dev test]a},
      {:recase, "~> 0.7"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
