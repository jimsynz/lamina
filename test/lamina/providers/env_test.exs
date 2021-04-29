defmodule Lamina.Provider.EnvTest do
  use ExUnit.Case, async: true
  alias Lamina.Provider.Env
  doctest Lamina.Provider.Env
  @moduledoc false

  @env_fixtures %{
    "PHOENIX_HTTP_PORT" => "4000",
    "BIND_ADDR" => "0.0.0.0"
  }

  setup do
    for {name, value} <- @env_fixtures do
      System.put_env(name, value)
    end

    on_exit(fn ->
      for {name, _} <- @env_fixtures do
        System.delete_env(name)
      end
    end)
  end
end
