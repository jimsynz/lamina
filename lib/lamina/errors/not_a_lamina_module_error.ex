defmodule Lamina.Error.NotALaminaModuleError do
  defexception [:module]
  alias Lamina.Error.NotALaminaModuleError

  @moduledoc """
  The module does not implement the `Lamina` behaviour.

  During startup, the Lamina server double checks that the module it's been
  asked to manage actually is a Lamina module and not just some other random
  module.  Really the only way you should ever see this error in the wild is if
  you try and manually start `Lamina.Server` - which you probably shouldn't be
  doing anyway.
  """

  @type t :: %NotALaminaModuleError{
          module: module,
          __exception__: true
        }

  @impl true
  def exception(module), do: %NotALaminaModuleError{module: module}

  @impl true
  def message(%NotALaminaModuleError{module: module}),
    do: "Module `#{inspect(module)}` does not implement the `Lamina` behaviour."
end
