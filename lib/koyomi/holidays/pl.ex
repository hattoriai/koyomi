defmodule Koyomi.Holidays.PL do
  @moduledoc """
  The public holidays of Poland (Ustawa o dniach wolnych od pracy), in
  Polish.

  Epiphany is listed from 2011, Christmas Eve from 2025.
  """
  use Koyomi.Holidays.Country, code: "PL", language: "pl"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Nowy Rok", "New Year's Day"},
      if(year >= 2011, do: {date(year, 1, 6), "Święto Trzech Króli", "Epiphany"}),
      {easter, "Wielkanoc", "Easter Sunday"},
      {Date.add(easter, 1), "Poniedziałek Wielkanocny", "Easter Monday"},
      {date(year, 5, 1), "Święto Pracy", "Labour Day"},
      {date(year, 5, 3), "Święto Narodowe Trzeciego Maja", "Constitution Day"},
      {Date.add(easter, 49), "Zielone Świątki", "Whit Sunday"},
      {Date.add(easter, 60), "Boże Ciało", "Corpus Christi"},
      {date(year, 8, 15), "Wniebowzięcie Najświętszej Maryi Panny", "Assumption Day"},
      {date(year, 11, 1), "Wszystkich Świętych", "All Saints' Day"},
      {date(year, 11, 11), "Narodowe Święto Niepodległości", "Independence Day"},
      if(year >= 2025, do: {date(year, 12, 24), "Wigilia Bożego Narodzenia", "Christmas Eve"}),
      {date(year, 12, 25), "Pierwszy dzień Bożego Narodzenia", "Christmas Day"},
      {date(year, 12, 26), "Drugi dzień Bożego Narodzenia", "Second Day of Christmas"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
