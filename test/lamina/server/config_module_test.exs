defmodule Lamina.Server.ConfigModuleTest do
  use ExUnit.Case
  alias Lamina.Error.NotALaminaModuleError
  alias Lamina.Server.ConfigModule
  use Mimic
  import Factory
  @moduledoc false

  describe "assert_lamina_module/1" do
    test "when the module implements the Lamina behaviour, it is ok" do
      module = MyHttpServer.Config
      assert {:ok, ^module} = ConfigModule.assert_lamina_module(module)
    end

    test "when the module does not implement the Lamina behaviour, it is an error" do
      module = module_factory()
      assert {:error, %NotALaminaModuleError{}} = ConfigModule.assert_lamina_module(module)
    end
  end

  describe "config_keys/1" do
    test "it calls the Lamina callback" do
      MyHttpServer.Config
      |> expect(:__lamina__, &(&1 == :config_keys))

      assert ConfigModule.config_keys(MyHttpServer.Config)
    end
  end

  describe "providers/1" do
    test "it calls the Lamina callback" do
      MyHttpServer.Config
      |> expect(:__lamina__, &(&1 == :providers))

      assert ConfigModule.providers(MyHttpServer.Config)
    end
  end

  describe "cast/2" do
    test "it calls the lamina callback" do
      config_value = build(:config_value)

      MyHttpServer.Config
      |> expect(:__lamina__, fn key, :cast, value ->
        assert key == config_value.config_key
        assert value == config_value.value
        true
      end)

      assert {:ok, true} =
               ConfigModule.cast(MyHttpServer.Config, config_value.config_key, config_value.value)
    end
  end

  describe "validate/3" do
    test "it calls the Lamina callback" do
      config_value = build(:config_value)

      MyHttpServer.Config
      |> expect(:__lamina__, fn key, :validate, value ->
        assert key == config_value.config_key
        assert value == config_value.value
        true
      end)

      assert {:ok, config_value.value} ==
               ConfigModule.validate(
                 MyHttpServer.Config,
                 config_value.config_key,
                 config_value.value
               )
    end
  end
end
