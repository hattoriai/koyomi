defmodule Koyomi.Holidays.BR do
  @moduledoc """
  The national holidays of Brazil, in Portuguese.

  Carnival and Corpus Christi are optional days off (pontos facultativos)
  and are not listed. The Day of Zumbi and Black Awareness is listed from
  2024.
  """
  use Koyomi.Holidays.Country, code: "BR", language: "pt"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 1), "Confraternização Universal", "New Year's Day"},
      {Date.add(easter(year), -2), "Sexta-feira Santa", "Good Friday"},
      {date(year, 4, 21), "Tiradentes", "Tiradentes Day"},
      {date(year, 5, 1), "Dia do Trabalho", "Labour Day"},
      {date(year, 9, 7), "Independência do Brasil", "Independence Day"},
      {date(year, 10, 12), "Nossa Senhora Aparecida", "Our Lady of Aparecida"},
      {date(year, 11, 2), "Finados", "All Souls' Day"},
      {date(year, 11, 15), "Proclamação da República", "Republic Day"},
      if(year >= 2024,
        do:
          {date(year, 11, 20), "Dia Nacional de Zumbi e da Consciência Negra",
           "Black Awareness Day"}
      ),
      {date(year, 12, 25), "Natal", "Christmas Day"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
