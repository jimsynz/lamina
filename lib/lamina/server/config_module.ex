defmodule Lamina.Server.ConfigModule do
  alias Lamina.Error.{InvalidValueError, NotALaminaModuleError}
  @moduledoc "Wrapper around access to a Lamina configuration module"

  @doc """
  Ensure that the module in question actually implements the Lamina behaviour.
  """
  @spec assert_lamina_module(module) :: {:ok, module} | {:error, NotALaminaModuleError.t()}
  def assert_lamina_module(module) do
    behaviours =
      :attributes
      |> module.__info__()
      |> Keyword.get(:behaviour, [])

    if Lamina in behaviours do
      {:ok, module}
    else
      {:error, NotALaminaModuleError.exception(module)}
    end
  rescue
    UndefinedFunctionError -> {:error, NotALaminaModuleError.exception(module)}
  end

  @doc """
  Call the Lamina callback on the configuration module and return a list of
  config keys.
  """
  @spec config_keys(module) :: [atom]
  def config_keys(module), do: module.__lamina__(:config_keys)

  @doc """
  Call the Lamina callback on the configuration module and return the providers.
  """
  @spec providers(module) :: [{module, keyword}]
  def providers(module), do: module.__lamina__(:providers)

  @doc """
  Call the Lamina callback on the configuration module to cast a configuration
  value.
  """
  @spec cast(module, atom, any) :: {:ok, any} | {:error, any}
  def cast(module, config_key, value) do
    {:ok, module.__lamina__(config_key, :cast, value)}
  rescue
    error -> {:error, error}
  end

  @doc """
  Call the Lamina callback on the configuration module to validate a
  configuration value.
  """
  @spec validate(module, atom, any) :: {:ok, any} | {:error, any}
  def validate(module, config_key, value) do
    if module.__lamina__(config_key, :validate, value) do
      {:ok, value}
    else
      {:error,
       InvalidValueError.exception(provider: module, config_key: config_key, value: value)}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Call the `config_change/3` callback on the configuration module.
  """
  @spec config_change(module, config_key, old_value, new_value) :: :ok | no_return
        when config_key: atom, old_value: any, new_value: any
  def config_change(module, config_key, old_value, new_value),
    do: module.config_change(config_key, old_value, new_value)
end
