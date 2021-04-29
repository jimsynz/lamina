defmodule Lamina.Server do
  use GenServer
  require Logger
  alias Lamina.Error.{ConfigNotFoundError, NotRegisteredError, StateError}
  alias Lamina.Registry.{PubSubRegistry, ServerRegistry}
  alias Lamina.Server.{ConfigModule, ConfigValue, Provider, State, Table}

  @moduledoc """
  The Lamina configuration server.
  """

  @type state :: State.t()
  @type lifetime :: Lamina.Provider.lifetime()
  @type provider :: Lamina.Provider.t()
  @type provider_state :: any
  @type value :: any
  @type config_key :: Lamina.config_key()

  # Yes, I recognise the irony of having configuration hard coded.
  @ttl_fresh_fraction 0.95
  @gc_timeout :timer.seconds(3)

  @doc """
  Initialise the configuration server.

  Initialises the configuration server by calling the callbacks defined by the
  `Lamina` behaviour on the config module and starts all the module's providers
  and loads all the configuration.

  If any step in this process fails, then the server will fail to start.
  """
  @impl true
  def init([module]) do
    with {:ok, module} <- ConfigModule.is_lamina_module(module),
         table <- Table.new(module),
         {:ok, _pid} <- ServerRegistry.register(module, table),
         config_keys <- ConfigModule.config_keys(module),
         providers <- ConfigModule.providers(module),
         {:ok, state} <-
           State.init(
             module: module,
             table: table,
             providers: providers,
             config_keys: config_keys
           ),
         {:ok, state} <- start_providers(state),
         {:ok, config_values, state} <- fetch_all_config(state),
         :ok <- Table.insert(table, config_values) do
      {:ok, state, {:continue, :set_provider_config_change_callbacks}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc """
  Retrieve a configuration value.

  This is the function which is called by the dynamically generated
  configuration functions in the configuration module, ie calling
  `MyHttpServer.Config.listen_port()` and
  `Lamina.Server.get(MyHttpServer.Config, :listen_port)` are functionally
  identical.

  Looks the server pid and ETS table up in Lamina registry, then queries the
  table for the best match configuration value.  In most cases this should allow
  the configuration value to be returned quickly without having to wait for a
  GenServer round-trip as both `Registry` and the server use ETS tables with
  read concurrency enabled.

  The only case where a call needs to be made to the server is when the best
  configuration value is marked as `:volatile` by the provider - ie the value
  can theoretically be different each time it's called.  This is the case for
  the `Env` and `ApplicationEnv` providers, as both of these provide wrappers
  around a potentially volatile store.

  ## Example

      iex> Server.get(MyHttpServer.Config, :listen_port)
      ...> {:ok, 4000}
  """
  @spec get(module, config_key) ::
          {:ok, value} | {:error, ConfigNotFoundError.t() | NotRegisteredError.t()}
  def get(module, config_key) do
    with {:ok, pid, table} <- ServerRegistry.lookup(module),
         {:ok, config_value} <- Table.get(table, config_key),
         {:ok, %ConfigValue{value: value}} <- maybe_get_volatile(config_value, pid, table) do
      {:ok, value}
    end
  end

  @impl GenServer
  def handle_call(
        {:get_volatile,
         %ConfigValue{provider: provider, config_key: config_key, value: old_value}},
        _from,
        %State{} = state
      ) do
    case do_refresh(provider, config_key, old_value, state) do
      {:ok, state} -> {:reply, :ok, state, @gc_timeout}
      {:ok, config_value, state} -> {:reply, {:ok, config_value}, state, @gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl GenServer
  def handle_info(
        {:refresh, %ConfigValue{provider: provider, config_key: config_key, value: old_value}},
        %State{} = state
      ) do
    case do_refresh(provider, config_key, old_value, state) do
      {:ok, state} -> {:noreply, state, @gc_timeout}
      {:ok, _config_value, state} -> {:noreply, state, @gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info({:refresh, provider, config_key}, %State{} = state) do
    with {:ok, old_value} <- maybe_get_value(provider, config_key, state),
         {:ok, _config_value, state} <- do_refresh(provider, config_key, old_value, state) do
      {:noreply, state, @gc_timeout}
    else
      {:ok, state} -> {:noreply, state, @gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info({:refresh, provider}, %State{config_keys: config_keys} = state) do
    config_keys
    |> Enum.reduce_while({:ok, state}, fn config_key, {:ok, state} ->
      with {:ok, old_value} <- maybe_get_value(provider, config_key, state),
           {:ok, _config_value, state} <- do_refresh(provider, config_key, old_value, state) do
        {:cont, {:ok, state}}
      else
        {:ok, state} -> {:cont, {:ok, state}}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> case do
      {:ok, state} -> {:noreply, state, @gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info(:timeout, %State{table: table} = state) do
    Table.expire(table)
    {:noreply, state, @gc_timeout}
  end

  @impl GenServer
  def handle_continue(
        :set_provider_config_change_callbacks,
        %State{provider_order: provider_order} = state
      ) do
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
    |> case do
      {:ok, state} -> {:noreply, state, @gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

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

  @spec fetch_all_config(State.t()) :: {:ok, [ConfigValue.t()], State.t()} | {:error, any}
  defp fetch_all_config(
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
        case fetch_config(provider, config_key, state, idx) do
          {:ok, state} -> {:cont, {:ok, config_values, state}}
          {:ok, value, state} -> {:cont, {:ok, [value | config_values], state}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  @spec fetch_config(provider, config_key, State.t()) ::
          {:ok, State.t()} | {:ok, ConfigValue.t(), State.t()} | {:error, any}
  defp fetch_config(provider, config_key, %State{provider_order: provider_order} = state) do
    case Enum.find_index(provider_order, &(&1 == provider)) do
      nil ->
        {:error,
         StateError.exception(
           state: state,
           reason: "Unable to locate the provider `#{inspect(provider)}`."
         )}

      idx ->
        fetch_config(provider, config_key, state, idx)
    end
  end

  @spec fetch_config(provider, config_key, State.t(), non_neg_integer()) ::
          {:ok, State.t()} | {:ok, ConfigValue.t(), State.t()} | {:error, any}
  defp fetch_config(
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
      now =
        DateTime.utc_now()
        |> DateTime.to_unix(:millisecond)

      maybe_queue_refresh(config_value, now)
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

  defp do_refresh(provider, config_key, old_value, %State{table: table} = state) do
    with {:ok, %ConfigValue{value: new_value} = config_value, state} <-
           fetch_config(provider, config_key, state),
         {:ok, state} <-
           maybe_handle_new_config_value(provider, config_key, old_value, new_value, state) do
      Table.insert(table, [config_value])
      {:ok, config_value, state}
    end
  end

  # We only queue a refresh for values which expire in the future.
  defp maybe_queue_refresh(
         %ConfigValue{expires_at: expires_at} = config_value,
         now
       )
       when is_integer(expires_at) and expires_at > now do
    refresh_delay = trunc((expires_at - now) * @ttl_fresh_fraction)
    Process.send_after(self(), {:refresh, config_value}, refresh_delay)
    :ok
  end

  defp maybe_queue_refresh(_config_value, _now), do: :ok

  defp maybe_get_volatile(
         %ConfigValue{lifetime: :volatile, config_key: config_key} = config_value,
         pid,
         table
       ) do
    case GenServer.call(pid, {:get_volatile, config_value}) do
      {:ok, config_value} -> {:ok, config_value}
      :ok -> Table.get(table, config_key)
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_get_volatile(%ConfigValue{} = config_value, _pid, _table), do: {:ok, config_value}

  @spec maybe_handle_new_config_value(provider, config_key, old_value, new_value, State.t()) ::
          {:ok, state}
        when old_value: any, new_value: any
  defp maybe_handle_new_config_value(
         provider,
         config_key,
         old_value,
         new_value,
         %State{module: module} = state
       )
       when old_value != new_value do
    Logger.debug(
      "Config for #{inspect(provider)} #{config_key} changed from #{inspect(old_value)} to #{
        inspect(new_value)
      }"
    )

    PubSubRegistry.publish(module, config_key, old_value, new_value)

    Task.start_link(fn ->
      ConfigModule.config_change(module, config_key, old_value, new_value)
    end)

    {:ok, state}
  end

  defp maybe_handle_new_config_value(_, _, _, _, state), do: {:ok, state}

  @spec maybe_get_value(provider, config_key, State.t()) :: {:ok, any}
  defp maybe_get_value(provider, config_key, %State{table: table}) do
    case Table.get(table, config_key, provider) do
      {:ok, %ConfigValue{value: value}} -> {:ok, value}
      _ -> {:ok, nil}
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
