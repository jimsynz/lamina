defmodule Lamina.Server.Impl do
  alias Lamina.Error.StateError
  alias Lamina.Registry.{PubSubRegistry, ServerRegistry}
  alias Lamina.Server.{ConfigModule, ConfigValue, Provider, State, Table}

  @moduledoc """
  Separates the functional implementation from the stateful GenServer.
  """

  @type provider :: module
  @type config_key :: atom

  @doc """
  Initialise the table and server state from the provided options.
  """
  @spec init(nonempty_improper_list(module, keyword)) :: {:ok, State.t()} | {:error, any}
  def init([module | opts]) do
    with {:ok, module} <- ConfigModule.is_lamina_module(module),
         table <- Table.new(module),
         {:ok, _pid} <- ServerRegistry.register(module, table),
         config_keys <- ConfigModule.config_keys(module),
         providers <- ConfigModule.providers(module),
         state_args <-
           Keyword.merge(opts,
             module: module,
             table: table,
             providers: providers,
             config_keys: config_keys
           ),
         {:ok, state} <- State.init(state_args),
         {:ok, state} <- start_providers(state),
         {:ok, config_values, state} <- fetch_all_config_from_all_providers(state),
         :ok <- Table.insert(table, config_values) do
      {:ok, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Call `config_change/2` on all providers with a function which they can use to
  trigger refreshes.
  """
  @spec set_provider_config_change_callbacks(State.t()) :: {:ok, State} | {:error, any}
  def set_provider_config_change_callbacks(%State{provider_order: provider_order} = state) do
    provider_order
    |> Enum.reduce_while({:ok, state}, fn provider, {:ok, state} ->
      with fun <- build_callback_function(provider, state),
           {:ok, state} <-
             with_provider_state(provider, state, &Provider.config_change(provider, fun, &1)) do
        {:cont, {:ok, state}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Refreshes all configuration for a provider.
  """
  @spec refresh_provider(provider, State.t()) :: {:ok, State} | {:error, any}
  def refresh_provider(provider, %State{config_keys: config_keys} = state) do
    config_keys
    |> Enum.reduce_while({:ok, state}, fn config_key, {:ok, state} ->
      case get_latest_value(provider, config_key, state) do
        {:ok, _config_value, state} -> {:cont, {:ok, state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  If `config_value` is volatile, then ask the Lamina server to make sure that it
  has the freshest information.
  """
  @spec maybe_get_latest(pid, ConfigValue.t()) :: {:ok, ConfigValue.t()} | {:error, any}
  def maybe_get_latest(pid, %ConfigValue{lifetime: :volatile} = config_value),
    do: GenServer.call(pid, {:get_latest, config_value})

  def maybe_get_latest(_pid, config_value), do: {:ok, config_value}

  @spec build_callback_function(provider, State.t()) :: (config_key -> :ok | {:error, any})
  defp build_callback_function(provider, %State{module: module}) do
    fn config_key ->
      case ServerRegistry.lookup(module) do
        {:ok, pid, _} -> send(pid, {:refresh, provider, config_key})
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec start_providers(State.t()) :: {:ok, State.t()} | {:error, any}
  defp start_providers(%State{provider_opts: provider_opts, providers_started: false} = state) do
    provider_opts
    |> Enum.reduce_while({:ok, %{}}, fn {provider, opts}, {:ok, provider_states} ->
      case Provider.start(provider, opts) do
        {:ok, state, interval} when is_integer(interval) and interval > 0 ->
          :timer.send_interval(interval, {:refresh, provider})

          {:cont, {:ok, Map.put(provider_states, provider, state)}}

        {:ok, state} ->
          {:cont, {:ok, Map.put(provider_states, provider, state)}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, provider_states} ->
        {:ok, %State{state | provider_states: provider_states, providers_started: true}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec fetch_all_config_from_all_providers(State.t()) ::
          {:ok, [ConfigValue.t()], State.t()} | {:error, any}
  defp fetch_all_config_from_all_providers(
         %State{
           config_keys: config_keys,
           provider_order: provider_order,
           providers_started: true
         } = state
       ) do
    provider_order
    |> Stream.with_index()
    |> Stream.flat_map(fn {provider, idx} ->
      Stream.map(config_keys, fn config_key ->
        {provider, idx, config_key}
      end)
    end)
    |> Enum.reduce_while({:ok, [], state}, fn
      {provider, idx, config_key}, {:ok, config_values, state} ->
        case refresh_config_from_provider(provider, config_key, state, idx) do
          {:ok, state} -> {:cont, {:ok, config_values, state}}
          {:ok, value, state} -> {:cont, {:ok, [value | config_values], state}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  @spec refresh_config_from_provider(provider, config_key, State.t()) ::
          {:ok, State.t()} | {:ok, ConfigValue.t(), State.t()} | {:error, any}
  defp refresh_config_from_provider(
         provider,
         config_key,
         %State{provider_order: provider_order} = state
       ) do
    case Enum.find_index(provider_order, &(&1 == provider)) do
      nil ->
        {:error,
         StateError.exception(
           state: state,
           reason: "Unable to locate the provider `#{inspect(provider)}`."
         )}

      idx ->
        refresh_config_from_provider(provider, config_key, state, idx)
    end
  end

  @spec refresh_config_from_provider(provider, config_key, State.t(), non_neg_integer()) ::
          {:ok, State.t()} | {:ok, ConfigValue.t(), State.t()} | {:error, any}
  defp refresh_config_from_provider(
         provider,
         config_key,
         %State{provider_states: provider_states, module: module, table: table} = state,
         idx
       ) do
    with {:ok, provider_state} <- Map.fetch(provider_states, provider),
         {:ok, value, lifetime, provider_state} <-
           Provider.fetch_config(provider, config_key, provider_state),
         {:ok, config_value} <-
           ConfigValue.init(config_key, lifetime, module, provider, idx, value),
         {:ok, config_value} <- ConfigValue.cast(config_value),
         {:ok, config_value} <- ConfigValue.validate(config_value) do
      Table.insert(table, [config_value])

      if is_integer(config_value.expires_at) do
        now = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        refresh_delay = trunc((config_value.expires_at - now) * state.ttl_refresh_fraction)
        Process.send_after(self(), {:refresh, config_value}, refresh_delay)
      end

      provider_states = Map.put(provider_states, provider, provider_state)
      {:ok, config_value, %State{state | provider_states: provider_states}}
    else
      :error ->
        {:error,
         StateError.exception(
           state: state,
           reason: "State for provider `#{inspect(provider)}` missing."
         )}

      {:error, reason} ->
        {:error, reason}

      {:ok, provider_state} ->
        provider_states = Map.put(provider_states, provider, provider_state)
        Table.remove(table, provider, config_key)
        {:ok, %State{state | provider_states: provider_states}}
    end
  end

  @doc """
  Query `provider` for the latest `config_key`.

  If the provider has a new value, and it is different to the old value, then broadcast the change to subscribers, and call the config module's `config_change/3` callback.
  """
  @spec get_latest_value(provider, config_key, State.t()) ::
          {:ok, State.t()} | {:ok, ConfigValue.t(), State.t()} | {:error, any}
  def get_latest_value(provider, config_key, %State{table: table, module: module} = state) do
    with {:ok, %ConfigValue{value: initial_value}} <- Table.get(table, config_key),
         {:ok, state} <- ensure_latest_provider_value(provider, config_key, state),
         {:ok, %ConfigValue{value: final_value} = final_config} <- Table.get(table, config_key) do
      if initial_value != final_value do
        Task.start_link(fn ->
          PubSubRegistry.publish(module, config_key, initial_value, final_value)
          ConfigModule.config_change(module, config_key, initial_value, final_value)
        end)
      end

      {:ok, final_config, state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ensure_latest_provider_value(provider, config_key, State.t()) ::
          {:ok, State.t()} | {:error, any}
  defp ensure_latest_provider_value(provider, config_key, state) do
    case refresh_config_from_provider(provider, config_key, state) do
      {:ok, _, state} -> {:ok, state}
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec with_provider_state(provider, State.t(), (any -> any)) :: {:ok, State.t()} | {:error, any}
  defp with_provider_state(provider, %State{provider_states: provider_states} = state, callback)
       when is_function(callback, 1) do
    with {:ok, provider_state} <- Map.fetch(provider_states, provider),
         {:ok, provider_state} <- apply(callback, [provider_state]) do
      provider_states = Map.put(provider_states, provider, provider_state)
      {:ok, %State{state | provider_states: provider_states}}
    else
      :error ->
        {:error,
         StateError.exception(
           state: state,
           reason: "State for provider `#{inspect(provider)}` missing."
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
