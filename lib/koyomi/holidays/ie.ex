defmodule Koyomi.Holidays.IE do
  @moduledoc """
  The public holidays of Ireland (Organisation of Working Time Act 1997),
  in English, the language most people use for them.

  Saint Brigid's Day is the first Monday of February, or February 1 when
  that is a Friday, from 2023. Good Friday is not a public holiday. A
  holiday on a weekend gives employees another day off, which is not a
  fixed date, so no day is added.
  """
  use Koyomi.Holidays.Country, code: "IE", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 1), "New Year's Day"},
      if(year >= 2023, do: {brigid(year), "Saint Brigid's Day"}),
      {date(year, 3, 17), "Saint Patrick's Day"},
      {Date.add(easter(year), 1), "Easter Monday"},
      {nth_weekday(year, 5, 1, 1), "May Bank Holiday"},
      {nth_weekday(year, 6, 1, 1), "June Bank Holiday"},
      {nth_weekday(year, 8, 1, 1), "August Bank Holiday"},
      {nth_weekday(year, 10, 1, :last), "October Bank Holiday"},
      {date(year, 12, 25), "Christmas Day"},
      {date(year, 12, 26), "Saint Stephen's Day"}
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {date, name} -> {date, name, name} end)
  end

  defp brigid(year) do
    first = date(year, 2, 1)
    if Date.day_of_week(first) == 5, do: first, else: on_or_after(first, 1)
  end
end
