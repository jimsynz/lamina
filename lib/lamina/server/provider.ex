defmodule Lamina.Server.Provider do
  @moduledoc """
  Helps the Lamina server deal with individual providers.
  """

  alias Lamina.Error.NotAProviderModuleError

  @type state :: any
  @type provider :: module
  @type config_key :: atom
  @type lifetime :: Lamina.Provider.lifetime()

  @doc false
  @spec assert_provider_module(provider) ::
          {:ok, provider} | {:error, NotAProviderModuleError.t()}
  def assert_provider_module(module) do
    behaviours =
      :attributes
      |> module.__info__()
      |> Keyword.get(:behaviour, [])

    if Lamina.Provider in behaviours do
      {:ok, module}
    else
      {:error, NotAProviderModuleError.exception(module)}
    end
  rescue
    UndefinedFunctionError -> {:error, NotAProviderModuleError.exception(module)}
  end

  @doc false
  @spec start(provider, keyword) :: {:ok, state} | {:ok, state, pos_integer} | {:error, any}
  def start(module, opts) do
    case module.init(opts) do
      {:ok, state} -> {:ok, state}
      {:ok, state, interval} -> {:ok, state, interval}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  @spec fetch_config(provider, config_key, state) ::
          {:ok, state} | {:ok, any, lifetime, state} | {:error, any}
  def fetch_config(module, config_key, state) do
    module.fetch_config(config_key, state)
  rescue
    error -> {:error, error}
  end

  @doc false
  @spec config_change(provider, (config_key -> :ok | {:error, any}), state) ::
          {:ok, state} | {:error, any}
  def config_change(module, callback_fun, state) when is_function(callback_fun, 1) do
    module.config_change(callback_fun, state)
  rescue
    error -> {:error, error}
  end
end
