# Lamina

Dynamic, runtime configuration for your Elixir app.

Lamina allows you to define a run-time configuration pipeline that can merge
configuration from several sources.  This allows the system to be reactive to
changes in its environment.

## Example

The following example defines a configuration for an imaginary HTTP server
application which takes it's configuration from a combination of default values,
the OTP application environment and system environment variables:

```elixir
defmodule MyHttpServer.Config do
  use Lamina

  provider(Lamina.Provider.Default, listen_port: 4000, listen_address: "0.0.0.0")
  provider(Lamina.Provider.ApplicationEnv, otp_app: :my_http_server, key: MyHttpServer.Endpoint)
  provider(Lamina.Provider.Env, prefix: "HTTP")

  config :listen_port do
    cast(&Lamina.Cast.to_integer/1)

    validate(fn
      port when is_integer(port) and (port in [80, 443] or port >= 1000) -> true
      _ -> false
    end)
  end

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
```

Provider order is preserved, such that providers added later (via the
`provider/1` or `provider/2` macro) have more priority than their predecessors.
This has the effect that when more than one provider can provide a value for a
given configuration item, the most preferred value will be returned.

Each configuration item is defined using the `config/1` or `config/2` macro.  If
the configuration item does not need casting to another type, nor validation
then just defining it with `config/1` is sufficient.  In some cases it is
necessary to provide additional casting or validating functions.  They can be
provided by passing a block containing the `cast/1` or `validate/1` macros.

Make sure that you add your configuration module to your application's
supervisor tree **before** any processes that rely on it's information.  Lamina
will fail to start or shutdown on any errors it encounters.

## Lifetimes

All configuration items in Lamina are explicitly marked with a lifetime, which
must be specified by the configuration provider when returning values.  The
semantics are as follows:

- `:volatile` - a configuration that could potentially be different every time
  it is read.  Volatile configuration items are returned by the `ApplicationEnv`
  and `Env` providers.
- `:static` - a configuration value that is not going to change until the
  provider changes it.  Static configuration items are returned by the `Default`
  provider, but could also be used for a configuration provider that notifies
  the system of configuration changes in some way.
- `{non_neg_integer(), System.time_unit()}` - a value that has a specific expiry
  time.  This may be used for a configuration source that has explicit leases on
  values (ala [Vault](https://www.vaultproject.io/) or a value for which
  querying is expensive, and providing an expiry would effectively cache it.

## Querying

When asked to retrieve a configuration value, Lamina queries it's ETS table
using the following query plan; values for which there is no expiry, or which
have not yet expired, ordered by provider weight, descending.  It only ever
returns a single row.

If the returned row is marked as `:volatile` then the configuration provider is
immediately queried for a new value, meaning that these requests will pay the
cost of a `GenServer.call/3` to ensure freshness.  If this is an issue then you
should consider changing the provider lifetime to use an expiry.  The
`ApplicationEnv` and `Env` providers have a configuration option to do this.  If
you are the developer of a volatile provider, it is strongly suggested that you
provide for this use case.

## Server configuration

The following options can be passed to the `use Lamina` macro, although it's
probably advisable to leave them as their defaults.

- `gc_timeout: pos_integer()` - how long the server should be idle before
  removing expired configuration from the ETS table in milliseconds.  Defaults
  to 3000.
- `ttl_refresh_fraction: float` - when presented with a configuration value
  which has an expiry, the server queues a refresh at some point prior to the
  value expiring, in order to avoid having missing configuration.  Setting this
  to a value between `0` and `1` specifies the proportion of the expiry time to
  wait before attempting to refresh the value.  Defaults to `0.95`.

## Configuration subscriptions

Lamina defines a `subscribe/1` and `unsubscribe/1` function on each
configuration module, which uses a `Registry` to handle pub-sub for
configuration changes.

This allows your processes to subscribe to configuration changes and update or
restart any services they provide.

### Example

For example, a simple HTTP server which changes it's listen port in response to
a configuration change:

```elixir
defmodule MyHttpServer.Cowboy do
  use GenServer
  alias Plug.Cowboy
  alias MyHttpServer.{Config, Plug}

  def init(_) do
    with {:ok, port} <- Config.listen_port(),
        {:ok, srv} <- Cowboy.http(Plug, [], port: port),
        :ok <- Config.subscribe(:listen_port) do
      {:ok, %{srv: srv, port: port}}
    end
  end

  def handle_info({:config_change, Config, :listen_port, _old_port, new_port}, %{
        port: current_port
      })
      when new_port != current_port do
    with :ok <- Cowboy.shutdown(Plug.HTTP),
        {:ok, srv} <- Cowboy.http(Plug, [], port: new_port) do
      {:noreply, %{port: new_port, srv: srv}}
    else
      {:error, reason} -> {:stop, reason, nil}
    end
  end

  def handle_info({:config_change, _, _, _}, state), do: {:noreply, state}
end

## Installation

Lamina is [available in Hex](https://hex.pm/packages/lamina), the package can be installed
by adding `lamina` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lamina, "~> 0.2.0"}
  ]
end
```

Documentation for the latest release can be found on [HexDocs](https://hexdocs.pm/lamina) and for the `main` branch [here](https://gitlab.com/jimsy/lamina).
