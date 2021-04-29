defmodule Lamina.DSL.Config do
  @moduledoc """
  Defines the macros used inside the `config` macro.
  """

  @doc """
  Specify a transformation function to cast the value to the final required
  type.

  Some configuration providers (most notably `Env`) are only able to return
  strings, so it can be necessary to modify them before they're returned to the
  user.

  ## Example

  ```elixir
  defmodule MyHttpServer.Config do
    use Lamina

    provider(Lamina.Provider.Env)

    config :listen_port do
      cast(&String.to_integer/1)
    end
  end
  ```
  """
  @spec cast((any -> any)) :: Macro.t()
  defmacro cast(cast_fn) do
    quote do
      def __lamina__(@config_key, :cast, value), do: apply(unquote(cast_fn), [value])
      @cast true
    end
  end

  @doc """
  Specify a validation function to ensure that the value is valid.

  Gives you an opportunity to ensure that the value about to be returned to the
  user is correct.

  ## Example

  ```elixir
  defmodule MyFileReader.Config do
    use Lamina

    provider(Lamina.Provider.Env)

    config :file_to_read do
      validate(fn
        "/etc/password" -> false
        _ -> true
      end)
    end
  end
  ```
  """
  @spec validate((any -> boolean)) :: Macro.t()
  defmacro validate(validate_fn) do
    quote do
      def __lamina__(@config_key, :validate, value), do: apply(unquote(validate_fn), [value])
      @validate true
    end
  end
end
