defmodule Lamina.Server.State do
  defstruct config_keys: [],
            gc_timeout: nil,
            module: nil,
            provider_order: [],
            provider_opts: [],
            provider_states: %{},
            providers_started: false,
            table: nil,
            ttl_refresh_fraction: nil

  @moduledoc """
  Defines the state of the Lamina server process.
  """

  alias Lamina.Server.State

  @type provider_state :: Lamina.Provider.state()

  @type t :: %State{
          config_keys: [atom],
          gc_timeout: pos_integer,
          module: atom,
          provider_order: [module],
          provider_opts: keyword,
          provider_states: %{optional(module) => provider_state},
          providers_started: boolean,
          table: Table.t(),
          ttl_refresh_fraction: float
        }

  # Yes, I recognise the irony of having configuration hard coded.
  @default_ttl_refresh_fraction 0.95
  @default_gc_timeout :timer.seconds(3)

  @spec init(keyword) :: {:ok, t} | {:error, any}
  def init(opts) when is_list(opts) do
    with {:ok, providers} <- do_fetch(opts, :providers),
         provider_order <- Enum.map(providers, &elem(&1, 0)),
         provider_states <- Enum.map(providers, &{elem(&1, 0), nil}) |> Enum.into(%{}),
         {:ok, config_keys} <- do_fetch(opts, :config_keys),
         {:ok, module} <- do_fetch(opts, :module),
         {:ok, table} <- do_fetch(opts, :table),
         {:ok, gc_timeout} <- fetch_gc_timeout(opts),
         {:ok, ttl_refresh_fraction} <- fetch_ttl_refresh_fraction(opts) do
      {:ok,
       %State{
         config_keys: config_keys,
         gc_timeout: gc_timeout,
         module: module,
         provider_opts: providers,
         provider_order: provider_order,
         provider_states: provider_states,
         table: table,
         ttl_refresh_fraction: ttl_refresh_fraction
       }}
    else
      {:error, {:field_not_found, key}} ->
        {:error,
         ArgumentError.exception(
           message: "Unable to initialise server state - key `#{key}` not found."
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec do_fetch(keyword, atom) :: {:ok, any} | {:error, {:field_not_found, atom}}
  defp do_fetch(opts, keyword) when is_list(opts) and is_atom(keyword) do
    case Keyword.fetch(opts, keyword) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:field_not_found, keyword}}
    end
  end

  @spec fetch_gc_timeout(keyword) :: {:ok, pos_integer} | {:error, StateError.t()}
  defp fetch_gc_timeout(opts) do
    case Keyword.fetch(opts, :gc_timeout) do
      {:ok, value} when is_integer(value) and value > 0 ->
        {:ok, value}

      {:ok, _} ->
        {:error, ArgumentError.exception(message: "GC timeout must be a positive integer.")}

      :error ->
        {:ok, @default_gc_timeout}
    end
  end

  @spec fetch_ttl_refresh_fraction(keyword) :: {:ok, float} | {:error, StateError.t()}
  defp fetch_ttl_refresh_fraction(opts) do
    case Keyword.fetch(opts, :ttl_refresh_fraction) do
      {:ok, value} when is_float(value) and value > 0 and value < 1 ->
        {:ok, value}

      {:ok, _} ->
        {:error,
         ArgumentError.exception(
           message: "TTL refresh fraction should be a float between 0 and 1."
         )}

      :error ->
        {:ok, @default_ttl_refresh_fraction}
    end
  end
end
