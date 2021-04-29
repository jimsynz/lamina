defmodule Lamina.Server.StateTest do
  use ExUnit.Case, async: true
  alias Lamina.Server.State
  @moduledoc false

  describe "init/1" do
    setup do
      opts = [
        providers: [{Lamina.Provider.Env, [arg: 1]}],
        config_keys: [:key_1, :key_2],
        module: __MODULE__,
        table: make_ref()
      ]

      {:ok, opts: opts}
    end

    for field <- ~w[providers config_keys module table]a do
      test "when there is no `#{inspect(field)}` opt, it returns an error", %{opts: opts} do
        opts =
          opts
          |> Keyword.drop([unquote(field)])

        assert {:error, %ArgumentError{}} = State.init(opts)
      end
    end

    test "it returns a new state", %{opts: opts} do
      assert {:ok, state} = State.init(opts)

      for field <- ~w[config_keys module table]a do
        assert Map.fetch(state, field) == Keyword.fetch(opts, field)
      end

      assert Map.fetch(state, :provider_opts) == Keyword.fetch(opts, :providers)
      assert Map.get(state, :provider_order) == opts |> Keyword.get(:providers) |> Keyword.keys()

      assert state |> Map.get(:provider_states) |> Map.keys() ==
               opts |> Keyword.get(:providers) |> Keyword.keys()

      assert state |> Map.get(:provider_states) |> Map.values() |> Enum.all?(&is_nil/1)
    end
  end
end
