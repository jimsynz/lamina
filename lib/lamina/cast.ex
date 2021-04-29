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
end
