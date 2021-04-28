defmodule LaminaTest do
  use ExUnit.Case
  doctest Lamina

  test "greets the world" do
    assert Lamina.hello() == :world
  end
end
