defmodule Lamina.Cast do
  @moduledoc """
  A helpful library of casts.

  Defining a cast function is brain-dead simple, however sometimes you just
  don't want to write the same thing over and over.  Here is a helpful pile of
  functions for common configuration castings.

  Feel free to [open a PR][1] to add more.

  [1]: https://gitlab.com/jimsy/lamina/-/merge_requests
  """

  @doc """
  Attempts to convert the inbound value into an integer.
  """
  @spec to_integer(integer | float | binary | charlist) :: integer | no_return
  def to_integer(value) when is_integer(value), do: value
  def to_integer(value) when is_float(value), do: trunc(value)
  def to_integer(value) when is_binary(value), do: String.to_integer(value)
  def to_integer(value) when is_list(value), do: List.to_integer(value)

  @doc """
  Attempts to convert the inbound value into an float.
  """
  @spec to_float(integer | float | binary | charlist) :: float | no_return
  def to_float(value) when is_integer(value), do: value / 1.0
  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_binary(value), do: String.to_float(value)
  def to_float(value) when is_list(value), do: List.to_float(value)

  @doc """
  Attempt to convert the inbound value into an atom.
  """
  @spec to_atom(integer | float | binary | charlist) :: atom | no_return
  def to_atom(value) when is_atom(value), do: value
  def to_atom(value) when is_binary(value), do: value |> String.to_atom()
  def to_atom(value) when is_number(value), do: value |> Kernel.to_string() |> String.to_atom()
  def to_atom(value) when is_list(value), do: value |> List.to_string() |> String.to_atom()

  @doc """
  Attempt to convert the inbound value into an atom.
  """
  @spec to_string(integer | float | binary | charlist) :: String.t() | no_return
  def to_string(value) when is_binary(value), do: value
  def to_string(value) when is_atom(value), do: value |> Kernel.to_string()
  def to_string(value) when is_number(value), do: value |> Kernel.to_string()
  def to_string(value) when is_list(value), do: value |> List.to_string()

  @doc """
  Attempt to convert the inbound value into a boolean.

  Things that are considered true:

    * A literal `true`.
    * The words "true" or "yes" in any capitalisation.

  Everything else is false.
  """
  @spec to_boolean(any) :: boolean | no_return
  def to_boolean(true), do: true

  def to_boolean(value) when is_binary(value) do
    value =
      value
      |> String.trim()
      |> String.downcase()

    value in ~w[yes true]
  end

  def to_boolean(value) when is_list(value),
    do: value |> List.to_string() |> to_boolean()

  def to_boolean(_), do: false
end
