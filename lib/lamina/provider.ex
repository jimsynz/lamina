defmodule Lamina.Provider do
  @moduledoc """
  The `Provider` behaviour is used to declare configuration providers.

  Lamina's flexibility comes from the ability to provide adapters for may
  configuration sources and be able to query them in order to build a composite
  view of the system's configuration.  The `Lamina.Provider` behaviour allows
  you to define these adapters.

  ## Example:

  As a minimum you must implement the `fetch_config/2` callback, which is used
  to look up individual configuration values in your storage:

  ```elixir
  defmodule MapProvider do
    use Lamina.Provider

    @impl true
    def fetch_config(config_key, state) do
      case Map.fetch(state, config_key) do
        {:ok, value} -> {:ok, value, :volatile, state}
        :error -> {:ok, state}
      end
    end
  end
  ```
  """

  @type state :: any
  @type lifetime :: :static | :volatile | {pos_integer(), System.time_unit()}

  @doc false
  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      @behaviour Lamina.Provider

      @doc false
      @impl true
      def init(opts), do: {:ok, opts}

      @impl true
      def config_change(_fun, state), do: {:ok, state}

      defoverridable init: 1, config_change: 2
    end
  end

  @doc """
  Called by Lamina when initialising a configuration provider.

  If you're implementing a configuration provider, then this is your opportunity
  to do any setup work before any configuration is requested.

  When returning successfully, it is possible to include a `refresh_period`
  option, which indicates how often (in milliseconds) to refresh the
  configuration values of this provider.  This can be used by providers such as
  `Lamina.Provider.Env` which represent volatile data, but have no way of
  detecting change other than polling.
  """
  @callback init(keyword) :: {:ok, state} | {:ok, state, refresh_period} | {:error, any}
            when refresh_period: pos_integer

  @doc """
  Config change callback. Optional.

  Depending on the semantics of the provider, it may be necessary for the
  provider to proactively notify the Lamina server that a configuration value
  has changed.  After initialisation the server will call this callback on all
  providers with a function as it's first argument.

  Calling this function will cause the server to immediately call the
  `fetch_config/2` callback.
  """
  @callback config_change((config_key -> :ok | {:error, any}), state) ::
              {:ok, state} | {:error, any}
            when config_key: atom

  @doc """
  Called by Lamina when it wants to retrieve a configuration value.

  ## Arguments

    - `config_key` - the name of the configuration value to be returned.
    - `state` - the current provider state.

  ## Return values

  There are three possible return values:

    1. A successful retrieval of a configuration value, including a lifetime
       indicator.
    2. Inability to supply a configuration value, which is not an error.
    3. An error.

  ## Lifetime indicators

  When returning a configuration value, Lamina expects a provider to provide
  additional information about how long it can expect the value to be valid for.

  Valid lifetime indicators are:

    1. `:static` indicating that the value can never change.  This is most
       likely for a default value, or one which may have been compiled in.
    2. `:volatile` indicating that the value can potentially change every time
       it is read.
    3. A tuple containing a combination of a positive integer and a time unit.
       Units are those specified by the `System.time_unit` typespec. For example
       `{60, :second}` or `{3, :microsecond}`.  Useful for providers such as
       [Vault](https://www.vaultproject.io/) which allow values to be leased for
       a specific period of time.
  """
  @callback fetch_config(config_key, state) ::
              {:ok, value, lifetime, state} | {:ok, state} | {:error, reason, state}
            when config_key: atom,
                 value: any,
                 reason: any
end
