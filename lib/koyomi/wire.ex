defmodule Koyomi.Wire do
  @moduledoc false

  # A value in the form that the pickers read and post: an ISO 8601
  # string, `%{"from", "to"}` for a range, a list of ISO dates, or nil.

  alias Koyomi.{DateRange, DateTimeRange, Recurrence}

  @spec encode(term()) :: String.t() | map() | [String.t()] | nil
  def encode(nil), do: nil
  def encode(""), do: nil
  def encode(%Date{} = date), do: Date.to_iso8601(date)
  def encode(%Time{} = time), do: time |> Time.truncate(:second) |> Time.to_iso8601()

  def encode(%DateTime{} = value),
    do: value |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  def encode(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()

  def encode(%Date.Range{} = range), do: DateRange.to_params(range)

  def encode(%DateTimeRange{from: from, to: to}),
    do: %{"from" => encode(from), "to" => encode(to)}

  def encode(%Recurrence{} = rule), do: Recurrence.to_string(rule)
  def encode({%Date{} = first, %Date{} = last}), do: encode(Date.range(first, last))

  def encode(list) when is_list(list),
    do: list |> Enum.map(&encode/1) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

  def encode(value) when is_integer(value), do: Integer.to_string(value)
  def encode(value) when is_binary(value), do: value

  def encode(%{} = map) when not is_struct(map) do
    %{
      "from" => encode(Map.get(map, "from", Map.get(map, :from))),
      "to" => encode(Map.get(map, "to", Map.get(map, :to)))
    }
  end
end
