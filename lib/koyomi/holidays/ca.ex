defmodule Koyomi.Holidays.CA do
  @moduledoc """
  The general holidays of Canada's federal jurisdiction (Canada Labour
  Code), in English: the national choice, since each province keeps its
  own list.

  When July 1 is a Sunday, July 2 is Canada Day (Holidays Act): the entry
  "Canada Day (observed)" marks it. Other holidays on a weekend are left
  to employers and provinces, and are not moved. The National Day for
  Truth and Reconciliation is listed from 2021.
  """
  use Koyomi.Holidays.Country, code: "CA", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    canada_day = date(year, 7, 1)

    [
      {date(year, 1, 1), "New Year's Day"},
      {Date.add(easter(year), -2), "Good Friday"},
      {on_or_before(date(year, 5, 24), 1), "Victoria Day"},
      {canada_day, "Canada Day"},
      if(Date.day_of_week(canada_day) == 7, do: {date(year, 7, 2), "Canada Day (observed)"}),
      {nth_weekday(year, 9, 1, 1), "Labour Day"},
      if(year >= 2021, do: {date(year, 9, 30), "National Day for Truth and Reconciliation"}),
      {nth_weekday(year, 10, 1, 2), "Thanksgiving"},
      {date(year, 11, 11), "Remembrance Day"},
      {date(year, 12, 25), "Christmas Day"},
      {date(year, 12, 26), "Boxing Day"}
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {date, name} -> {date, name, name} end)
  end
end
