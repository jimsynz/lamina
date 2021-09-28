defmodule Lamina.Registry.ServerRegistry do
  @moduledoc """
  An Elixir Registry which keeps track of `Lamina.Server` processes.
  """

  alias Lamina.{Error, Table}

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :unique, name: __MODULE__]]},
      restart: :permanent,
      type: :worker
    }
  end

  @spec register(module, :ets.tid()) :: {:ok, pid} | {:error, Error.AlreadyRegisteredError.t()}
  def register(module, table) when is_atom(module) when table do
    case Registry.register(__MODULE__, module, table) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_registered, pid}} ->
        {:error, Error.AlreadyRegisteredError.exception(module: module, pid: pid)}
    end
  end

  @spec lookup(module) :: {:ok, pid, Table.t()} | {:error, Error.NotRegisteredError.t()}
  def lookup(module) when is_atom(module) do
    case Registry.lookup(__MODULE__, module) do
      [{pid, table}] -> {:ok, pid, table}
      _ -> {:error, Error.NotRegisteredError.exception(module)}
    end
  end

  @doc """
  Returns a list of all the currently running configuration servers on this
  system.
  """
  @spec all_servers :: [module]
  def all_servers do
    __MODULE__
    |> Registry.select([{{:"$1", :_, :_}, [], [{{:"$1"}}]}])
    |> Enum.map(&elem(&1, 0))
  end
end
