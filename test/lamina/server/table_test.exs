defmodule Lamina.Server.TableTest do
  use ExUnit.Case, async: true
  alias Lamina.Server.Table
  import Factory
  @moduledoc false

  describe "new/1" do
    test "it returns a reference to a new table" do
      assert MyHttpServer.Config |> Table.new() |> is_reference()
    end
  end

  describe "insert/2" do
    setup do
      {:ok, table: Table.new(module_factory())}
    end

    test "inserts config values into the table", %{table: table} do
      assert :ets.tab2list(table) |> Enum.empty?()

      config_values = build_list(3, :config_value)

      assert :ok = Table.insert(table, config_values)
      assert :ets.tab2list(table) |> Enum.count() == 3
    end
  end

  describe "remove/3" do
    setup do
      {:ok, table: Table.new(module_factory())}
    end

    test "it removes matching config values from the table", %{table: table} do
      [first | _] = config_values = build_list(3, :config_value)
      assert :ok = Table.insert(table, config_values)

      assert :ok = Table.remove(table, first.provider, first.config_key)
      assert :ets.tab2list(table) |> Enum.count() == 2
    end
  end

  describe "expire/1" do
    setup do
      {:ok, table: Table.new(module_factory())}
    end

    test "when there are no expired rows, none are deleted", %{table: table} do
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(180, :second)
        |> DateTime.to_unix(:millisecond)

      config_values = build_list(3, :config_value, expires_at: expires_at)
      assert :ok = Table.insert(table, config_values)
      assert :ok = Table.expire(table)

      assert table |> :ets.tab2list() |> Enum.count() == 3
    end

    test "when there are expired rows, they are deleted", %{table: table} do
      expires_at =
        DateTime.utc_now()
        |> DateTime.add(-180, :second)
        |> DateTime.to_unix(:millisecond)

      config_values = build_list(3, :config_value, expires_at: expires_at)
      assert :ok = Table.insert(table, config_values)
      assert :ok = Table.expire(table)

      assert table |> :ets.tab2list() |> Enum.empty?()
    end
  end
end
