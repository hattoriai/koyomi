defmodule Koyomi.DateTimeRange do
  @moduledoc """
  An Ecto type for a span of time, stored in a PostgreSQL `tstzrange`
  column: a start and an end instant, the start included and the end
  left out (`[from, to)`), as for a booking from 14:00 to 16:00.

      # The migration
      add :booking, :tstzrange

      # The schema
      field :booking, Koyomi.DateTimeRange

  The value is a `%Koyomi.DateTimeRange{from: DateTime, to: DateTime}`,
  in UTC. The type casts this struct, a `{from, to}` tuple, and a map
  with `"from"` and `"to"`: two `DateTime`, or two ISO 8601 strings with
  an offset (`"2027-03-15T14:00:00+01:00"`), as two date and time pickers
  with a `time_zone` post them. Both ends empty cast to `nil`. A span that
  ends before it starts is invalid.

  The type needs `:postgrex` to dump and load.
  """

  use Ecto.Type

  @enforce_keys [:from, :to]
  defstruct [:from, :to]

  @type t :: %__MODULE__{from: DateTime.t(), to: DateTime.t()}

  @impl Ecto.Type
  def type, do: :tstzrange

  @impl Ecto.Type
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

  if Code.ensure_loaded?(Postgrex.Range) do
    @impl Ecto.Type
    def dump(nil), do: {:ok, nil}

    def dump(%__MODULE__{from: from, to: to}) do
      {:ok,
       %Postgrex.Range{lower: from, upper: to, lower_inclusive: true, upper_inclusive: false}}
    end

    def dump(_other), do: :error

    @impl Ecto.Type
    def load(nil), do: {:ok, nil}

    def load(%Postgrex.Range{lower: %DateTime{} = lower, upper: %DateTime{} = upper}),
      do: {:ok, %__MODULE__{from: utc(lower), to: utc(upper)}}

    def load(%Postgrex.Range{}), do: {:ok, nil}
    def load(_other), do: :error
  else
    @impl Ecto.Type
    def dump(_value), do: :error

    @impl Ecto.Type
    def load(_value), do: :error
  end

  @impl Ecto.Type
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b),
    do: DateTime.compare(a.from, b.from) == :eq and DateTime.compare(a.to, b.to) == :eq

  def equal?(a, b), do: a == b

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
