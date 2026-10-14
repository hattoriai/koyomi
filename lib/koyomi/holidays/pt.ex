defmodule Koyomi.Holidays.PT do
  @moduledoc """
  The mandatory public holidays of Portugal (Código do Trabalho, article
  234), in Portuguese.

  Carnival and the municipal holidays are optional or local, and are not
  listed. Corpus Christi, October 5, November 1 and December 1 were
  suspended from 2013 to 2015, and are not listed in those years.
  """
  use Koyomi.Holidays.Country, code: "PT", language: "pt"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)
    kept? = year not in 2013..2015

    [
      {date(year, 1, 1), "Ano Novo", "New Year's Day"},
      {Date.add(easter, -2), "Sexta-feira Santa", "Good Friday"},
      {easter, "Páscoa", "Easter Sunday"},
      {date(year, 4, 25), "Dia da Liberdade", "Freedom Day"},
      {date(year, 5, 1), "Dia do Trabalhador", "Labour Day"},
      if(kept?, do: {Date.add(easter, 60), "Corpo de Deus", "Corpus Christi"}),
      {date(year, 6, 10), "Dia de Portugal, de Camões e das Comunidades Portuguesas",
       "Portugal Day"},
      {date(year, 8, 15), "Assunção de Nossa Senhora", "Assumption Day"},
      if(kept?, do: {date(year, 10, 5), "Implantação da República", "Republic Day"}),
      if(kept?, do: {date(year, 11, 1), "Dia de Todos os Santos", "All Saints' Day"}),
      if(kept?,
        do: {date(year, 12, 1), "Restauração da Independência", "Restoration of Independence"}
      ),
      {date(year, 12, 8), "Imaculada Conceição", "Immaculate Conception"},
      {date(year, 12, 25), "Natal", "Christmas Day"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
