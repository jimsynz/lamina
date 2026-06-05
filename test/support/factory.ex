defmodule Factory do
  use ExMachina
  alias Lamina.Server.ConfigValue
  @moduledoc false

  @doc false
  def config_value_factory do
    lifetime = lifetime_factory()
    expires_at = build(:expires_at, lifetime: lifetime)

    config_key = random_word() |> Recase.to_snake() |> String.to_atom()

    %ConfigValue{
      config_key: config_key,
      expires_at: expires_at,
      lifetime: lifetime,
      module: module_factory(),
      provider: module_factory(),
      provider_index: :rand.uniform(99),
      value: random_word()
    }
  end

  @doc false
  def lifetime_factory do
    case :rand.uniform(3) do
      1 -> :volatile
      2 -> :static
      3 -> {:rand.uniform(180), Enum.random(~w[second millisecond microsecond nanosecond]a)}
    end
  end

  @doc false
  def expires_at_factory(attrs) do
    case Map.get(attrs, :lifetime, nil) do
      {n, unit} -> DateTime.utc_now() |> DateTime.add(n, unit) |> DateTime.to_unix(:millisecond)
      _ -> nil
    end
  end

  @doc false
  def module_factory do
    module =
      random_word()
      |> Recase.to_pascal()

    :"Elixir.#{module}"
  end

  defp random_word do
    1..Enum.random(4..12)
    |> Enum.map_join(fn _ -> <<Enum.random(?a..?z)>> end)
  end
end
