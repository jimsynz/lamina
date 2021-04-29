defmodule Lamina.Server.State do
  defstruct config_keys: [],
            module: nil,
            provider_order: [],
            provider_opts: [],
            provider_states: %{},
            providers_started: false,
            table: nil

  @moduledoc """
  Defines the state of the Lamina server process.
  """

  alias Lamina.Server.State

  @type provider_state :: Lamina.Provider.state()

  @type t :: %State{
          config_keys: [atom],
          module: atom,
          provider_order: [module],
          provider_opts: keyword,
          provider_states: %{optional(module) => provider_state},
          providers_started: boolean,
          table: Table.t()
        }

  @spec init(keyword) :: {:ok, t} | {:error, any}
  def init(opts) when is_list(opts) do
    with {:ok, providers} <- do_fetch(opts, :providers),
         provider_order <- Enum.map(providers, &elem(&1, 0)),
         provider_states <- Enum.map(providers, &{elem(&1, 0), nil}) |> Enum.into(%{}),
         {:ok, config_keys} <- do_fetch(opts, :config_keys),
         {:ok, module} <- do_fetch(opts, :module),
         {:ok, table} <- do_fetch(opts, :table) do
      {:ok,
       %State{
         config_keys: config_keys,
         module: module,
         provider_opts: providers,
         provider_order: provider_order,
         provider_states: provider_states,
         table: table
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
end
