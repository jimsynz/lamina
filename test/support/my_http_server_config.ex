defmodule MyHttpServer.Config do
  use Lamina

  @moduledoc """
  This is an example configuration module, mostly used to tests.
  """

  provider(Lamina.Provider.Default, listen_port: 4000, listen_address: "0.0.0.0")
  provider(Lamina.Provider.ApplicationEnv, otp_app: :lamina, key: MyHttpServer.Endpoint)
  provider(Lamina.Provider.Env, prefix: "HTTP")

  @doc """
  The TCP port upon which to listen for HTTP requests.
  """
  config :listen_port do
    cast(&Lamina.Cast.to_integer/1)

    validate(fn
      port when is_integer(port) and (port in [80, 443] or port >= 1000) -> true
      _ -> false
    end)
  end

  @doc """
  The address of the network interface upon which to bind.
  """
  config :listen_address do
    validate(fn
      address when is_binary(address) ->
        address
        |> String.to_charlist()
        |> :inet.parse_address()
        |> case do
          {:ok, _} -> true
          _ -> false
        end

      _ ->
        false
    end)
  end
end
