defmodule Koyomi.DateTimeRange do
  @moduledoc """
  An Ecto type for a span of time: a start and an end instant, the start
  included and the end left out (`[from, to)`), as for a booking from
  14:00 to 16:00.

  The `:storage` option says how the span is stored, so that the same
  field works with any database:

    * `:postgres` (the default) - a PostgreSQL `tstzrange` column. It
      needs `:postgrex`.
    * `:string` - a text column with an ISO 8601 interval in UTC,
      `"2027-03-15T13:00:00Z/2027-03-15T15:00:00Z"`: SQLite, MySQL, and
      embedded schemas.
    * `:map` - a map column (JSON in SQLite and MySQL) with
      `%{"from" => "2027-03-15T13:00:00Z", "to" => "2027-03-15T15:00:00Z"}`.

  ```elixir
  # PostgreSQL
  add :booking, :tstzrange
  field :booking, Koyomi.DateTimeRange

  # SQLite (ecto_sqlite3), MySQL
  add :booking, :string
  field :booking, Koyomi.DateTimeRange, storage: :string
  ```

  A query for the spans that hold an instant needs PostgreSQL; with
  another database, two `:utc_datetime` columns can be queried as
  instants.

  The value is a `%Koyomi.DateTimeRange{from: DateTime, to: DateTime}`,
  in UTC. The type casts this struct, a `{from, to}` tuple, a map with
  `"from"` and `"to"` (two `DateTime`, or two ISO 8601 strings with an
  offset, `"2027-03-15T14:00:00+01:00"`, as two date and time pickers
  with a `time_zone` post them), and an ISO 8601 interval of two such
  strings. Both ends empty cast to `nil`. A span that ends before it
  starts is invalid.
  """

  use Ecto.ParameterizedType

  @enforce_keys [:from, :to]
  defstruct [:from, :to]

  @type t :: %__MODULE__{from: DateTime.t(), to: DateTime.t()}

  @storages [:postgres, :string, :map]

  @impl Ecto.ParameterizedType
  def init(opts) do
    storage = Keyword.get(opts, :storage, :postgres)

    cond do
      storage not in @storages ->
        raise ArgumentError,
              "Koyomi.DateTimeRange: :storage must be one of #{inspect(@storages)}, got: #{inspect(storage)}"

      storage == :postgres and not Code.ensure_loaded?(Postgrex.Range) ->
        raise ArgumentError, """
        Koyomi.DateTimeRange stores a PostgreSQL tstzrange by default, which needs :postgrex. \
        With another database, give `storage: :string` (a text column) or `storage: :map`.\
        """

      true ->
        %{storage: storage}
    end
  end

  @impl Ecto.ParameterizedType
  def type(%{storage: :postgres}), do: :tstzrange
  def type(%{storage: :string}), do: :string
  def type(%{storage: :map}), do: :map

  @impl Ecto.ParameterizedType
  def cast(value, _params), do: cast(value)

  @impl Ecto.ParameterizedType
  def dump(value, _dumper, %{storage: :postgres}), do: dump(value)
  def dump(nil, _dumper, _params), do: {:ok, nil}

  def dump(%__MODULE__{} = span, _dumper, %{storage: :string}) do
    %{"from" => from, "to" => to} = to_params(span)
    {:ok, from <> "/" <> to}
  end

  def dump(%__MODULE__{} = span, _dumper, %{storage: :map}), do: {:ok, to_params(span)}
  def dump(_value, _dumper, _params), do: :error

  @impl Ecto.ParameterizedType
  def load(value, _loader, %{storage: :postgres}), do: load(value)
  def load(nil, _loader, _params), do: {:ok, nil}

  def load(value, _loader, %{storage: storage}) when storage in [:string, :map] do
    case cast(value) do
      {:ok, span} -> {:ok, span}
      _error -> :error
    end
  end

  @impl Ecto.ParameterizedType
  def equal?(a, b, _params), do: equal?(a, b)

  # In an embedded schema (JSON), a span is kept in the form of its
  # storage; give an embedded field `storage: :string` or `storage: :map`,
  # since a tstzrange has no JSON form.
  @impl Ecto.ParameterizedType
  def embed_as(_format, %{storage: :postgres}), do: :self
  def embed_as(_format, _params), do: :dump

  @doc """
  Casts a value to a `Koyomi.DateTimeRange` (see the module docs for the
  forms it takes).
  """
  @spec cast(term()) :: {:ok, t() | nil} | :error | {:error, keyword()}
  def cast(nil), do: {:ok, nil}
  def cast(%__MODULE__{from: from, to: to}), do: build(from, to)
  def cast({from, to}), do: cast(%{"from" => from, "to" => to})

  def cast(%{} = map) when not is_struct(map) do
    from = Map.get(map, "from", Map.get(map, :from))
    to = Map.get(map, "to", Map.get(map, :to))

    case {from in [nil, ""], to in [nil, ""]} do
      {true, true} -> {:ok, nil}
      {false, false} -> with {:ok, a} <- instant(from), {:ok, b} <- instant(to), do: build(a, b)
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

  defp instant(%DateTime{} = value), do: {:ok, DateTime.shift_zone!(value, "Etc/UTC")}

  defp instant(text) when is_binary(text) do
    case DateTime.from_iso8601(String.trim(text)) do
      {:ok, value, _offset} -> {:ok, value}
      {:error, _reason} -> :error
    end
  end

  defp instant(_other), do: :error

  defp build(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :gt,
      do: {:error, message: "must end after its start"},
      else: {:ok, %__MODULE__{from: utc(from), to: utc(to)}}
  end

  defp build(_from, _to), do: :error

  defp utc(value), do: value |> DateTime.shift_zone!("Etc/UTC") |> DateTime.truncate(:second)

  @doc """
  Dumps a span to a PostgreSQL `tstzrange` (`Postgrex.Range`), `[from, to)`.
  """
  @spec dump(t() | nil) :: {:ok, term()} | :error
  if Code.ensure_loaded?(Postgrex.Range) do
    def dump(nil), do: {:ok, nil}

    def dump(%__MODULE__{from: from, to: to}) do
      {:ok,
       %Postgrex.Range{lower: from, upper: to, lower_inclusive: true, upper_inclusive: false}}
    end

    def dump(_other), do: :error
  else
    def dump(_value), do: :error
  end

  @doc """
  Loads a PostgreSQL `tstzrange` (`Postgrex.Range`); a span without a
  bound (infinite) or an empty one loads as `nil`.
  """
  @spec load(term()) :: {:ok, t() | nil} | :error
  if Code.ensure_loaded?(Postgrex.Range) do
    def load(nil), do: {:ok, nil}

    def load(%Postgrex.Range{lower: %DateTime{} = lower, upper: %DateTime{} = upper}),
      do: {:ok, %__MODULE__{from: utc(lower), to: utc(upper)}}

    def load(%Postgrex.Range{}), do: {:ok, nil}
    def load(_other), do: :error
  else
    def load(_value), do: :error
  end

  @doc false
  @spec equal?(term(), term()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b),
    do: DateTime.compare(a.from, b.from) == :eq and DateTime.compare(a.to, b.to) == :eq

  def equal?(a, b), do: a == b

  @doc """
  The span as ISO 8601 strings in UTC: `%{"from" => iso, "to" => iso}`.

  ## Examples

      iex> {:ok, span} = Koyomi.DateTimeRange.cast(%{"from" => "2027-03-15T14:00:00+01:00", "to" => "2027-03-15T16:00:00+01:00"})
      iex> Koyomi.DateTimeRange.to_params(span)
      %{"from" => "2027-03-15T13:00:00Z", "to" => "2027-03-15T15:00:00Z"}

  """
  @spec to_params(t()) :: %{String.t() => String.t()}
  def to_params(%__MODULE__{from: from, to: to}),
    do: %{"from" => DateTime.to_iso8601(from), "to" => DateTime.to_iso8601(to)}

  @doc """
  The length of the span.

  ## Examples

      iex> {:ok, span} = Koyomi.DateTimeRange.cast(%{"from" => "2027-03-15T14:00:00Z", "to" => "2027-03-15T16:30:00Z"})
      iex> Koyomi.DateTimeRange.duration(span, :minute)
      150

  """
  @spec duration(t(), System.time_unit()) :: integer()
  def duration(%__MODULE__{from: from, to: to}, unit \\ :second),
    do: DateTime.diff(to, from, unit)
end
