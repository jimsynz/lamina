defmodule Lamina.Server.Table do
  @moduledoc """
  A wrapper around ETS for our specific use cases.
  """

  alias Lamina.Error.ConfigNotFoundError
  alias Lamina.Server.ConfigValue

  @type t :: :ets.tid()
  @type provider :: module
  @type value :: any
  @type lifetime :: Lamina.Provider.lifetime()

  @doc """
  Initialises a new ETS table.
  """
  @spec new(module) :: t
  def new(module), do: :ets.new(module, [:ordered_set, read_concurrency: true])

  @doc """
  Insert any number of configuration values into the ETS table.
  """
  @spec insert(t, [ConfigValue.t()]) :: :ok
  def insert(table, config_values) when is_list(config_values) do
    rows = Enum.map(config_values, &config_value_to_row/1)
    :ets.insert(table, rows)
    :ok
  end

  @doc """
  Remove matching configuration values from the ETS table.
  """
  @spec remove(t, provider, config_key) :: :ok when config_key: atom
  def remove(table, provider, config_key) do
    :ets.match_delete(table, {{config_key, :_}, :_, provider, :_, :_, :_})
    :ok
  end

  @doc """
  Find the most likely configuration value for a given configuration key.

  This executes a gently complicated match spec against the ETS table to find a
  configuration value which has the highest provider priority and is not
  expired.
  """
  @spec get(t, atom) :: {:ok, ConfigValue.t()} | {:error, ConfigNotFoundError.t()}
  def get(table, config_key) do
    now = now()

    match_spec = [
      {{{config_key, :"$1"}, :"$2", :"$3", :"$4", :"$5", :"$6"},
       [{:orelse, {:==, :"$6", nil}, {:>, :"$6", now}}],
       [{{{{config_key, :"$1"}}, :"$2", :"$3", :"$4", :"$5", :"$6"}}]}
    ]

    table
    |> :ets.select_reverse(match_spec, 1)
    |> case do
      {[row], _} -> {:ok, row_to_config_value(row)}
      _ -> {:error, ConfigNotFoundError.exception(table: table, config_key: config_key)}
    end
  end

  @doc """
  Get a specific configuration value from the ETS table.

  Searches by `config_key` and `provider` only - **does not take into account
  the row's expiry time**.
  """
  @spec get(t, atom, provider) :: {:ok, ConfigValue.t()} | {:error, ConfigNotFoundError.t()}
  def get(table, config_key, provider) do
    match_spec = [{{{config_key, :"$1"}, :"$2", provider, :"$3", :"$4", :"$5"}, [], [:"$_"]}]

    table
    |> :ets.select(match_spec, 1)
    |> case do
      {[row], _} -> {:ok, row_to_config_value(row)}
      _ -> {:error, ConfigNotFoundError.exception(table: table, config_key: config_key)}
    end
  end

  @doc """
  Delete any expired rows from the ETS table.
  """
  @spec expire(t) :: :ok
  def expire(table) do
    now = now()

    match_spec = [
      {{:_, :_, :_, :_, :_, :"$1"}, [{:andalso, {:is_integer, :"$1"}, {:<, :"$1", now}}], [true]}
    ]

    :ets.select_delete(table, match_spec)

    :ok
  end

  defp config_value_to_row(%ConfigValue{
         config_key: config_key,
         expires_at: expires_at,
         lifetime: lifetime,
         module: module,
         provider: provider,
         provider_index: provider_index,
         value: value
       }),
       do: {{config_key, provider_index}, module, provider, value, lifetime, expires_at}

  defp row_to_config_value(
         {{config_key, provider_index}, module, provider, value, lifetime, expires_at}
       ),
       do: %ConfigValue{
         config_key: config_key,
         expires_at: expires_at,
         lifetime: lifetime,
         module: module,
         provider: provider,
         provider_index: provider_index,
         value: value
       }

  defp now,
    do:
      DateTime.utc_now()
      |> DateTime.to_unix(:millisecond)
end
