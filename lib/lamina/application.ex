defmodule Lamina.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @doc false
  @impl true
  def start(_type, _args) do
    [
      Lamina.Registry.ServerRegistry,
      Lamina.Registry.PubSubRegistry
    ]
    |> Supervisor.start_link(strategy: :one_for_one, name: Lamina.Supervisor)
  end
end
