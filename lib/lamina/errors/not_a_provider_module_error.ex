defmodule Lamina.Error.NotAProviderModuleError do
  defexception [:module]
  alias Lamina.Error.NotAProviderModuleError

  @moduledoc """
  The module does not implement the `Lamina.Provider` behaviour.

  During startup, the Lamina server double checks that the providers it's been
  asked to use actually are `Lamina.Provider` modules and not just some other
  random module.

  Some reasons you could be seeing this error:

    - You have misspelt the name of the module when using the `provider` macro
      in your configuration module (or you're missing an alias).
    - You are developing a provider and haven't fully implemented all the
      required callbacks.
  """

  @type t :: %NotAProviderModuleError{
          module: module,
          __exception__: true
        }

  @impl true
  def exception(module), do: %NotAProviderModuleError{module: module}

  @impl true
  def message(%NotAProviderModuleError{module: module}),
    do: "Module `#{inspect(module)}` does not implement the `Lamina.Provider` behaviour."
end
