defmodule Lamina.Server.ConfigValueTest do
  use ExUnit.Case
  use Mimic
  alias Lamina.Server.{ConfigModule, ConfigValue}
  import Factory
  @moduledoc false

  setup do
    config_value = build(:config_value)

    {:ok, config_value: config_value}
  end

  describe "init/6" do
    setup %{config_value: config_value} do
      args =
        ~w[config_key lifetime module provider provider_index value]a
        |> Enum.map(&Map.get(config_value, &1))

      {:ok, config_value: config_value, args: args}
    end

    test "when the lifetime is `:volatile` it does not calculate an expiry", %{args: args} do
      [config_key, _, module, provider, provider_index, value] = args

      assert {:ok, config_value} =
               ConfigValue.init(config_key, :volatile, module, provider, provider_index, value)

      assert is_nil(config_value.expires_at)
    end

    test "when the lifetime is `:static` it does not calculate an expiry", %{args: args} do
      [config_key, _, module, provider, provider_index, value] = args

      assert {:ok, config_value} =
               ConfigValue.init(config_key, :static, module, provider, provider_index, value)

      assert is_nil(config_value.expires_at)
    end

    test "when the lifetime has a TTL calculates an expiry", %{args: args} do
      [config_key, _, module, provider, provider_index, value] = args

      ttl = {180, :second}

      expected =
        DateTime.utc_now()
        |> DateTime.add(180, :second)
        |> DateTime.to_unix(:millisecond)

      assert {:ok, config_value} =
               ConfigValue.init(config_key, ttl, module, provider, provider_index, value)

      assert_in_delta(expected, config_value.expires_at, 750)
    end
  end

  describe "cast/1" do
    test "it delegates to `ConfigModule.cast/3`", %{config_value: config_value} do
      ConfigModule
      |> expect(:cast, fn m, ck, v ->
        assert m == config_value.module
        assert ck == config_value.config_key
        assert v == config_value.value
        {:ok, "Behold! I am a new value!"}
      end)

      assert {:ok, %ConfigValue{value: "Behold! I am a new value!"}} =
               ConfigValue.cast(config_value)
    end
  end

  describe "validate/1" do
    test "it delegates to `ConfigModule.validate/3`", %{config_value: config_value} do
      ConfigModule
      |> expect(:validate, fn m, ck, v ->
        assert m == config_value.module
        assert ck == config_value.config_key
        assert v == config_value.value
        {:ok, v}
      end)

      assert {:ok, ^config_value} = ConfigValue.validate(config_value)
    end
  end

  describe "expired?/1" do
    test "when the value has no expires at time, it is not expired", %{config_value: config_value} do
      config_value =
        config_value
        |> Map.put(:expires_at, nil)

      refute ConfigValue.expired?(config_value)
    end

    test "when the value has expired, it is true", %{config_value: config_value} do
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(-180, :second)
        |> DateTime.to_unix(:millisecond)

      config_value =
        config_value
        |> Map.put(:expires_at, expires_at)

      assert ConfigValue.expired?(config_value)
    end

    test "when the value has not expired, it is false", %{config_value: config_value} do
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(180, :second)
        |> DateTime.to_unix(:millisecond)

      config_value =
        config_value
        |> Map.put(:expires_at, expires_at)

      refute ConfigValue.expired?(config_value)
    end
  end
end
