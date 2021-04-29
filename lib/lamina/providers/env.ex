defmodule Lamina.Provider.Env do
  use Lamina.Provider

  @moduledoc """
  A configuration provider for retrieving information from the UNIX process
  environment.

  Allows you to use process enviroment variables as application configuration.

  This is a very simple wrapper around `System.get_env/2`.  See the Elixir core
  documentation for more information.

  ## Name mangling

  We use a process called "name mangling" to convert an atom configuration key
  into the name of an environment variable.  The default mangler
  (`name_mangler/2`) converts the configuration key into UPPER_SNAKE_CASE with
  an optional prefix.

  Should you need to you can define your own mangler function and pass it as the
  `:mangler` option to this provider.

  ## Examples

  Given the following environment variables:

  | Name              |   Value |
  | ----------------- | ------- |
  | PHOENIX_HTTP_PORT |    4000 |
  | BIND_ADDR         | 0.0.0.0 |

  We can retrieve the configurations from the environment:

      iex> {:ok, state, _} = Env.init(prefix: "PHOENIX")
      ...> {:ok, "4000", :volatile, _state} = Env.fetch_config(:http_port, state)

      iex> {:ok, state, _} = Env.init([])
      ...> {:ok, "0.0.0.0", :volatile, _state} = Env.fetch_config(:bind_addr, state)

  """

  @type options :: [option]
  @type option :: prefix_option | mangler_option | refresh_period_opion
  @type prefix_option :: {:prefix, String.t()}
  @type mangler_option :: {:mangler, (atom, any -> String.t())}
  @type refresh_period_opion :: {:refresh_period, pos_integer}
  @type state :: %{
          required(:mangler) => (atom, any -> String.t()),
          required(:refresh_period) => pos_integer,
          optional(:prefix) => String.t()
        }

  @default_refresh_period :timer.seconds(10)

  @impl true
  @spec init(keyword) :: {:ok, state, pos_integer}
  def init(opts) do
    state = %{
      mangler: Keyword.get(opts, :mangler, &name_mangler/2),
      refresh_period: Keyword.get(opts, :refresh_period, @default_refresh_period)
    }

    state =
      case Keyword.get(opts, :prefix) do
        prefix when is_binary(prefix) and byte_size(prefix) > 0 -> Map.put(state, :prefix, prefix)
        _ -> state
      end

    {:ok, state, state.refresh_period}
  end

  @doc false
  @impl true
  @spec fetch_config(config_key, state) ::
          {:ok, value, lifetime, state} | {:ok, state} | {:error, reason, state}
        when config_key: atom,
             lifetime: Lamina.Provider.lifetime(),
             value: any,
             reason: any
  def fetch_config(config_key, %{mangler: mangler} = state) do
    name = apply(mangler, [config_key, state])

    case System.fetch_env(name) do
      {:ok, value} -> {:ok, value, :volatile, state}
      :error -> {:ok, state}
    end
  end

  @doc """
  The default name mangler for environment variables.

  Converts the configuration key into an upper-case underscored string,
  optionally with a prefix.

  ## Examples:

      iex> Env.name_mangler(:http_port, %{})
      "HTTP_PORT"

      iex> Env.name_mangler(:http_port, %{prefix: "phoenix"})
      "PHOENIX_HTTP_PORT"
  """
  @spec name_mangler(Lamina.config_key(), state) :: String.t()
  def name_mangler(config_key, %{prefix: prefix}) when is_atom(config_key),
    do: Recase.to_constant("#{prefix}_#{config_key}")

  def name_mangler(config_key, _opts) when is_atom(config_key),
    do: config_key |> to_string() |> Recase.to_constant()
end
