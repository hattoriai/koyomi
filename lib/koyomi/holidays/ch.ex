defmodule Koyomi.Holidays.CH do
  @moduledoc """
  The holidays of Switzerland kept in every canton, in German, the
  language of most Swiss (French, Italian and Romansh are official too).

  The Swiss National Day (August 1) is the only federal holiday; the
  cantons set the others. Listed are the four that every canton keeps:
  New Year's Day, Ascension Day, the National Day and Christmas Day.
  Good Friday, Easter Monday, Whit Monday and December 26, kept in most
  cantons but not all, are not listed.
  """
  use Koyomi.Holidays.Country, code: "CH", language: "de"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 1), "Neujahr", "New Year's Day"},
      {Date.add(easter(year), 39), "Auffahrt", "Ascension Day"},
      {date(year, 8, 1), "Bundesfeiertag", "Swiss National Day"},
      {date(year, 12, 25), "Weihnachten", "Christmas Day"}
    ]
  end
end
