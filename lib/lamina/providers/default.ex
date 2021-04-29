defmodule Lamina.Provider.Default do
  use Lamina.Provider

  @moduledoc """
  Configuration provider for static default configuration values.

  Values are passed in as a keyword list of options to init.

  ## Example

      iex> {:ok, state} = Default.init(name: "Marty McFly")
      ...> {:ok, "Marty McFly", :static, _state} = Default.fetch_config(:name, state)
  """

  @doc false
  @impl true
  @spec fetch_config(config_key, state) ::
          {:ok, value, lifetime, state} | {:ok, state} | {:error, reason, state}
        when config_key: atom,
             lifetime: Lamina.Provider.lifetime(),
             value: any,
             reason: any,
             state: keyword
  def fetch_config(config_key, opts) do
    case Keyword.fetch(opts, config_key) do
      {:ok, value} -> {:ok, value, :static, opts}
      :error -> {:ok, opts}
    end
  end
end
