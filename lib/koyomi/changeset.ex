defmodule Koyomi.Changeset do
  @moduledoc """
  Changeset validations with the rules of a picker (see `Koyomi.Rules`).

  Give the same rules to the component and to the changeset, so that the
  browser and the server never disagree:

      @stay_rules Koyomi.Rules.new(min: :today, max_days: 14)

      def changeset(booking, attrs) do
        booking
        |> cast(attrs, [:stay])
        |> validate_required([:stay])
        |> Koyomi.Changeset.validate_range(:stay, @stay_rules)
      end

  Each validation checks the field only when it has a value (a change or
  the data's own value), and adds at most one error. The error has
  `validation: :koyomi` and `kind:` (the reason, see `t:Koyomi.Rules.error/0`)
  in its keys, and the values of the message (`min`, `max`, `count`,
  `date`...), so that `translate_error/1` of a Phoenix app can translate
  it. `count` is set for the messages with a number, for plural forms.

  ## Options

    * `:message` - a message for every error, or a map of messages by
      kind (`%{too_long: "a stay is two weeks at most"}`); the kinds that
      the map does not name keep the default message.
  """

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Koyomi.Rules

  @messages %{
    before_min: "must be on or after %{min}",
    after_max: "must be on or before %{max}",
    disabled: "is not available",
    disabled_in_range: "includes a day that is not available (%{date})",
    reversed: "must end on or after its start",
    too_short: "must be at least %{count} days",
    too_long: "must be at most %{count} days",
    too_few: "must have at least %{count} days",
    too_many: "must have at most %{count} days",
    time_before_min: "must be at or after %{min_time}",
    time_after_max: "must be at or before %{max_time}",
    time_step: "must be in steps of %{count} minutes",
    gap: "does not exist in %{time_zone} (the clocks change)",
    ambiguous: "happens twice in %{time_zone} (the clocks change)"
  }

  @doc """
  Returns the default error messages, by kind.

  ## Examples

      iex> Koyomi.Changeset.messages().disabled
      "is not available"

  """
  @spec messages() :: %{atom() => String.t()}
  def messages, do: @messages

  @doc """
  Validates a `:date` field (or a `Koyomi.Month` or `Koyomi.Week` field):
  its day must be allowed by the rules.

  ## Examples

      iex> types = %{due: :date}
      iex> changeset = Ecto.Changeset.cast({%{}, types}, %{"due" => "2027-03-13"}, [:due])
      iex> changeset = Koyomi.Changeset.validate_date(changeset, :due, disabled_weekdays: [6, 7])
      iex> changeset.errors
      [due: {"is not available", [validation: :koyomi, kind: :disabled, date: ~D[2027-03-13]]}]

  """
  @spec validate_date(Changeset.t(), atom(), Rules.t() | keyword(), keyword()) :: Changeset.t()
  def validate_date(%Changeset{} = changeset, field, rules, opts \\ []) when is_atom(field) do
    rules = Rules.new(rules)

    validate(changeset, field, opts, fn
      %Date{} = date -> Rules.check_date(rules, date)
      _other -> :ok
    end)
  end

  @doc """
  Validates a range of days.

  `field` is a `Koyomi.DateRange` field (a `Date.Range`), or a `{from, to}`
  tuple of two `:date` fields; with two fields, the error goes on `from`
  for a rule of its day and on `to` otherwise.

  ## Examples

      iex> types = %{check_in: :date, check_out: :date}
      iex> params = %{"check_in" => "2027-03-01", "check_out" => "2027-03-20"}
      iex> changeset = Ecto.Changeset.cast({%{}, types}, params, [:check_in, :check_out])
      iex> changeset = Koyomi.Changeset.validate_range(changeset, {:check_in, :check_out}, max_days: 14)
      iex> changeset.errors
      [check_out: {"must be at most %{count} days", [validation: :koyomi, kind: :too_long, count: 14, max_days: 14]}]

  """
  @spec validate_range(Changeset.t(), atom() | {atom(), atom()}, Rules.t() | keyword(), keyword()) ::
          Changeset.t()
  def validate_range(changeset, field, rules, opts \\ [])

  def validate_range(%Changeset{} = changeset, {from, to}, rules, opts) do
    rules = Rules.new(rules)

    with %Date{} = first <- get_field(changeset, from),
         %Date{} = last <- get_field(changeset, to),
         {:error, {kind, _keys} = error} <- Rules.check_range(rules, {first, last}) do
      # A rule of the first day goes on its field; the others on the last.
      on =
        if kind in [:before_min, :disabled] and Rules.check_date(rules, first) != :ok,
          do: from,
          else: to

      add(changeset, on, error, opts)
    else
      _ok_or_incomplete -> changeset
    end
  end

  def validate_range(%Changeset{} = changeset, field, rules, opts) when is_atom(field) do
    rules = Rules.new(rules)

    validate(changeset, field, opts, fn
      %Date.Range{} = range -> Rules.check_range(rules, range)
      _other -> :ok
    end)
  end

  @doc """
  Validates a list of days (`Koyomi.Dates` or `{:array, :date}`): each
  day, and the count of days.
  """
  @spec validate_dates(Changeset.t(), atom(), Rules.t() | keyword(), keyword()) :: Changeset.t()
  def validate_dates(%Changeset{} = changeset, field, rules, opts \\ []) when is_atom(field) do
    rules = Rules.new(rules)

    validate(changeset, field, opts, fn
      dates when is_list(dates) -> Rules.check_dates(rules, dates)
      _other -> :ok
    end)
  end

  @doc """
  Validates a `:time` field against `:min_time`, `:max_time` and `:step`.
  """
  @spec validate_time(Changeset.t(), atom(), Rules.t() | keyword(), keyword()) :: Changeset.t()
  def validate_time(%Changeset{} = changeset, field, rules, opts \\ []) when is_atom(field) do
    rules = Rules.new(rules)

    validate(changeset, field, opts, fn
      %Time{} = time -> Rules.check_time(rules, time)
      _other -> :ok
    end)
  end

  @doc """
  Validates a date and time field (`:utc_datetime`, `:naive_datetime` and
  their `_usec` forms): its day, its time of day in the time zone of the
  rules, and the bounds.
  """
  @spec validate_datetime(Changeset.t(), atom(), Rules.t() | keyword(), keyword()) ::
          Changeset.t()
  def validate_datetime(%Changeset{} = changeset, field, rules, opts \\ []) when is_atom(field) do
    rules = Rules.new(rules)

    validate(changeset, field, opts, fn
      %DateTime{} = value -> Rules.check_datetime(rules, value)
      %NaiveDateTime{} = value -> Rules.check_datetime(rules, value)
      _other -> :ok
    end)
  end

  @doc """
  Casts a date and time that a person gave in a time zone into a
  `DateTime` in UTC.

  The date and time picker with a `time_zone` posts an ISO 8601 string
  with the offset of the zone (`"2027-07-15T14:30:00+01:00"`), which a
  `:utc_datetime` field casts on its own. This function also reads a
  date and time without an offset (`"2027-03-15T14:30"`, as the browser's
  own input posts it when JavaScript is off) as a wall clock time in
  `time_zone`. Call it instead of listing the field in `cast/4`:

      booking
      |> cast(attrs, [:name])
      |> Koyomi.Changeset.cast_datetime(attrs, :starts_at, "Europe/Lisbon")

  A wall clock time that the zone skips (the hour the clocks go forward)
  gets the error `:gap`; a time that it repeats (the hour the clocks go
  back) takes the first of the two instants, or the second with
  `ambiguous: :later`, or gets the error `:ambiguous` with
  `ambiguous: :error`. A zone other than UTC needs a time zone database
  (see `Calendar`). `params` may have string or atom keys.
  """
  @spec cast_datetime(Changeset.t(), map(), atom(), String.t(), keyword()) :: Changeset.t()
  def cast_datetime(%Changeset{} = changeset, params, field, time_zone, opts \\ [])
      when is_atom(field) and is_binary(time_zone) do
    key = Atom.to_string(field)

    case Map.fetch(params, key) do
      {:ok, value} -> put_datetime(changeset, field, value, time_zone, opts)
      :error -> changeset |> cast_atom_key(params, field, time_zone, opts)
    end
  end

  defp cast_atom_key(changeset, params, field, time_zone, opts) do
    case Map.fetch(params, field) do
      {:ok, value} -> put_datetime(changeset, field, value, time_zone, opts)
      :error -> changeset
    end
  end

  defp put_datetime(changeset, field, value, _time_zone, _opts) when value in [nil, ""],
    do: put_change(changeset, field, nil)

  defp put_datetime(changeset, field, %DateTime{} = value, time_zone, _opts),
    do: put_cast(changeset, field, value, time_zone)

  defp put_datetime(changeset, field, value, time_zone, opts) when is_binary(value) do
    value = String.trim(value)

    case DateTime.from_iso8601(value) do
      {:ok, instant, _offset} ->
        put_cast(changeset, field, instant, time_zone)

      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> put_local(changeset, field, naive, time_zone, opts)
          {:error, _reason} -> add_error(changeset, field, "is invalid", validation: :cast)
        end

      {:error, _reason} ->
        case NaiveDateTime.from_iso8601(value <> ":00") do
          {:ok, naive} -> put_local(changeset, field, naive, time_zone, opts)
          {:error, _reason} -> add_error(changeset, field, "is invalid", validation: :cast)
        end
    end
  end

  defp put_datetime(changeset, field, _value, _time_zone, _opts),
    do: add_error(changeset, field, "is invalid", validation: :cast)

  defp put_local(changeset, field, naive, time_zone, opts) do
    case DateTime.from_naive(naive, time_zone) do
      {:ok, instant} ->
        put_cast(changeset, field, instant, time_zone)

      {:ambiguous, first, second} ->
        case Keyword.get(opts, :ambiguous, :earlier) do
          :earlier -> put_cast(changeset, field, first, time_zone)
          :later -> put_cast(changeset, field, second, time_zone)
          :error -> add(changeset, field, {:ambiguous, time_zone: time_zone}, opts)
        end

      {:gap, _before, _after} ->
        add(changeset, field, {:gap, time_zone: time_zone}, opts)

      {:error, reason} ->
        raise ArgumentError, "Koyomi.Changeset.cast_datetime/5: #{time_zone}: #{inspect(reason)}"
    end
  end

  # The field's own type decides: :utc_datetime keeps the instant in UTC,
  # :naive_datetime keeps the wall clock of the zone.
  defp put_cast(changeset, field, %DateTime{} = instant, time_zone) do
    utc = DateTime.shift_zone!(instant, "Etc/UTC")

    case changeset.types[field] do
      type when type in [:naive_datetime, :naive_datetime_usec] ->
        local = DateTime.shift_zone!(instant, time_zone)
        put_change(changeset, field, cast_type(type, DateTime.to_naive(local)))

      type when type in [:utc_datetime, :utc_datetime_usec] ->
        put_change(changeset, field, cast_type(type, utc))

      _other ->
        put_change(changeset, field, utc)
    end
  end

  defp cast_type(type, value) do
    {:ok, cast} = Ecto.Type.cast(type, value)
    cast
  end

  defp validate(changeset, field, opts, check) do
    if Keyword.has_key?(changeset.errors, field) do
      changeset
    else
      case check.(get_field(changeset, field)) do
        :ok -> changeset
        {:error, error} -> add(changeset, field, error, opts)
      end
    end
  end

  defp add(changeset, field, {kind, keys}, opts) do
    keys = with_count(kind, keys)

    add_error(changeset, field, message(kind, Keyword.get(opts, :message)), [
      {:validation, :koyomi},
      {:kind, kind} | keys
    ])
  end

  defp with_count(kind, keys) do
    count =
      case kind do
        :too_short -> keys[:min_days]
        :too_long -> keys[:max_days]
        :too_few -> keys[:min_count]
        :too_many -> keys[:max_count]
        :time_step -> keys[:step]
        _other -> nil
      end

    if count, do: [{:count, count} | keys], else: keys
  end

  defp message(kind, nil), do: Map.fetch!(@messages, kind)
  defp message(_kind, message) when is_binary(message), do: message
  defp message(kind, %{} = messages), do: Map.get(messages, kind) || Map.fetch!(@messages, kind)
end
