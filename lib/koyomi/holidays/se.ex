defmodule Koyomi.Holidays.SE do
  @moduledoc """
  The public holidays of Sweden (allmänna helgdagar), in Swedish.

  Midsummer Eve, Christmas Eve and New Year's Eve are days off by custom,
  not public holidays, and are not listed. The National Day is listed
  from 2005.
  """
  use Koyomi.Holidays.Country, code: "SE", language: "sv"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Nyårsdagen", "New Year's Day"},
      {date(year, 1, 6), "Trettondedag jul", "Epiphany"},
      {Date.add(easter, -2), "Långfredagen", "Good Friday"},
      {easter, "Påskdagen", "Easter Sunday"},
      {Date.add(easter, 1), "Annandag påsk", "Easter Monday"},
      {date(year, 5, 1), "Första maj", "May Day"},
      {Date.add(easter, 39), "Kristi himmelsfärds dag", "Ascension Day"},
      {Date.add(easter, 49), "Pingstdagen", "Whit Sunday"},
      if(year >= 2005, do: {date(year, 6, 6), "Sveriges nationaldag", "National Day of Sweden"}),
      {on_or_after(date(year, 6, 20), 6), "Midsommardagen", "Midsummer Day"},
      {on_or_after(date(year, 10, 31), 6), "Alla helgons dag", "All Saints' Day"},
      {date(year, 12, 25), "Juldagen", "Christmas Day"},
      {date(year, 12, 26), "Annandag jul", "Second Day of Christmas"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
