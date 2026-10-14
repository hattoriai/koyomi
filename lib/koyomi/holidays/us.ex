defmodule Koyomi.Holidays.US do
  @moduledoc """
  The federal holidays of the United States (5 U.S.C. 6103), in English.

  A holiday on a Saturday is observed on the Friday before, and one on a
  Sunday on the Monday after. The holiday stays on its date, and an entry
  "<name> (observed)" marks the day off. When New Year's Day is a
  Saturday, it is observed on December 31 of the year before, which is in
  that year's list. Juneteenth is listed from 2021. Inauguration Day (a
  holiday around Washington only) is not listed.
  """
  use Koyomi.Holidays.Country, code: "US", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    observed =
      for {date, name, _} <- fixed(year) ++ fixed(year + 1),
          day = observed_day(date),
          day != date and day.year == year,
          do: {day, name <> " (observed)", name <> " (observed)"}

    movable = [
      {nth_weekday(year, 1, 1, 3), "Birthday of Martin Luther King, Jr."},
      {nth_weekday(year, 2, 1, 3), "Washington's Birthday"},
      {nth_weekday(year, 5, 1, :last), "Memorial Day"},
      {nth_weekday(year, 9, 1, 1), "Labor Day"},
      {nth_weekday(year, 10, 1, 2), "Columbus Day"},
      {nth_weekday(year, 11, 4, 4), "Thanksgiving Day"}
    ]

    fixed(year) ++ Enum.map(movable, fn {date, name} -> {date, name, name} end) ++ observed
  end

  defp fixed(year) do
    [
      {date(year, 1, 1), "New Year's Day"},
      if(year >= 2021, do: {date(year, 6, 19), "Juneteenth National Independence Day"}),
      {date(year, 7, 4), "Independence Day"},
      {date(year, 11, 11), "Veterans Day"},
      {date(year, 12, 25), "Christmas Day"}
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {date, name} -> {date, name, name} end)
  end

  defp observed_day(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, -1)
      7 -> Date.add(date, 1)
      _ -> date
    end
  end
end
