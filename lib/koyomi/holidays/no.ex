defmodule Koyomi.Holidays.NO do
  @moduledoc """
  The public holidays of Norway (helligdager and offentlige høytidsdager),
  in Norwegian Bokmål.
  """
  use Koyomi.Holidays.Country, code: "NO", language: "nb"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Første nyttårsdag", "New Year's Day"},
      {Date.add(easter, -3), "Skjærtorsdag", "Maundy Thursday"},
      {Date.add(easter, -2), "Langfredag", "Good Friday"},
      {easter, "Første påskedag", "Easter Sunday"},
      {Date.add(easter, 1), "Andre påskedag", "Easter Monday"},
      {date(year, 5, 1), "Arbeidernes dag", "Labour Day"},
      {date(year, 5, 17), "Grunnlovsdag", "Constitution Day"},
      {Date.add(easter, 39), "Kristi himmelfartsdag", "Ascension Day"},
      {Date.add(easter, 49), "Første pinsedag", "Whit Sunday"},
      {Date.add(easter, 50), "Andre pinsedag", "Whit Monday"},
      {date(year, 12, 25), "Første juledag", "Christmas Day"},
      {date(year, 12, 26), "Andre juledag", "Second Day of Christmas"}
    ]
  end
end
