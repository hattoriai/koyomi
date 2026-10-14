defmodule Koyomi.Holidays.DE do
  @moduledoc """
  The public holidays of Germany kept in every state, in German.

  The states add their own, such as Epiphany, Corpus Christi or
  Reformation Day; they are not listed.
  """
  use Koyomi.Holidays.Country, code: "DE", language: "de"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Neujahr", "New Year's Day"},
      {Date.add(easter, -2), "Karfreitag", "Good Friday"},
      {Date.add(easter, 1), "Ostermontag", "Easter Monday"},
      {date(year, 5, 1), "Tag der Arbeit", "Labour Day"},
      {Date.add(easter, 39), "Christi Himmelfahrt", "Ascension Day"},
      {Date.add(easter, 50), "Pfingstmontag", "Whit Monday"},
      {date(year, 10, 3), "Tag der Deutschen Einheit", "German Unity Day"},
      {date(year, 12, 25), "1. Weihnachtstag", "Christmas Day"},
      {date(year, 12, 26), "2. Weihnachtstag", "Second Day of Christmas"}
    ]
  end
end
