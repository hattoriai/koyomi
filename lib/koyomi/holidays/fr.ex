defmodule Koyomi.Holidays.FR do
  @moduledoc """
  The public holidays of metropolitan France (Code du travail, article
  L3133-1), in French.

  Good Friday and December 26, kept in Alsace and Moselle only, and the
  days of abolition of slavery of the overseas departments, are not
  listed.
  """
  use Koyomi.Holidays.Country, code: "FR", language: "fr"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Jour de l’an", "New Year's Day"},
      {Date.add(easter, 1), "Lundi de Pâques", "Easter Monday"},
      {date(year, 5, 1), "Fête du Travail", "Labour Day"},
      {date(year, 5, 8), "Victoire 1945", "Victory in Europe Day"},
      {Date.add(easter, 39), "Ascension", "Ascension Day"},
      {Date.add(easter, 50), "Lundi de Pentecôte", "Whit Monday"},
      {date(year, 7, 14), "Fête nationale", "Bastille Day"},
      {date(year, 8, 15), "Assomption", "Assumption Day"},
      {date(year, 11, 1), "Toussaint", "All Saints' Day"},
      {date(year, 11, 11), "Armistice 1918", "Armistice Day"},
      {date(year, 12, 25), "Noël", "Christmas Day"}
    ]
  end
end
