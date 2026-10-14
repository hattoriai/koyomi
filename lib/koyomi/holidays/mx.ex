defmodule Koyomi.Holidays.MX do
  @moduledoc """
  The mandatory rest days of Mexico (Ley Federal del Trabajo, article 74),
  in Spanish.

  October 1 of each sixth year from 2024 (the transfer of the federal
  executive) is listed. Election days, which the electoral laws declare
  one by one, are not.
  """
  use Koyomi.Holidays.Country, code: "MX", language: "es"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 1), "Año Nuevo", "New Year's Day"},
      {nth_weekday(year, 2, 1, 1), "Día de la Constitución", "Constitution Day"},
      {nth_weekday(year, 3, 1, 3), "Natalicio de Benito Juárez", "Benito Juárez's Birthday"},
      {date(year, 5, 1), "Día del Trabajo", "Labour Day"},
      {date(year, 9, 16), "Día de la Independencia", "Independence Day"},
      if(year >= 2024 and rem(year - 2024, 6) == 0,
        do:
          {date(year, 10, 1), "Transmisión del Poder Ejecutivo Federal",
           "Transfer of the Federal Executive"}
      ),
      {nth_weekday(year, 11, 1, 3), "Día de la Revolución", "Revolution Day"},
      {date(year, 12, 25), "Navidad", "Christmas Day"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
