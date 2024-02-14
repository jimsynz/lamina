defmodule Lamina.Error.StateError do
  @attrs ~w[reason state]a
  defexception @attrs
  alias Lamina.{Error.StateError, Server.State}

  @moduledoc """
  The Lamina Server is in an invalid state.

  This is an internal error within `Lamina.Server` and is strongly indicitave of
  a bug.  Please [open an issue][1].

  [1]: https://harton.dev/james/lamina/-/issues
  """

  @type t :: %StateError{
          reason: String.t(),
          state: State.t(),
          __exception__: true
        }

  @impl true
  def exception(opts) when is_list(opts) do
    attrs = opts |> Keyword.take(@attrs)

    struct(StateError, attrs)
  end

  @impl true
  def message(%StateError{reason: reason, state: %{name: name}}),
    do: "Lamina server for config `#{inspect(name)}` is in an invalid state: #{reason}."

  def message(%StateError{reason: reason}),
    do: "Lamina server is in an invalid state: #{reason}."
end
