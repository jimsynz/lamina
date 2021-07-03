defmodule Lamina.Error.InvalidValueError do
  @attrs ~w[provider config_key value]a
  defexception @attrs
  alias Lamina.Error.InvalidValueError

  @moduledoc """
  A configuration value returned by a provider has failed validation.
  """

  @impl true
  def exception(opts) when is_list(opts) do
    attrs =
      opts
      |> Keyword.take(@attrs)

    struct(InvalidValueError, attrs)
  end

  @impl true
  def message(%InvalidValueError{provider: provider, config_key: config_key, value: value}) do
    "Provider `#{inspect(provider)}` returned invalid value `#{inspect(value)}` for config key `#{config_key}`"
  end
end
