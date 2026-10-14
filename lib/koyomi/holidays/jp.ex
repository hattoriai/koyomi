defmodule Koyomi.Holidays.JP do
  @moduledoc """
  The national holidays of Japan (国民の祝日に関する法律), in Japanese.

  Also listed, as the law makes them holidays:

    * 振替休日 (substitute holiday): when a holiday falls on a Sunday, the
      next day that is not a holiday.
    * 国民の休日 (citizens' holiday): a day between two holidays, such as
      the Tuesday between Respect for the Aged Day and the Autumnal
      Equinox Day in 2026.

  The equinox days are set each year by the Cabinet from astronomical
  tables. They are computed here by the usual approximation, which gives
  the announced dates for 1980 to 2099; outside those years they are not
  listed. The Emperor's Birthday is December 23 up to 2018 and February
  23 from 2020; Mountain Day is listed from 2016. One-off holidays and
  moves (the 2019 enthronement, the 2020 and 2021 Olympic games) are not
  listed.
  """
  use Koyomi.Holidays.Country, code: "JP", language: "ja"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    national = national(year)
    holidays = MapSet.new(national, &elem(&1, 0))

    substitutes =
      for {date, _, _} <- national, Date.day_of_week(date) == 7 do
        {next_working(Date.add(date, 1), holidays), "振替休日", "Substitute Holiday"}
      end

    taken = MapSet.union(holidays, MapSet.new(substitutes, &elem(&1, 0)))

    citizens =
      for {date, _, _} <- national,
          day = Date.add(date, 1),
          day.year == year,
          not MapSet.member?(taken, day),
          MapSet.member?(holidays, Date.add(day, 1)),
          uniq: true,
          do: {day, "国民の休日", "Citizens' Holiday"}

    national ++ substitutes ++ citizens
  end

  defp national(year) do
    [
      {date(year, 1, 1), "元日", "New Year's Day"},
      {nth_weekday(year, 1, 1, 2), "成人の日", "Coming of Age Day"},
      {date(year, 2, 11), "建国記念の日", "National Foundation Day"},
      if(year >= 2020, do: {date(year, 2, 23), "天皇誕生日", "The Emperor's Birthday"}),
      equinox(year, 3, 20.8431, "春分の日", "Vernal Equinox Day"),
      {date(year, 4, 29), "昭和の日", "Shōwa Day"},
      {date(year, 5, 3), "憲法記念日", "Constitution Memorial Day"},
      {date(year, 5, 4), "みどりの日", "Greenery Day"},
      {date(year, 5, 5), "こどもの日", "Children's Day"},
      {nth_weekday(year, 7, 1, 3), "海の日", "Marine Day"},
      if(year >= 2016, do: {date(year, 8, 11), "山の日", "Mountain Day"}),
      {nth_weekday(year, 9, 1, 3), "敬老の日", "Respect for the Aged Day"},
      equinox(year, 9, 23.2488, "秋分の日", "Autumnal Equinox Day"),
      {nth_weekday(year, 10, 1, 2), "スポーツの日", "Sports Day"},
      {date(year, 11, 3), "文化の日", "Culture Day"},
      {date(year, 11, 23), "勤労感謝の日", "Labour Thanksgiving Day"},
      if(year <= 2018, do: {date(year, 12, 23), "天皇誕生日", "The Emperor's Birthday"})
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&elem(&1, 0), Date)
  end

  # The day of the equinox in March or September: the integer part of
  # base + 0.242194 × (year − 1980) − ⌊(year − 1980) / 4⌋.
  defp equinox(year, month, base, name, english) when year in 1980..2099 do
    day = trunc(base + 0.242194 * (year - 1980) - div(year - 1980, 4))
    {date(year, month, day), name, english}
  end

  defp equinox(_year, _month, _base, _name, _english), do: nil

  defp next_working(date, holidays) do
    if MapSet.member?(holidays, date), do: next_working(Date.add(date, 1), holidays), else: date
  end
end
