defmodule Lamina.MixProject do
  use Mix.Project
  @moduledoc false

  @version "0.1.0"
  @description "Application configuration done right"

  def project do
    [
      app: :lamina,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: @description,
      deps: deps(),
      package: package()
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
      {:git_ops, "~> 2.3", only: ~w[dev test]a, runtime: false}
    ]
  end
end
