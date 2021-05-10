defmodule Lamina.DSL do
  @moduledoc """
  Defines the macros used for building a configuration module.
  """

  @doc """
  Defines a provider for the configuration system.

  The same as `provider/2`, however passes an empty list to the provider's
  `init/1` function.
  """
  @spec provider(module) :: Macro.t()
  defmacro provider(module) do
    quote do
      @providers {unquote(module), []}
    end
  end

  @doc """
  Defines a provider for the configuration system.

  ## Arguments:

  - `module` - the name of a module which implements the `Lamina.Provider`
    behaviour.
  - `options` - a keyword list of options to be passed to the provider's
    `init/1` function.

  ## Example

  ```elixir
  provider(Lamina.Provider.Env, prefix: "HTTP")
  ```
  """
  @spec provider(module, keyword) :: Macro.t()
  defmacro provider(module, options) do
    quote do
      @providers {unquote(module), unquote(options)}
    end
  end

  @doc """
  Defines an individual configration parameter.

  The same as `config/2`, except that no block is provided.
  """
  @spec config(Lamina.config_key()) :: Macro.t()
  defmacro config(config_key) do
    quote do
      def unquote(config_key)() do
        Lamina.Server.get(__MODULE__, unquote(config_key))
      end

      def unquote(:"#{config_key}!")() do
        Lamina.Server.get!(__MODULE__, unquote(config_key))
      end

      @configs unquote(config_key)

      def __lamina__(unquote(config_key), :cast, value), do: value
      def __lamina__(unquote(config_key), :validate, _value), do: true
    end
  end

  @doc """
  Defines an individual configration parameter.

  ## Arguments:

    - `config_key` - the name of the new configuration parameter to define.
    - `block` - a "do block" which will be evaluated in the context of the
      `Lamina.DSL.Config` module.

  ## Example

  ```elixir
  config :listen_port do
    cast(&Lamina.Cast.to_integer/1)
    validate(&is_integer/1)
  end
  ```
  """
  @spec config(Lamina.config_key(), do: Macro.t()) :: Macro.t()
  defmacro config(config_key, do: block) do
    quote do
      def unquote(config_key)() do
        Lamina.Server.get(__MODULE__, unquote(config_key))
      end

      def unquote(:"#{config_key}!")() do
        Lamina.Server.get!(__MODULE__, unquote(config_key))
      end

      @configs unquote(config_key)

      import Lamina.DSL.Config
      @config_key unquote(config_key)
      @cast nil
      @validate nil

      unquote(block)
      @config_key nil

      unless @cast do
        def __lamina__(unquote(config_key), :cast, value), do: value
      end

      unless @validate do
        def __lamina__(unquote(config_key), :validate, _value), do: true
      end

      @cast nil
      @validate nil
    end
  end

  @doc false
  @spec __before_compile__(any) :: Macro.t()
  defmacro __before_compile__(_env) do
    quote do
      def __lamina__(:providers) do
        Enum.reverse(@providers)
      end

      def __lamina__(:config_keys) do
        Enum.reverse(@configs)
      end
    end
  end
end
