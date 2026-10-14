defmodule Koyomi.Holidays.IT do
  @moduledoc """
  The national holidays of Italy, in Italian.

  The feast of Saint Francis of Assisi (October 4) is listed from 2026.
  The patron saints' days of each town are not listed.
  """
  use Koyomi.Holidays.Country, code: "IT", language: "it"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Capodanno", "New Year's Day"},
      {date(year, 1, 6), "Epifania", "Epiphany"},
      {easter, "Pasqua", "Easter Sunday"},
      {Date.add(easter, 1), "Lunedì dell’Angelo", "Easter Monday"},
      {date(year, 4, 25), "Festa della Liberazione", "Liberation Day"},
      {date(year, 5, 1), "Festa del Lavoro", "Labour Day"},
      {date(year, 6, 2), "Festa della Repubblica", "Republic Day"},
      {date(year, 8, 15), "Ferragosto", "Assumption Day"},
      if(year >= 2026,
        do: {date(year, 10, 4), "San Francesco d’Assisi", "Saint Francis of Assisi"}
      ),
      {date(year, 11, 1), "Ognissanti", "All Saints' Day"},
      {date(year, 12, 8), "Immacolata Concezione", "Immaculate Conception"},
      {date(year, 12, 25), "Natale", "Christmas Day"},
      {date(year, 12, 26), "Santo Stefano", "Saint Stephen's Day"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
