defmodule Lamina.Error.NotRegisteredError do
  defexception [:module]
  alias Lamina.Error.NotRegisteredError

  @moduledoc """
  Lamina is unable to locate the configuration module in the registry.

   Lamina uses an Elixir node-local `Registry` to keep track of all the
  configuration modules and their respective ETS tables.  This error indicates
  that a request has been made to retrieve the pid or table of a configuration
  module which is not present in the registry.

  This is most likely to happen if the Lamina server process has exited for some
  reason and could not be or has not yet been restarted.
  """

  @type t :: %NotRegisteredError{
          module: module,
          __exception__: true
        }

  @impl true
  def exception(module), do: %NotRegisteredError{module: module}

  @impl true
  def message(%NotRegisteredError{module: module}),
    do: "Module `#{inspect(module)}` does not implement the `Lamina` behaviour."
end
