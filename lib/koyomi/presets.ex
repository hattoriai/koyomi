defmodule Koyomi.Presets do
  @moduledoc """
  Presets: the common choices beside the calendar, such as "Today",
  "Last 7 days" or "In a month".

      <.date_range_picker field={@form[:period]} presets={[:last_7_days, :this_month, :year_to_date]} />
      <.date_picker field={@form[:due]} presets={[:today, :tomorrow, {:in, 1, :week}, {:in, 1, :month}]} />

  The server computes each preset's value from today (in the picker's time
  zone), so a preset is the same day in the browser and on the server. A
  preset that the rules refuse is shown disabled.

  ## Presets

    * `:today`, `:tomorrow`, `:yesterday`
    * `{:in, n, unit}` and `{:ago, n, unit}`, with `unit` one of `:day`,
      `:week`, `:month`, `:year` (or their plurals)
    * `:this_week`, `:next_week`, `:last_week`, `:this_month`,
      `:next_month`, `:last_month`, `:this_quarter`, `:last_quarter`,
      `:this_year`, `:last_year` - ranges in a range picker, their first
      day in a date picker
    * `{:last, n, :days}` and `{:next, n, :days}` - the last `n` days up to
      today, and the next `n` days from today
    * `:month_to_date`, `:year_to_date`
    * `{label, value}` - the app's own: a label and a `Date`, a
      `Date.Range` or a function of today that returns one

  The browser labels the built-in presets in the picker's locale
  (`Intl.RelativeTimeFormat` and `Koyomi.Messages`): "Today", "Next week",
  "In 30 days", "Hoje", "La semaine prochaine".

  ## Keys, and presets that stay relative

  Each preset has a key: a built-in preset's own (`"today"`,
  `"last_7_days"`, `"this_month"`, `"in_1_week"`, `"month_to_date"`, see
  `key/1`), or the one an entry of a keyword list gives it:

      presets={[recent: {:last, 7, :days}, mtd: :month_to_date, :this_year]}

  A picker with `relative` posts the key of the preset a person chose,
  instead of today's dates (see the [Filters and URLs](filters.md)
  guide), and shows a key it is given as that preset. `to_date/2` and
  `to_range/2` turn a key back into the dates it covers on a day.
  """

  @type unit :: :day | :week | :month | :quarter | :year
  @type preset ::
          atom()
          | {:in | :ago, pos_integer(), atom()}
          | {:last | :next, pos_integer(), :days}
          | {String.t(), Date.t() | Date.Range.t() | (Date.t() -> Date.t() | Date.Range.t())}

  @typedoc "A preset of a picker's `presets`: a preset, or a key and a preset."
  @type entry :: preset() | {atom(), preset()}

  @units %{
    day: "day",
    days: "day",
    week: "week",
    weeks: "week",
    month: "month",
    months: "month",
    year: "year",
    years: "year"
  }

  @periods %{
    this_week: {:week, 0},
    next_week: {:week, 1},
    last_week: {:week, -1},
    this_month: {:month, 0},
    next_month: {:month, 1},
    last_month: {:month, -1},
    this_quarter: {:quarter, 0},
    last_quarter: {:quarter, -1},
    this_year: {:year, 0},
    last_year: {:year, -1}
  }

  @doc """
  Resolves presets for a picker kind (`:date`, `:range`, `:dates`,
  `:datetime`) and today, into the list that the browser reads: maps with
  `"value"` (an ISO date, or `%{"from", "to"}` for a range), and
  `"label"` (the app's) or `"relative"` / `"message"` (for the browser to
  label), and `"key"`, the preset's key.

  `first_day` is the first day of the week (ISO, 1 is Monday), for the
  week presets.

  ## Examples

      iex> Koyomi.Presets.resolve([:tomorrow], :date, ~D[2027-03-15])
      [%{"id" => "tomorrow", "key" => "tomorrow", "value" => "2027-03-16", "relative" => %{"n" => 1, "unit" => "day"}}]

      iex> [preset] = Koyomi.Presets.resolve([{:last, 7, :days}], :range, ~D[2027-03-15])
      iex> preset["value"]
      %{"from" => "2027-03-09", "to" => "2027-03-15"}

  """
  @spec resolve([preset()] | nil, atom(), Date.t(), 1..7) :: [map()]
  def resolve(presets, kind, today, first_day \\ 1)
  def resolve(nil, _kind, _today, _first_day), do: []

  def resolve(presets, kind, %Date{} = today, first_day) when is_list(presets) do
    presets
    |> Enum.with_index()
    |> Enum.map(fn {entry, index} ->
      {key, preset} = split(entry)
      preset |> one(today, first_day, index) |> put_key(key || key(preset))
    end)
    |> Enum.map(&fit(&1, kind))
    |> Enum.reject(&is_nil/1)
  end

  # A keyword entry names its preset; the app's own presets ({label, value})
  # have a binary first element, the built-in ones no 2-tuple with an atom.
  defp split({key, preset}) when is_atom(key) and not is_nil(key) and not is_boolean(key),
    do: {Atom.to_string(key), preset}

  defp split(preset), do: {nil, preset}

  defp put_key(map, nil), do: map
  defp put_key(map, key), do: Map.put(map, "key", key)

  @doc """
  The key of a built-in preset, or `nil` for an app's own `{label, value}`
  (which a keyword list names).

  ## Examples

      iex> Koyomi.Presets.key({:last, 7, :days})
      "last_7_days"

      iex> Koyomi.Presets.key({:in, 2, :weeks})
      "in_2_week"

      iex> Koyomi.Presets.key(:this_quarter)
      "this_quarter"

  """
  @spec key(preset()) :: String.t() | nil
  def key(preset) when preset in [:today, :tomorrow, :yesterday, :month_to_date, :year_to_date],
    do: Atom.to_string(preset)

  def key(preset) when is_map_key(@periods, preset), do: Atom.to_string(preset)

  def key({direction, n, unit}) when direction in [:in, :ago] and is_integer(n) and n > 0,
    do: "#{direction}_#{n}_#{unit(unit)}"

  def key({direction, n, :days}) when direction in [:last, :next] and is_integer(n) and n > 0,
    do: "#{direction}_#{n}_days"

  def key(_preset), do: nil

  @doc """
  The preset of a built-in key (`"last_7_days"`, `"this_month"`,
  `"in_1_week"`), or `:error`. Hyphens work as underscores, and the units
  as their plurals.

  ## Examples

      iex> Koyomi.Presets.parse("last_30_days")
      {:ok, {:last, 30, :days}}

      iex> Koyomi.Presets.parse("next-week")
      {:ok, :next_week}

      iex> Koyomi.Presets.parse("soon")
      :error

  """
  @spec parse(String.t() | atom()) :: {:ok, preset()} | :error
  def parse(key) when is_atom(key) and not is_nil(key), do: parse(Atom.to_string(key))

  def parse(key) when is_binary(key) do
    key = key |> String.trim() |> String.downcase() |> String.replace("-", "_")

    case String.split(key, "_") do
      [direction, n, unit] when direction in ["in", "ago"] ->
        with {:ok, n} <- count(n),
             {:ok, unit} <- unit_atom(unit),
             do: {:ok, {direction(direction), n, unit}}

      [direction, n, days] when direction in ["last", "next"] and days in ["day", "days"] ->
        with {:ok, n} <- count(n), do: {:ok, {direction(direction), n, :days}}

      _other ->
        named(key)
    end
  end

  def parse(_key), do: :error

  @named Enum.map(
           [:today, :tomorrow, :yesterday, :month_to_date, :year_to_date] ++ Map.keys(@periods),
           &{Atom.to_string(&1), &1}
         )
         |> Map.new()

  defp named(key) do
    case Map.fetch(@named, key) do
      {:ok, preset} -> {:ok, preset}
      :error -> :error
    end
  end

  defp direction("in"), do: :in
  defp direction("ago"), do: :ago
  defp direction("last"), do: :last
  defp direction("next"), do: :next

  defp count(text) do
    case Integer.parse(text) do
      {n, ""} when n > 0 -> {:ok, n}
      _other -> :error
    end
  end

  defp unit_atom(text) do
    case Enum.find(@units, fn {atom, _unit} -> Atom.to_string(atom) == text end) do
      {atom, _unit} -> {:ok, atom}
      nil -> :error
    end
  end

  @doc """
  The day of a preset, or of its key, on `today`: a range preset gives its
  first day, as in a date picker. `:error` for a key that is not a
  built-in one.

  Options: `:today` (the day the preset counts from; today in UTC by
  default), and `:first_day` (the first day of the week, ISO, for the week
  presets; Monday by default). Give a picker's `time_zone` as `:today`'s
  day there: `Koyomi.Rules.today/1` does it.

  ## Examples

      iex> Koyomi.Presets.to_date("yesterday", today: ~D[2027-03-15])
      {:ok, ~D[2027-03-14]}

      iex> Koyomi.Presets.to_date(:this_month, today: ~D[2027-03-15])
      {:ok, ~D[2027-03-01]}

  """
  @spec to_date(preset() | String.t(), keyword()) :: {:ok, Date.t()} | :error
  def to_date(preset_or_key, opts \\ []) do
    with {:ok, %{"value" => value}} <- value(preset_or_key, :date, opts),
         do: {:ok, Date.from_iso8601!(value)}
  end

  @doc """
  The range of a preset, or of its key, on `today`: a day preset gives a
  range of one day, as in a range picker. Options as in `to_date/2`.

  ## Examples

      iex> Koyomi.Presets.to_range("last_7_days", today: ~D[2027-03-15])
      {:ok, Date.range(~D[2027-03-09], ~D[2027-03-15])}

      iex> Koyomi.Presets.to_range(:last_week, today: ~D[2027-03-15], first_day: 7)
      {:ok, Date.range(~D[2027-03-07], ~D[2027-03-13])}

  """
  @spec to_range(preset() | String.t(), keyword()) :: {:ok, Date.Range.t()} | :error
  def to_range(preset_or_key, opts \\ []) do
    with {:ok, %{"value" => %{"from" => from, "to" => to}}} <- value(preset_or_key, :range, opts),
         do: {:ok, Date.range(Date.from_iso8601!(from), Date.from_iso8601!(to))}
  end

  defp value(key, kind, opts) when is_binary(key) do
    with {:ok, preset} <- parse(key), do: value(preset, kind, opts)
  end

  defp value(preset, kind, opts) do
    today = Keyword.get_lazy(opts, :today, &Date.utc_today/0)
    first_day = Keyword.get(opts, :first_day, 1)

    case resolve([preset], kind, today, first_day) do
      [resolved] -> {:ok, resolved}
      _other -> :error
    end
  rescue
    ArgumentError -> :error
  end

  defp one(:today, today, _first_day, _index),
    do: day("today", today, %{"n" => 0, "unit" => "day"})

  defp one(:tomorrow, today, _first_day, _index),
    do: day("tomorrow", Date.add(today, 1), %{"n" => 1, "unit" => "day"})

  defp one(:yesterday, today, _first_day, _index),
    do: day("yesterday", Date.add(today, -1), %{"n" => -1, "unit" => "day"})

  defp one({direction, n, unit}, today, _first_day, _index)
       when direction in [:in, :ago] and is_integer(n) and n > 0 do
    unit = unit(unit)
    n = if direction == :in, do: n, else: -n
    day("#{direction}-#{abs(n)}-#{unit}", shift(today, n, unit), %{"n" => n, "unit" => unit})
  end

  defp one({:last, n, :days}, today, _first_day, _index) when is_integer(n) and n > 0 do
    range("last-#{n}-days", Date.add(today, 1 - n), today, message: "lastDays", n: n)
  end

  defp one({:next, n, :days}, today, _first_day, _index) when is_integer(n) and n > 0 do
    range("next-#{n}-days", today, Date.add(today, n - 1), message: "nextDays", n: n)
  end

  defp one(:month_to_date, today, _first_day, _index),
    do: range("month-to-date", Date.beginning_of_month(today), today, message: "monthToDate")

  defp one(:year_to_date, today, _first_day, _index),
    do: range("year-to-date", %{today | month: 1, day: 1}, today, message: "yearToDate")

  defp one(name, today, first_day, _index) when is_map_key(@periods, name) do
    {unit, n} = Map.fetch!(@periods, name)
    {first, last} = period(unit, n, today, first_day)
    id = name |> Atom.to_string() |> String.replace("_", "-")
    range(id, first, last, relative: %{"n" => n, "unit" => Atom.to_string(unit)})
  end

  defp one({label, value}, today, _first_day, index) when is_binary(label) do
    value = if is_function(value, 1), do: value.(today), else: value

    case value do
      %Date{} = date ->
        %{"id" => "preset-#{index}", "label" => label, "value" => Date.to_iso8601(date)}

      %Date.Range{first: first, last: last} ->
        %{"id" => "preset-#{index}", "label" => label, "value" => range_value(first, last)}

      other ->
        raise ArgumentError,
              "Koyomi.Presets: the preset #{inspect(label)} must give a Date or a Date.Range, got: #{inspect(other)}"
    end
  end

  defp one(other, _today, _first_day, _index) do
    raise ArgumentError, "Koyomi.Presets: unknown preset #{inspect(other)}; see Koyomi.Presets"
  end

  defp day(id, date, relative),
    do: %{"id" => id, "value" => Date.to_iso8601(date), "relative" => relative}

  defp range(id, first, last, opts) do
    base = %{"id" => id, "value" => range_value(first, last)}

    cond do
      opts[:relative] -> Map.put(base, "relative", opts[:relative])
      opts[:n] -> Map.merge(base, %{"message" => opts[:message], "n" => opts[:n]})
      true -> Map.put(base, "message", opts[:message])
    end
  end

  defp range_value(first, last),
    do: %{"from" => Date.to_iso8601(first), "to" => Date.to_iso8601(last)}

  # A range preset in a date picker gives its first day; a day preset in a
  # range picker gives a range of one day.
  defp fit(%{"value" => %{"from" => from}} = preset, kind)
       when kind in [:date, :dates, :datetime],
       do: %{preset | "value" => from}

  defp fit(%{"value" => value} = preset, :range) when is_binary(value),
    do: %{preset | "value" => %{"from" => value, "to" => value}}

  defp fit(preset, kind) when kind in [:date, :dates, :datetime, :range], do: preset
  defp fit(_preset, _kind), do: nil

  defp unit(unit) do
    Map.get(@units, unit) ||
      raise ArgumentError,
            "Koyomi.Presets: unknown unit #{inspect(unit)}; use :day, :week, :month or :year"
  end

  defp shift(date, n, "day"), do: Date.add(date, n)
  defp shift(date, n, "week"), do: Date.add(date, 7 * n)
  defp shift(date, n, "month"), do: Date.shift(date, month: n)
  defp shift(date, n, "year"), do: Date.shift(date, year: n)

  defp period(:week, n, today, first_day) do
    start = Date.add(today, -rem(Date.day_of_week(today) - first_day + 7, 7) + 7 * n)
    {start, Date.add(start, 6)}
  end

  defp period(:month, n, today, _first_day) do
    first = today |> Date.beginning_of_month() |> Date.shift(month: n)
    {first, Date.end_of_month(first)}
  end

  defp period(:quarter, n, today, _first_day) do
    month = today.month - rem(today.month - 1, 3)
    first = Date.shift(%{today | month: month, day: 1}, month: 3 * n)
    {first, first |> Date.shift(month: 2) |> Date.end_of_month()}
  end

  defp period(:year, n, today, _first_day) do
    year = today.year + n
    {Date.new!(year, 1, 1), Date.new!(year, 12, 31)}
  end
end
