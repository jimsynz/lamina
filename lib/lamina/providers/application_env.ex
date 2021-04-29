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
  config :flat_app, jigga_watts: 1.21
  config :nested_app, :time_machine, model: :delorean
  ```

  We can retrieve the configurations from the environment:

      iex> {:ok, state} = ApplicationEnv.init(otp_app: :flat_app)
      ...> {:ok, 1.21, :volatile, _state} = ApplicationEnv.fetch_config(:jigga_watts, state)

      iex> {:ok, state} = ApplicationEnv.init(otp_app: :nested_app, key: :time_machine)
      ...> {:ok, :delorean, :volatile, _state} = ApplicationEnv.fetch_config(:model, state)

  """

  @type options :: [option]
  @type option :: otp_app_option | key_option
  @type otp_app_option :: {:otp_app, atom}
  @type key_option :: {:key, atom}

  @type state :: %{
          required(:otp_app) => atom,
          optional(:key) => atom
        }

  @doc false
  @impl true
  def init(opts) do
    with {:ok, state} <- otp_app_config(%{}, opts),
         {:ok, state} <- key_config(state, opts) do
      {:ok, state}
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
  def fetch_config(config_key, %{otp_app: otp_app, key: key} = state) when is_atom(config_key) do
    config =
      otp_app
      |> Application.get_env(key, [])

    case Keyword.fetch(config, config_key) do
      {:ok, value} -> {:ok, value, :volatile, state}
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
    case Keyword.fetch(opts, :otp_app) do
      {:ok, value} when is_atom(value) ->
        {:ok, Map.put(state, :otp_app, value)}

      {:ok, _} ->
        {:error, "ApplicationEnv `otp_app` option must be an atom"}

      :error ->
        {:error, "ApplicationEnv provider requires an `otp_app` option"}
    end
  end

  @spec key_config(state, keyword) :: {:ok, state} | {:error, any}
  defp key_config(state, opts) do
    case Keyword.fetch(opts, :key) do
      {:ok, value} when is_atom(value) -> {:ok, Map.put(state, :key, value)}
      {:ok, _} -> {:error, "ApplicationEnv `key` option must be an atom"}
      :error -> {:ok, state}
    end
  end
end
