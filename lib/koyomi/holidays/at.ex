defmodule Koyomi.Holidays.AT do
  @moduledoc """
  The public holidays of Austria (Feiertagsruhegesetz and
  Arbeitsruhegesetz), in German.
  """
  use Koyomi.Holidays.Country, code: "AT", language: "de"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Neujahr", "New Year's Day"},
      {date(year, 1, 6), "Heilige Drei Könige", "Epiphany"},
      {easter, "Ostersonntag", "Easter Sunday"},
      {Date.add(easter, 1), "Ostermontag", "Easter Monday"},
      {date(year, 5, 1), "Staatsfeiertag", "Labour Day"},
      {Date.add(easter, 39), "Christi Himmelfahrt", "Ascension Day"},
      {Date.add(easter, 49), "Pfingstsonntag", "Whit Sunday"},
      {Date.add(easter, 50), "Pfingstmontag", "Whit Monday"},
      {Date.add(easter, 60), "Fronleichnam", "Corpus Christi"},
      {date(year, 8, 15), "Mariä Himmelfahrt", "Assumption Day"},
      {date(year, 10, 26), "Nationalfeiertag", "Austrian National Day"},
      {date(year, 11, 1), "Allerheiligen", "All Saints' Day"},
      {date(year, 12, 8), "Mariä Empfängnis", "Immaculate Conception"},
      {date(year, 12, 25), "Christtag", "Christmas Day"},
      {date(year, 12, 26), "Stefanitag", "Saint Stephen's Day"}
    ]
  end
end
