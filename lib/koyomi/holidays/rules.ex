defmodule Koyomi.Holidays.Rules do
  @moduledoc """
  Date rules for holidays: Easter, the nth weekday of a month, and the
  days that replace a holiday on a weekend. The built-in countries use
  them, and a `Koyomi.Holidays.Provider` can too.

  Weekdays are numbered as in `Date.day_of_week/1`: 1 is Monday and 7 is
  Sunday.
  """

  @type weekday :: 1..7

  @doc """
  Returns Easter Sunday of `year` in the Gregorian calendar (the
  Western churches' date), by the anonymous Gregorian computus.

  ## Examples

      iex> Koyomi.Holidays.Rules.easter(2025)
      ~D[2025-04-20]

  """
  @spec easter(integer()) :: Date.t()
  def easter(year) do
    a = rem(year, 19)
    b = div(year, 100)
    c = rem(year, 100)
    d = div(b, 4)
    e = rem(b, 4)
    f = div(b + 8, 25)
    g = div(b - f + 1, 3)
    h = rem(19 * a + b - d - g + 15, 30)
    i = div(c, 4)
    k = rem(c, 4)
    l = rem(32 + 2 * e + 2 * i - h - k, 7)
    m = div(a + 11 * h + 22 * l, 451)
    n = h + l - 7 * m + 114
    Date.new!(year, div(n, 31), rem(n, 31) + 1)
  end

  @doc """
  Returns the `n`th `weekday` of a month, or the last one when `n` is
  `:last`.

  ## Examples

      iex> Koyomi.Holidays.Rules.nth_weekday(2027, 11, 4, 4)
      ~D[2027-11-25]

      iex> Koyomi.Holidays.Rules.nth_weekday(2027, 5, 1, :last)
      ~D[2027-05-31]

  """
  @spec nth_weekday(integer(), 1..12, weekday(), pos_integer() | :last) :: Date.t()
  def nth_weekday(year, month, weekday, :last) do
    year |> Date.new!(month, 1) |> Date.end_of_month() |> on_or_before(weekday)
  end

  def nth_weekday(year, month, weekday, n) when is_integer(n) and n > 0 do
    year |> Date.new!(month, 1) |> on_or_after(weekday) |> Date.add(7 * (n - 1))
  end

  @doc """
  Returns the first `weekday` on or after `date`.

  ## Examples

      iex> Koyomi.Holidays.Rules.on_or_after(~D[2027-06-20], 6)
      ~D[2027-06-26]

  """
  @spec on_or_after(Date.t(), weekday()) :: Date.t()
  def on_or_after(date, weekday) do
    Date.add(date, rem(weekday - Date.day_of_week(date) + 7, 7))
  end

  @doc """
  Returns the last `weekday` on or before `date`.

  ## Examples

      iex> Koyomi.Holidays.Rules.on_or_before(~D[2027-05-24], 1)
      ~D[2027-05-24]

  """
  @spec on_or_before(Date.t(), weekday()) :: Date.t()
  def on_or_before(date, weekday) do
    Date.add(date, -rem(Date.day_of_week(date) - weekday + 7, 7))
  end

  @doc """
  Returns `true` when `date` is a Saturday or a Sunday.
  """
  @spec weekend?(Date.t()) :: boolean()
  def weekend?(date), do: Date.day_of_week(date) >= 6

  @doc """
  Returns the days that replace holidays on a weekend, as
  `{day, holiday}` pairs.

  Each holiday of `eligible` on a Saturday or a Sunday, in date order, is
  replaced by the next weekday that is neither a holiday of `holidays`
  nor a day already given to another holiday. This is the British rule
  for substitute days: with Christmas Day on a Saturday and Boxing Day on
  the Sunday, the days off are Monday 27 and Tuesday 28 December.

  ## Examples

      iex> christmas = {~D[2027-12-25], "Christmas Day", "Christmas Day"}
      iex> boxing = {~D[2027-12-26], "Boxing Day", "Boxing Day"}
      iex> Koyomi.Holidays.Rules.substitute_days([christmas, boxing], [christmas, boxing])
      [{~D[2027-12-27], christmas}, {~D[2027-12-28], boxing}]

  """
  @spec substitute_days([Koyomi.Holidays.Provider.entry()], [Koyomi.Holidays.Provider.entry()]) ::
          [{Date.t(), Koyomi.Holidays.Provider.entry()}]
  def substitute_days(holidays, eligible) do
    taken = MapSet.new(holidays, &elem(&1, 0))

    eligible
    |> Enum.filter(&weekend?(elem(&1, 0)))
    |> Enum.sort_by(&elem(&1, 0), Date)
    |> Enum.map_reduce(taken, fn {date, _name, _english} = holiday, taken ->
      day = next_free_weekday(Date.add(date, 1), taken)
      {{day, holiday}, MapSet.put(taken, day)}
    end)
    |> elem(0)
  end

  defp next_free_weekday(date, taken) do
    if weekend?(date) or MapSet.member?(taken, date),
      do: next_free_weekday(Date.add(date, 1), taken),
      else: date
  end
end
