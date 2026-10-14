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
  """

  @type unit :: :day | :week | :month | :quarter | :year
  @type preset ::
          atom()
          | {:in | :ago, pos_integer(), atom()}
          | {:last | :next, pos_integer(), :days}
          | {String.t(), Date.t() | Date.Range.t() | (Date.t() -> Date.t() | Date.Range.t())}

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
  label).

  `first_day` is the first day of the week (ISO, 1 is Monday), for the
  week presets.

  ## Examples

      iex> Koyomi.Presets.resolve([:tomorrow], :date, ~D[2027-03-15])
      [%{"id" => "tomorrow", "value" => "2027-03-16", "relative" => %{"n" => 1, "unit" => "day"}}]

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
    |> Enum.map(fn {preset, index} -> one(preset, today, first_day, index) end)
    |> Enum.map(&fit(&1, kind))
    |> Enum.reject(&is_nil/1)
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
