defmodule Koyomi.Holidays.ES do
  @moduledoc """
  The national holidays of Spain, in Spanish: the days that are holidays
  in every autonomous community.

  The communities add their own days, such as Maundy Thursday, and may
  move a holiday that falls on a Sunday to the Monday; neither is listed.
  """
  use Koyomi.Holidays.Country, code: "ES", language: "es"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 1), "Año Nuevo", "New Year's Day"},
      {date(year, 1, 6), "Epifanía del Señor", "Epiphany"},
      {Date.add(easter(year), -2), "Viernes Santo", "Good Friday"},
      {date(year, 5, 1), "Fiesta del Trabajo", "Labour Day"},
      {date(year, 8, 15), "Asunción de la Virgen", "Assumption Day"},
      {date(year, 10, 12), "Fiesta Nacional de España", "National Day of Spain"},
      {date(year, 11, 1), "Todos los Santos", "All Saints' Day"},
      {date(year, 12, 6), "Día de la Constitución Española", "Constitution Day"},
      {date(year, 12, 8), "Inmaculada Concepción", "Immaculate Conception"},
      {date(year, 12, 25), "Natividad del Señor", "Christmas Day"}
    ]
  end
end
