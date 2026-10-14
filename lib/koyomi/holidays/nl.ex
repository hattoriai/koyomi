defmodule Koyomi.Holidays.NL do
  @moduledoc """
  The national holidays of the Netherlands, in Dutch.

  King's Day is April 27, or April 26 when the 27th is a Sunday, and is
  listed from 2014 (Queen's Day, before it, is not). Liberation Day is
  listed every year, though many employers give the day off only every
  fifth year. Good Friday is not listed.
  """
  use Koyomi.Holidays.Country, code: "NL", language: "nl"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Nieuwjaarsdag", "New Year's Day"},
      {easter, "Eerste Paasdag", "Easter Sunday"},
      {Date.add(easter, 1), "Tweede Paasdag", "Easter Monday"},
      if(year >= 2014, do: {kings_day(year), "Koningsdag", "King's Day"}),
      {date(year, 5, 5), "Bevrijdingsdag", "Liberation Day"},
      {Date.add(easter, 39), "Hemelvaartsdag", "Ascension Day"},
      {Date.add(easter, 49), "Eerste Pinksterdag", "Whit Sunday"},
      {Date.add(easter, 50), "Tweede Pinksterdag", "Whit Monday"},
      {date(year, 12, 25), "Eerste Kerstdag", "Christmas Day"},
      {date(year, 12, 26), "Tweede Kerstdag", "Second Day of Christmas"}
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp kings_day(year) do
    day = date(year, 4, 27)
    if Date.day_of_week(day) == 7, do: Date.add(day, -1), else: day
  end
end
