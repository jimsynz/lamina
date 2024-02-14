defmodule Lamina.MixProject do
  use Mix.Project
  @moduledoc false

  @version "0.4.0"
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
      licenses: ["HL3-FULL"],
      links: %{
        "Source" => "https://harton.dev/james/lamina"
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
      {:credo, "~> 1.6", only: ~w[dev test]a, runtime: false},
      {:dialyxir, "~> 1.4", only: ~w[dev test]a, runtime: false},
      {:doctor, "~> 0.21", only: ~w[dev test]a, runtime: false},
      {:earmark, "~> 1.4", only: ~w[dev test]a, runtime: false},
      {:ex_doc, "~> 0.30", only: ~w[dev test]a, runtime: false},
      {:ex_machina, "~> 2.7", only: ~w[dev test]a},
      {:faker, "~> 0.17.0", only: ~w[dev test]a},
      {:git_ops, "~> 2.4", only: ~w[dev test]a, runtime: false},
      {:mimic, "~> 1.5", only: ~w[dev test]a},
      {:recase, "~> 0.7"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
