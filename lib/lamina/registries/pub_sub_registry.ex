defmodule Lamina.Registry.PubSubRegistry do
  @moduledoc """
  An Elixir Registry which keeps track of configuration subscribers.
  """

  @doc false
  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Registry, :start_link, [[keys: :duplicate, name: __MODULE__]]},
      restart: :permanent,
      type: :worker
    }
  end

  @spec subscribe(module, config_key) :: :ok when config_key: atom
  def subscribe(module, config_key) when is_atom(config_key) do
    Registry.register(__MODULE__, {module, config_key}, nil)
    :ok
  end

  @spec unsubscribe(module, config_key) :: :ok when config_key: atom
  def unsubscribe(module, config_key) when is_atom(config_key) do
    Registry.unregister(__MODULE__, {module, config_key})
  end

  @spec publish(module, config_key, old_value, new_value) :: :ok
        when config_key: atom, old_value: any, new_value: any
  def publish(module, config_key, old_value, new_value) do
    Registry.dispatch(__MODULE__, {module, config_key}, fn entries ->
      for {pid, _} <- entries,
          do: send(pid, {:config_change, module, config_key, old_value, new_value})
    end)
  end
end
