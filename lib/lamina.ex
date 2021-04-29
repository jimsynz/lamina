defmodule Lamina do
  @moduledoc """
  Documentation for `Lamina`.

  Lamina allows you to define a run-time configuration pipeline that can
  marshall configuration from several sources.

  ## Example

  ```elixir
  defmodule MyHttpServer.Config do
    use Lamina,
      providers: [
        {Lamina.Provider.Default, listen_port: 4000, listen_address: "0.0.0.0"},
        {Lamina.Provider.ApplicationEnv, otp_app: :my_http_server, key: MyHttpServer.Endpoint},
        {Lamina.Provider.Env, prefix: "HTTP"}
      ],
      values: [
        listen_port: [cast: &String.to_integer/1],
        :listen_address
      ]

  end
  ```

  ## Lifetimes

  Every configuration item in Lamina has a lifetime attached to it.  Usually
  this is an implementation detail that you don't need to understand, but ...
  """

  @spec __using__(keyword) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :configs, accumulate: true)
      Module.register_attribute(__MODULE__, :providers, accumulate: true)
      import Lamina.DSL
      @before_compile Lamina.DSL
      @behaviour Lamina

      @doc false
      @spec child_spec(keyword) :: Supervisor.child_spec()
      def child_spec(_opts) do
        %{
          id: {Lamina.Server, __MODULE__},
          start: {GenServer, :start_link, [Lamina.Server, [__MODULE__]]},
          restart: :permanent,
          type: :worker
        }
      end

      @doc false
      @spec config_change(atom, any, any) :: :ok
      def config_change(config_key, old_value, new_value), do: :ok

      defoverridable config_change: 3
    end
  end

  @doc false
  @callback __lamina__(atom) :: []

  @doc """
  Called when the `Lamina.Server` detects a configuration change.

  This is a simple mechanism to
  """
  @callback config_change(config_key, old_value, new_value) :: :ok
            when config_key: atom, old_value: any, new_value: any
end
