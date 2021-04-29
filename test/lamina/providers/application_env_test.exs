defmodule Lamina.Provider.ApplicationEnvTest do
  use ExUnit.Case, async: true
  alias Lamina.Provider.ApplicationEnv
  doctest Lamina.Provider.ApplicationEnv
  @moduledoc false

  @app_fixtures [
    flat_app: [jigga_watts: 1.21],
    nested_app: [time_machine: [model: :delorean]]
  ]

  setup do
    Application.put_all_env(@app_fixtures)

    on_exit(fn ->
      for {otp_app, opts} <- @app_fixtures do
        for {key, _} <- opts do
          Application.delete_env(otp_app, key)
        end
      end
    end)
  end
end
