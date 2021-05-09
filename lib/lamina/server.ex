defmodule Lamina.Server do
  use GenServer
  require Logger
  alias Lamina.Registry.ServerRegistry
  alias Lamina.Server.{ConfigValue, Impl, State, Table}

  @moduledoc """
  The Lamina configuration server.

  This server is the owner of the ETS table used to store the configuration
  information and handles providers and their states as well as timers for
  refreshing and expiring the configuration.
  """

  @type state :: State.t()
  @type lifetime :: Lamina.Provider.lifetime()
  @type provider :: Lamina.Provider.t()
  @type provider_state :: any
  @type value :: any
  @type config_key :: Lamina.config_key()

  @doc """
  Initialise the configuration server.

  Initialises the configuration server by calling the callbacks defined by the
  `Lamina` behaviour on the config module, starts all the module's providers and
  loads all the configuration.

  If any step in this process fails the server will fail to start.
  """
  @impl true
  def init(opts) do
    case Impl.init(opts) do
      {:ok, state} -> {:ok, state, {:continue, :set_provider_config_change_callbacks}}
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
         {:ok, config_value} <- Impl.maybe_get_latest(pid, config_value) do
      {:ok, config_value.value}
    end
  end

  @doc """
  A raising version of `get/2`.
  """
  @spec get!(module, config_key) :: value | no_return
  def get!(module, config_key) do
    case get(module, config_key) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @impl GenServer
  def handle_call(
        {:get_latest, %ConfigValue{provider: provider, config_key: config_key}},
        _from,
        %State{} = state
      ) do
    case Impl.get_latest_value(provider, config_key, state) do
      {:ok, config_value, state} -> {:reply, {:ok, config_value}, state, state.gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl GenServer
  def handle_info(
        {:refresh, %ConfigValue{provider: provider, config_key: config_key}},
        %State{} = state
      ) do
    case Impl.get_latest_value(provider, config_key, state) do
      {:ok, _config_value, state} -> {:noreply, state, state.gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info({:refresh, provider, config_key}, %State{} = state) do
    case Impl.get_latest_value(provider, config_key, state) do
      {:ok, _config_value, state} -> {:noreply, state, state.gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info({:refresh, provider}, %State{} = state) do
    case Impl.refresh_provider(provider, state) do
      {:ok, state} -> {:noreply, state, state.gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  def handle_info(:timeout, %State{table: table} = state) do
    Table.expire(table)
    {:noreply, state, state.gc_timeout}
  end

  @impl GenServer
  def handle_continue(:set_provider_config_change_callbacks, %State{} = state) do
    case Impl.set_provider_config_change_callbacks(state) do
      {:ok, state} -> {:noreply, state, state.gc_timeout}
      {:error, reason} -> {:stop, reason, state}
    end
  end
end
