defmodule Koyomi.Holidays.BE do
  @moduledoc """
  The ten legal public holidays of Belgium, in Dutch, the language of
  most Belgians (French and German are official too).

  When a holiday falls on a Sunday, each employer sets another day off;
  no day is added.
  """
  use Koyomi.Holidays.Country, code: "BE", language: "nl"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Nieuwjaar", "New Year's Day"},
      {Date.add(easter, 1), "Paasmaandag", "Easter Monday"},
      {date(year, 5, 1), "Dag van de Arbeid", "Labour Day"},
      {Date.add(easter, 39), "Onze-Lieve-Heer-Hemelvaart", "Ascension Day"},
      {Date.add(easter, 50), "Pinkstermaandag", "Whit Monday"},
      {date(year, 7, 21), "Nationale feestdag", "Belgian National Day"},
      {date(year, 8, 15), "Onze-Lieve-Vrouw-Hemelvaart", "Assumption Day"},
      {date(year, 11, 1), "Allerheiligen", "All Saints' Day"},
      {date(year, 11, 11), "Wapenstilstand", "Armistice Day"},
      {date(year, 12, 25), "Kerstmis", "Christmas Day"}
    ]
  end
end
