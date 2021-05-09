defmodule Lamina.Provider.ApplicationEnv do
  use Lamina.Provider

  @moduledoc """
  Configuration provider for the OTP application environment.

  Allows you to use the configuration from your application enviroment
  (typically stored in `config/config.exs` et al inside your project).

  In order to correctly find configuration for your application you must provide
  the `otp_app` option, and possibly a second-level configuration key.

  This is a very simple wrapper around `Application.get_all_env/1` and
  `Application.get_env/3`.  See the Elixir core documentation for more
  information.

  ## Examples

  Given the following configurations:

  ```elixir
  import Config
  config :lamina,
    jigga_watts: 1.21,
    time_machine: [model: :delorean, top_speed: 88]
  ```

  We can retrieve the configurations from the environment:

      iex> {:ok, state, _refresh_period} = ApplicationEnv.init(otp_app: :lamina)
      ...> {:ok, 1.21, :volatile, _state} = ApplicationEnv.fetch_config(:jigga_watts, state)

      iex> {:ok, state, _refresh_period} = ApplicationEnv.init(otp_app: :lamina, key: :time_machine)
      ...> {:ok, :delorean, :volatile, _state} = ApplicationEnv.fetch_config(:model, state)

  """

  @type options :: [option]
  @type option :: otp_app_option | key_option | refresh_period_option | lifetime_option
  @type otp_app_option :: {:otp_app, atom}
  @type key_option :: {:key, atom}
  @type refresh_period_option :: {:refresh_period, pos_integer()}
  @type lifetime_option :: {:lifetime, Lamina.Provider.lifetime()}

  @type state :: %{
          required(:otp_app) => atom,
          required(:refresh_period) => pos_integer,
          required(:lifetime) => Lamina.Provider.lifetime(),
          optional(:key) => atom
        }

  @default_refresh_period :timer.seconds(10)

  @doc false
  @impl true
  def init(opts) do
    state = %{
      refresh_period: Keyword.get(opts, :refresh_period, @default_refresh_period),
      lifetime: Keyword.get(opts, :lifetime, :volatile)
    }

    with {:ok, state} <- otp_app_config(state, opts),
         {:ok, state} <- key_config(state, opts) do
      {:ok, state, state.refresh_period}
    end
  end

  @doc false
  @impl true
  @spec fetch_config(config_key, state) ::
          {:ok, value, lifetime, state} | {:ok, state} | {:error, reason, state}
        when config_key: atom,
             lifetime: Lamina.Provider.lifetime(),
             value: any,
             reason: any
  def fetch_config(config_key, %{otp_app: otp_app, key: key, lifetime: lifetime} = state)
      when is_atom(config_key) do
    config =
      otp_app
      |> Application.get_env(key, [])

    case Keyword.fetch(config, config_key) do
      {:ok, value} -> {:ok, value, lifetime, state}
      :error -> {:ok, state}
    end
  end

  def fetch_config(config_key, %{otp_app: otp_app} = state) do
    config =
      otp_app
      |> Application.get_all_env()

    case Keyword.fetch(config, config_key) do
      {:ok, value} -> {:ok, value, :volatile, state}
      :error -> {:ok, state}
    end
  end

  @spec otp_app_config(map, keyword) :: {:ok, state} | {:error, any}
  defp otp_app_config(state, opts) do
    with {:ok, value} when is_atom(value) <- Keyword.fetch(opts, :otp_app),
         app_spec when is_list(app_spec) <- Application.spec(value) do
      {:ok, Map.put(state, :otp_app, value)}
    else
      nil ->
        {:error,
         ArgumentError.exception(
           message: "ApplicationEnv `otp_app` is not a valid OTP application"
         )}

      {:ok, _} ->
        {:error,
         ArgumentError.exception(message: "ApplicationEnv `otp_app` option must be an atom")}

      :error ->
        {:error,
         ArgumentError.exception(message: "ApplicationEnv provider requires an `otp_app` option")}
    end
  end

  @spec key_config(state, keyword) :: {:ok, state} | {:error, any}
  defp key_config(state, opts) do
    case Keyword.fetch(opts, :key) do
      {:ok, value} when is_atom(value) ->
        {:ok, Map.put(state, :key, value)}

      {:ok, _} ->
        {:error, ArgumentError.exception(message: "ApplicationEnv `key` option must be an atom")}

      :error ->
        {:ok, state}
    end
  end
end
