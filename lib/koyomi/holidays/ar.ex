defmodule Koyomi.Holidays.AR do
  @moduledoc """
  The national holidays of Argentina (Ley 27.399), in Spanish.

  The movable holidays (June 17, August 17, October 12 and November 20)
  move by the law's rule: one on a Tuesday or a Wednesday to the Monday
  before, one on a Thursday or a Friday to the Monday after. Only the day
  they move to is listed. The government sometimes sets other days by
  decree, and declares days off for tourism (días no laborables); neither
  is listed.
  """
  use Koyomi.Holidays.Country, code: "AR", language: "es"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Año Nuevo", "New Year's Day"},
      {Date.add(easter, -48), "Carnaval", "Carnival"},
      {Date.add(easter, -47), "Carnaval", "Carnival"},
      {date(year, 3, 24), "Día Nacional de la Memoria por la Verdad y la Justicia",
       "Day of Remembrance for Truth and Justice"},
      {date(year, 4, 2), "Día del Veterano y de los Caídos en la Guerra de Malvinas",
       "Malvinas Day"},
      {Date.add(easter, -2), "Viernes Santo", "Good Friday"},
      {date(year, 5, 1), "Día del Trabajador", "Labour Day"},
      {date(year, 5, 25), "Día de la Revolución de Mayo", "May Revolution Day"},
      {moved(date(year, 6, 17)), "Paso a la Inmortalidad del General Martín Miguel de Güemes",
       "Anniversary of the Death of General Güemes"},
      {date(year, 6, 20), "Paso a la Inmortalidad del General Manuel Belgrano", "Flag Day"},
      {date(year, 7, 9), "Día de la Independencia", "Independence Day"},
      {moved(date(year, 8, 17)), "Paso a la Inmortalidad del General José de San Martín",
       "Anniversary of the Death of General San Martín"},
      {moved(date(year, 10, 12)), "Día del Respeto a la Diversidad Cultural",
       "Day of Respect for Cultural Diversity"},
      {moved(date(year, 11, 20)), "Día de la Soberanía Nacional", "National Sovereignty Day"},
      {date(year, 12, 8), "Inmaculada Concepción de María", "Immaculate Conception"},
      {date(year, 12, 25), "Navidad", "Christmas Day"}
    ]
  end

  defp moved(date) do
    case Date.day_of_week(date) do
      day when day in [2, 3] -> on_or_before(date, 1)
      day when day in [4, 5] -> on_or_after(date, 1)
      _ -> date
    end
  end
end
