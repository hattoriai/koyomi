defmodule Koyomi.DateRange do
  @moduledoc """
  An Ecto type for a range of days, stored in a PostgreSQL `daterange`
  column. The value is a `Date.Range` with a step of 1, both ends
  included.

      # The migration
      add :stay, :daterange

      # The schema
      field :stay, Koyomi.DateRange

  The range picker posts the range as a map, `%{"from" => "2027-03-01",
  "to" => "2027-03-07"}`; the type also casts a `Date.Range`, a
  `{first, last}` tuple and an ISO 8601 interval
  (`"2027-03-01/2027-03-07"`). Both ends empty cast to `nil`. A range
  with one end, or with an end before its start, is invalid.

  PostgreSQL keeps a `daterange` in its canonical form, `[first, last + 1)`;
  the type writes that form and reads any form back as a `Date.Range`. A
  range without a bound (infinite) or an empty range reads back as `nil`.

  The type needs `:postgrex` to dump and load. Without it, keep the two
  ends in two `:date` fields and give the picker `from` and `to` (see
  `Koyomi.Components.date_range_picker/1`).
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: :daterange

  @impl Ecto.Type
  def cast(nil), do: {:ok, nil}

  def cast(%Date.Range{first: first, last: last, step: step}) when step in [1, -1] do
    build(first, last)
  end

  def cast({%Date{} = first, %Date{} = last}), do: build(first, last)

  def cast(%{} = map) when not is_struct(map) do
    from = Map.get(map, "from", Map.get(map, :from))
    to = Map.get(map, "to", Map.get(map, :to))

    case {blank?(from), blank?(to)} do
      {true, true} -> {:ok, nil}
      {false, false} -> with {:ok, a} <- date(from), {:ok, b} <- date(to), do: build(a, b)
      _one_end -> {:error, message: "must have a start and an end"}
    end
  end

  def cast(text) when is_binary(text) do
    case String.split(String.trim(text), "/") do
      [""] -> {:ok, nil}
      [from, to] -> cast(%{"from" => from, "to" => to})
      _other -> :error
    end
  end

  def cast(_other), do: :error

  defp blank?(value), do: value in [nil, ""]

  defp date(%Date{} = date), do: {:ok, date}

  defp date(text) when is_binary(text) do
    case Date.from_iso8601(String.trim(text)) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp date(_other), do: :error

  defp build(first, last) do
    if Date.compare(first, last) == :gt,
      do: {:error, message: "must end on or after its start"},
      else: {:ok, Date.range(first, last)}
  end

  if Code.ensure_loaded?(Postgrex.Range) do
    @impl Ecto.Type
    def dump(nil), do: {:ok, nil}

    def dump(%Date.Range{first: first, last: last}) do
      {first, last} = if Date.compare(first, last) == :gt, do: {last, first}, else: {first, last}

      {:ok,
       %Postgrex.Range{
         lower: first,
         upper: Date.add(last, 1),
         lower_inclusive: true,
         upper_inclusive: false
       }}
    end

    def dump(_other), do: :error

    @impl Ecto.Type
    def load(nil), do: {:ok, nil}

    def load(%Postgrex.Range{lower: %Date{} = lower, upper: %Date{} = upper} = range) do
      first = if range.lower_inclusive, do: lower, else: Date.add(lower, 1)
      last = if range.upper_inclusive, do: upper, else: Date.add(upper, -1)

      if Date.compare(first, last) == :gt,
        do: {:ok, nil},
        else: {:ok, Date.range(first, last)}
    end

    def load(%Postgrex.Range{}), do: {:ok, nil}
    def load(_other), do: :error
  else
    @impl Ecto.Type
    def dump(_value), do: :error

    @impl Ecto.Type
    def load(_value), do: :error
  end

  @impl Ecto.Type
  def equal?(%Date.Range{first: a1, last: b1}, %Date.Range{first: a2, last: b2}),
    do: Date.compare(a1, a2) == :eq and Date.compare(b1, b2) == :eq

  def equal?(a, b), do: a == b

  @doc """
  The value of a range in the form that the picker reads and posts:
  `%{"from" => iso, "to" => iso}`, or empty strings for `nil`.

  ## Examples

      iex> Koyomi.DateRange.to_params(Date.range(~D[2027-03-01], ~D[2027-03-07]))
      %{"from" => "2027-03-01", "to" => "2027-03-07"}

  """
  @spec to_params(Date.Range.t() | nil) :: %{String.t() => String.t()}
  def to_params(nil), do: %{"from" => "", "to" => ""}

  def to_params(%Date.Range{first: first, last: last}),
    do: %{"from" => Date.to_iso8601(first), "to" => Date.to_iso8601(last)}
end
