defmodule Koyomi.Holidays.FI do
  @moduledoc """
  The public holidays of Finland, in Finnish, the language of most Finns
  (Swedish is official too).

  Midsummer Eve and Christmas Eve are days off by custom, not public
  holidays, and are not listed.
  """
  use Koyomi.Holidays.Country, code: "FI", language: "fi"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Uudenvuodenpäivä", "New Year's Day"},
      {date(year, 1, 6), "Loppiainen", "Epiphany"},
      {Date.add(easter, -2), "Pitkäperjantai", "Good Friday"},
      {easter, "Pääsiäispäivä", "Easter Sunday"},
      {Date.add(easter, 1), "2. pääsiäispäivä", "Easter Monday"},
      {date(year, 5, 1), "Vappu", "May Day"},
      {Date.add(easter, 39), "Helatorstai", "Ascension Day"},
      {Date.add(easter, 49), "Helluntaipäivä", "Whit Sunday"},
      {on_or_after(date(year, 6, 20), 6), "Juhannuspäivä", "Midsummer Day"},
      {on_or_after(date(year, 10, 31), 6), "Pyhäinpäivä", "All Saints' Day"},
      {date(year, 12, 6), "Itsenäisyyspäivä", "Independence Day"},
      {date(year, 12, 25), "Joulupäivä", "Christmas Day"},
      {date(year, 12, 26), "Tapaninpäivä", "Saint Stephen's Day"}
    ]
  end
end
