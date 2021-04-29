defmodule Lamina.Error.AlreadyRegisteredError do
  @attrs ~w[module pid]a
  defexception @attrs
  alias Lamina.Error.AlreadyRegisteredError

  @moduledoc """
  Lamina is unable to register the configuration module.

  Lamina uses an Elixir node-local `Registry` to keep track of all the
  configuration modules and their respective ETS tables.  This error indicates
  that an attempt has been made to add the same configuration module twice.

  This is most likely to happen if you have accidentally added your
  configuration module to a supervisor more than once.
  """

  @type t :: %AlreadyRegisteredError{
          module: module,
          __exception__: true
        }

  @impl true
  def exception(opts) when is_list(opts) do
    attrs = opts |> Keyword.take(@attrs)

    struct(AlreadyRegisteredError, attrs)
  end

  @impl true
  def message(%AlreadyRegisteredError{module: module, pid: pid}),
    do: "Module `#{inspect(module)}` already registered as pid `#{inspect(pid)}`."
end
