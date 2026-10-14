defmodule Koyomi.DateRange do
  @moduledoc """
  An Ecto type for a range of days. The value is a `Date.Range` with a
  step of 1, both ends included.

  The `:storage` option says how the range is stored, so that the same
  field works with any database:

    * `:postgres` (the default) - a PostgreSQL `daterange` column. It
      needs `:postgrex`.
    * `:string` - a text column with an ISO 8601 interval,
      `"2027-03-01/2027-03-07"`: SQLite, MySQL, and embedded schemas.
    * `:map` - a map column (JSON in SQLite and MySQL, `jsonb` in
      PostgreSQL) with `%{"from" => "2027-03-01", "to" => "2027-03-07"}`.

  ```elixir
  # PostgreSQL
  add :stay, :daterange
  field :stay, Koyomi.DateRange

  # SQLite (ecto_sqlite3), MySQL
  add :stay, :string
  field :stay, Koyomi.DateRange, storage: :string
  ```

  A string or a map sorts and compares as text, not as a range: a query
  for the ranges that hold a day needs PostgreSQL. With another database,
  two `:date` columns also work, with the `from` and `to` of
  `Koyomi.Components.date_range_picker/1`, and can be queried as dates.

  The range picker posts the range as a map, `%{"from" => "2027-03-01",
  "to" => "2027-03-07"}`; the type also casts a `Date.Range`, a
  `{first, last}` tuple and an ISO 8601 interval
  (`"2027-03-01/2027-03-07"`). Both ends empty cast to `nil`. A range
  with one end, or with an end before its start, is invalid.

  PostgreSQL keeps a `daterange` in its canonical form, `[first, last + 1)`;
  the type writes that form and reads any form back as a `Date.Range`. A
  range without a bound (infinite) or an empty range reads back as `nil`.
  """

  use Ecto.ParameterizedType

  @storages [:postgres, :string, :map]

  @impl Ecto.ParameterizedType
  def init(opts) do
    storage = Keyword.get(opts, :storage, :postgres)

    cond do
      storage not in @storages ->
        raise ArgumentError,
              "Koyomi.DateRange: :storage must be one of #{inspect(@storages)}, got: #{inspect(storage)}"

      storage == :postgres and not Code.ensure_loaded?(Postgrex.Range) ->
        raise ArgumentError, """
        Koyomi.DateRange stores a PostgreSQL daterange by default, which needs :postgrex. \
        With another database, give `storage: :string` (a text column) or `storage: :map`.\
        """

      true ->
        %{storage: storage}
    end
  end

  @impl Ecto.ParameterizedType
  def type(%{storage: :postgres}), do: :daterange
  def type(%{storage: :string}), do: :string
  def type(%{storage: :map}), do: :map

  @impl Ecto.ParameterizedType
  def cast(value, _params), do: cast(value)

  @impl Ecto.ParameterizedType
  def dump(value, _dumper, %{storage: :postgres}), do: dump(value)
  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(%Date.Range{} = range, _dumper, %{storage: :string}) do
    %{"from" => from, "to" => to} = to_params(ordered(range))
    {:ok, from <> "/" <> to}
  end

  def dump(%Date.Range{} = range, _dumper, %{storage: :map}),
    do: {:ok, to_params(ordered(range))}

  def dump(_value, _dumper, _params), do: :error

  @impl Ecto.ParameterizedType
  def load(value, _loader, %{storage: :postgres}), do: load(value)
  def load(nil, _loader, _params), do: {:ok, nil}

  def load(value, _loader, %{storage: storage}) when storage in [:string, :map] do
    case cast(value) do
      {:ok, range} -> {:ok, range}
      _error -> :error
    end
  end

  @impl Ecto.ParameterizedType
  def equal?(a, b, _params), do: equal?(a, b)

  # In an embedded schema (JSON), a range is kept in the form of its
  # storage; give an embedded field `storage: :string` or `storage: :map`,
  # since a daterange has no JSON form.
  @impl Ecto.ParameterizedType
  def embed_as(_format, %{storage: :postgres}), do: :self
  def embed_as(_format, _params), do: :dump

  @doc """
  Casts a value to a `Date.Range` (see the module docs for the forms it
  takes).

  ## Examples

      iex> Koyomi.DateRange.cast("2027-03-01/2027-03-07")
      {:ok, Date.range(~D[2027-03-01], ~D[2027-03-07])}

  """
  @spec cast(term()) :: {:ok, Date.Range.t() | nil} | :error | {:error, keyword()}
  def cast(nil), do: {:ok, nil}

  def cast(%Date.Range{first: first, last: last, step: 1}), do: build(first, last)
  def cast(%Date.Range{first: first, last: last, step: -1}), do: build(last, first)

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

  defp ordered(%Date.Range{first: first, last: last}) do
    if Date.compare(first, last) == :gt,
      do: Date.range(last, first),
      else: Date.range(first, last)
  end

  @doc """
  Dumps a range to a PostgreSQL `daterange` (`Postgrex.Range`), in its
  canonical form `[first, last + 1)`.
  """
  @spec dump(Date.Range.t() | nil) :: {:ok, term()} | :error
  if Code.ensure_loaded?(Postgrex.Range) do
    def dump(nil), do: {:ok, nil}

    def dump(%Date.Range{} = range) do
      %Date.Range{first: first, last: last} = ordered(range)

      {:ok,
       %Postgrex.Range{
         lower: first,
         upper: Date.add(last, 1),
         lower_inclusive: true,
         upper_inclusive: false
       }}
    end

    def dump(_other), do: :error
  else
    def dump(_value), do: :error
  end

  @doc """
  Loads a PostgreSQL `daterange` (`Postgrex.Range`) of any form as a
  `Date.Range`; an infinite or empty range loads as `nil`.
  """
  @spec load(term()) :: {:ok, Date.Range.t() | nil} | :error
  if Code.ensure_loaded?(Postgrex.Range) do
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
    def load(_value), do: :error
  end

  @doc false
  @spec equal?(term(), term()) :: boolean()
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
