defmodule Lamina.Server.ConfigValue do
  defstruct ~w[config_key expires_at lifetime module provider provider_index value]a
  alias Lamina.Server.{ConfigModule, ConfigValue}

  @moduledoc """
  A wrapper around an individual configuration value.

  It makes the code much simpler. That is all.
  """

  @type config_key :: atom
  @type lifetime :: Lamina.Provider.lifetime()
  @type provider :: module
  @type provider_index :: pos_integer

  @type t :: %ConfigValue{
          config_key: atom,
          expires_at: nil | pos_integer,
          lifetime: lifetime,
          module: module,
          provider: module,
          provider_index: pos_integer,
          value: any
        }

  @doc """
  Initialise a new ConfigValue.
  """
  @spec init(config_key, lifetime, module, provider, provider_index, any) ::
          {:ok, t} | {:error, Exception.t()}
  def init(config_key, lifetime, module, provider, provider_index, value)
      when is_atom(config_key) and is_atom(module) and is_atom(provider) and
             is_integer(provider_index) and provider_index >= 0 do
    {:ok,
     %ConfigValue{
       config_key: config_key,
       expires_at: expiry_for(lifetime),
       lifetime: lifetime,
       module: module,
       provider: provider,
       provider_index: provider_index,
       value: value
     }}
  end

  def init(_, _, _, _, _, _),
    do: {:error, ArgumentError.exception(message: "Unable to initialise config value.")}

  @doc """
  Perform a value cast using the ConfigValue's module.
  """
  @spec cast(t) :: {:ok, t} | {:error, any}
  def cast(%ConfigValue{module: module, config_key: config_key, value: value} = config_value) do
    case ConfigModule.cast(module, config_key, value) do
      {:ok, value} -> {:ok, %ConfigValue{config_value | value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Perform a value validation using the ConfigValue's module.
  """
  @spec validate(t) :: {:ok, t} | {:error, any}
  def validate(%ConfigValue{module: module, config_key: config_key, value: value} = config_value) do
    case ConfigModule.validate(module, config_key, value) do
      {:ok, _value} -> {:ok, config_value}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Has the ConfigValue expired?
  """
  @spec expired?(t) :: boolean
  def expired?(%ConfigValue{expires_at: nil}), do: false
  def expired?(%ConfigValue{expires_at: expires_at}), do: now() >= expires_at

  @spec now :: pos_integer
  defp now, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)

  # Compute an expiry time based on the value's lifetime.
  @spec expiry_for(lifetime) :: pos_integer()
  defp expiry_for({n, unit})
       when is_integer(n) and n >= 0 and unit in ~w[second millisecond microsecond nanosecond]a do
    DateTime.utc_now()
    |> DateTime.add(n, unit)
    |> DateTime.to_unix(:millisecond)
  end

  defp expiry_for(:static), do: nil
  defp expiry_for(:volatile), do: nil
end
