defmodule Lamina.Server.ProviderTest do
  use ExUnit.Case
  use Mimic
  alias Lamina.Error.NotAProviderModuleError
  alias Lamina.Provider.Default
  alias Lamina.Server.Provider
  import Factory
  @moduledoc false

  describe "assert_provider_module/1" do
    test "when the module implements the Lamina.Provider behaviour, it is true" do
      module = Lamina.Provider.Default
      assert {:ok, ^module} = Provider.assert_provider_module(module)
    end

    test "when the module does not implement the Lamina.Provider behaviour, it is false" do
      module = module_factory()
      assert {:error, %NotAProviderModuleError{}} = Provider.assert_provider_module(module)
    end
  end

  describe "start/2" do
    test "it delegates to the the provider's `init/1` function" do
      init_opts = [a: 1, b: 2]

      Default
      |> expect(:init, fn ^init_opts ->
        {:ok, :state}
      end)

      assert {:ok, :state} = Provider.start(Default, init_opts)
    end

    test "when the provider's init function raises, it returns an error" do
      Default
      |> expect(:init, fn _ -> raise "hell" end)

      assert {:error, %RuntimeError{message: "hell"}} = Provider.start(Default, [])
    end
  end

  describe "fetch_config/3" do
    test "it delegates to the provider's `fetch_config/3` function" do
      config_key = :marty_mcfly
      state = []

      Default
      |> expect(:fetch_config, fn ck, s ->
        assert ck == config_key
        assert s == state
      end)

      Provider.fetch_config(Default, config_key, state)
    end

    test "when the provider's fetch_config function raises, it returns an error" do
      Default
      |> expect(:fetch_config, fn _, _ -> raise "hell" end)

      assert {:error, %RuntimeError{message: "hell"}} =
               Provider.fetch_config(Default, :config_key, [])
    end
  end

  describe "config_change/3" do
    test "it delegates to the provider's `config_change/2' callback" do
      callback_fun = &Function.identity/1
      state = []

      Default
      |> expect(:config_change, fn f, s ->
        assert f == callback_fun
        assert s == state
      end)

      Provider.config_change(Default, callback_fun, state)
    end

    test "when the provider's config_change function raises, it returns an error" do
      Default
      |> expect(:config_change, fn _, _ -> raise "hell" end)

      assert {:error, %RuntimeError{message: "hell"}} =
               Provider.config_change(Default, &Function.identity/1, [])
    end
  end
end
