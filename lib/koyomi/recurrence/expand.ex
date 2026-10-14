defmodule Koyomi.Recurrence.Expand do
  @moduledoc false

  # The occurrences of a `Koyomi.Recurrence`, the same as `occurrences`
  # in `rrule.ts`. Days are Gregorian day numbers, as in `rrule.ts` they
  # are days since 1970, so the two walk the same periods.
  #
  # Each period (a day, a week, a month or a year, `interval` apart) gives
  # its candidate days: every day of the period that passes each `BY` part
  # and the defaults from the start. Filtering every day of the period is
  # the same as the RFC's expand and limit: a part that expands picks its
  # days from the period, a part that limits drops the others. BYSETPOS
  # then picks from the sorted candidates.

  alias Koyomi.Recurrence

  # The Gregorian calendar repeats every 400 years (146 097 days): a rule
  # with no occurrence in that long has none to come.
  @give_up 146_097
  @last_day Date.to_gregorian_days(~D[9999-12-31])

  @spec occurrences(Recurrence.t(), Date.t() | NaiveDateTime.t() | DateTime.t(), module()) ::
          Enumerable.t()
  def occurrences(%Recurrence{} = rule, start, database) do
    start_day = start |> day_of() |> Date.to_gregorian_days()
    rule = defaults(rule, Date.from_gregorian_days(start_day))

    days =
      Stream.concat(
        [start_day],
        Stream.resource(
          fn -> {0, start_day} end,
          &next_period(rule, start_day, &1),
          fn _state -> :ok end
        )
      )

    days
    |> Stream.map(&at(start, Date.from_gregorian_days(&1), database))
    |> until(rule.until)
    |> count(rule.count)
  end

  @doc false
  @spec day_of(Date.t() | NaiveDateTime.t() | DateTime.t()) :: Date.t()
  def day_of(%Date{} = date), do: date
  def day_of(%NaiveDateTime{} = naive), do: NaiveDateTime.to_date(naive)
  def day_of(%DateTime{} = datetime), do: DateTime.to_date(datetime)

  # The days of the next period after the start, and the state for the
  # one after it: the period's number and the last day found so far.
  defp next_period(_rule, _start_day, :halt), do: {:halt, :halt}

  defp next_period(rule, start_day, {k, last}) do
    case period(rule, start_day, k) do
      :halt ->
        {:halt, :halt}

      {first, days} ->
        days |> Enum.filter(&(&1 > start_day)) |> advance(first, k, last)
    end
  end

  defp advance([], first, _k, last) when first - last > @give_up, do: {:halt, :halt}
  defp advance([], _first, k, last), do: {[], {k + 1, last}}
  defp advance(days, _first, k, _last), do: {days, {k + 1, List.last(days)}}

  defp count(stream, nil), do: stream
  defp count(stream, count), do: Stream.take(stream, count)

  defp until(stream, nil), do: stream

  defp until(stream, %Date{} = until) do
    Stream.take_while(stream, &(Date.compare(day_of(&1), until) != :gt))
  end

  defp until(stream, %DateTime{} = until) do
    Stream.take_while(stream, fn
      %Date{} = date -> Date.compare(date, DateTime.to_date(until)) != :gt
      %NaiveDateTime{} = naive -> NaiveDateTime.compare(naive, DateTime.to_naive(until)) != :gt
      %DateTime{} = datetime -> DateTime.compare(datetime, until) != :gt
    end)
  end

  defp at(%Date{}, date, _database), do: date

  defp at(%NaiveDateTime{} = start, date, _database),
    do: NaiveDateTime.new!(date, NaiveDateTime.to_time(start))

  defp at(%DateTime{} = start, date, database) do
    time = DateTime.to_time(start)

    case DateTime.new(date, time, start.time_zone, database) do
      {:ok, datetime} ->
        datetime

      {:ambiguous, first, _second} ->
        first

      {:gap, before, after_gap} ->
        # The offset before the gap, applied to the wall clock time, lands
        # after it by the length of the gap (02:30 becomes 03:30).
        shift = offset(after_gap) - offset(before)
        naive = date |> NaiveDateTime.new!(time) |> NaiveDateTime.add(shift)
        DateTime.from_naive!(naive, start.time_zone, database)

      {:error, reason} ->
        raise ArgumentError, "cannot place #{date} in #{start.time_zone}: #{inspect(reason)}"
    end
  end

  defp offset(datetime), do: datetime.utc_offset + datetime.std_offset

  # The parts that the rule leaves out, from the start (RFC 5545, as
  # python-dateutil and libical read it).
  defp defaults(rule, start) do
    case rule do
      %{freq: :weekly, by_day: []} ->
        %{rule | by_day: [{nil, Date.day_of_week(start)}]}

      %{freq: :monthly, by_day: [], by_month_day: []} ->
        %{rule | by_month_day: [start.day]}

      %{freq: :yearly, by_day: [], by_month_day: [], by_month: []} ->
        %{rule | by_month_day: [start.day], by_month: [start.month]}

      %{freq: :yearly, by_day: [], by_month_day: []} ->
        %{rule | by_month_day: [start.day]}

      _rule ->
        rule
    end
  end

  # The first day of period `k` and its candidate days, or :halt past the
  # year 9999.
  defp period(rule, start_day, k) do
    {first, last} = bounds(rule, start_day, k * rule.interval)

    if first == :halt or first > @last_day do
      :halt
    else
      days =
        first..min(last, @last_day)//1
        |> Enum.filter(&matches?(rule, &1))
        |> set_positions(rule.by_set_pos)

      {first, days}
    end
  end

  # The first and last days of the period `step` periods after the start.
  defp bounds(%{freq: :daily}, start_day, step), do: {start_day + step, start_day + step}

  defp bounds(%{freq: :weekly} = rule, start_day, step) do
    start = Date.from_gregorian_days(start_day)
    week = start_day - Integer.mod(Date.day_of_week(start) - rule.week_start, 7) + 7 * step
    {week, week + 6}
  end

  defp bounds(%{freq: :monthly}, start_day, step) do
    start = Date.from_gregorian_days(start_day)
    index = start.year * 12 + start.month - 1 + step
    year = Integer.floor_div(index, 12)
    month = index - year * 12 + 1

    if year > 9999,
      do: {:halt, nil},
      else: month_bounds(year, month)
  end

  defp bounds(%{freq: :yearly}, start_day, step) do
    year = Date.from_gregorian_days(start_day).year + step
    if year > 9999, do: {:halt, nil}, else: {gregorian(year, 1, 1), gregorian(year, 12, 31)}
  end

  defp month_bounds(year, month) do
    {gregorian(year, month, 1),
     gregorian(year, month, Date.days_in_month(Date.new!(year, month, 1)))}
  end

  defp gregorian(year, month, day), do: Date.to_gregorian_days(Date.new!(year, month, day))

  defp matches?(rule, day) do
    date = Date.from_gregorian_days(day)
    days_in_month = Date.days_in_month(date)

    (rule.by_month == [] or date.month in rule.by_month) and
      (rule.by_month_day == [] or
         Enum.any?(rule.by_month_day, fn n ->
           if n > 0, do: date.day == n, else: date.day == days_in_month + n + 1
         end)) and
      (rule.by_day == [] or Enum.any?(rule.by_day, &weekday_matches?(rule, date, day, &1)))
  end

  defp weekday_matches?(_rule, date, _day, {nil, weekday}), do: Date.day_of_week(date) == weekday

  defp weekday_matches?(rule, date, day, {ordinal, weekday}) do
    if Date.day_of_week(date) == weekday do
      # An ordinal counts in the month for a monthly rule and for a
      # yearly rule with BYMONTH, in the year otherwise.
      {first, last} =
        if rule.freq == :monthly or rule.by_month != [],
          do: month_bounds(date.year, date.month),
          else: {gregorian(date.year, 1, 1), gregorian(date.year, 12, 31)}

      if ordinal > 0,
        do: div(day - first, 7) + 1 == ordinal,
        else: -(div(last - day, 7) + 1) == ordinal
    else
      false
    end
  end

  defp set_positions(days, []), do: days

  defp set_positions(days, positions) do
    size = length(days)

    positions
    |> Enum.map(fn n -> if n > 0, do: n - 1, else: size + n end)
    |> Enum.filter(&(&1 >= 0 and &1 < size))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&Enum.at(days, &1))
  end
end
