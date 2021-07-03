defmodule Lamina.Error.ConfigNotFoundError do
  @attrs ~w[config_key table state]a
  defexception @attrs
  alias Lamina.{Error.ConfigNotFoundError}
  alias Lamina.Server.{State, Table}

  @moduledoc """
  No configuration value was found.

  This is the result of querying the ETS table for a value, but no applicable
  record being present.  Some possible reasons for this to happen:

    - No providers returned a value for this config key.
    - All values present in the table have expired.
    - The config key is incorrect.
  """

  @type t :: %ConfigNotFoundError{
          config_key: atom,
          table: nil | Table.t(),
          state: nil | State.t()
        }

  @impl true
  def exception(opts) when is_list(opts) do
    attrs = opts |> Keyword.take(@attrs)

    struct(ConfigNotFoundError, attrs)
  end

  @impl true
  def message(%ConfigNotFoundError{config_key: config_key, table: table}),
    do: "No value for `#{config_key}` found in table `#{inspect(table)}`."

  def message(%ConfigNotFoundError{config_key: config_key, state: %State{} = state}),
    do:
      "The module `#{inspect(state.module)}` does not contain a configuration called `#{config_key}`"
end
