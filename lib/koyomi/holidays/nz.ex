defmodule Koyomi.Holidays.NZ do
  @moduledoc """
  The national public holidays of New Zealand (Holidays Act 2003), in
  English.

  Mondayisation: when New Year's Day, the day after it, Christmas Day or
  Boxing Day falls on a weekend, the next free weekday is a holiday (see
  `Koyomi.Holidays.Rules.substitute_days/2`); Waitangi Day and Anzac Day
  on a weekend move to the Monday after. The holiday stays on its date,
  and an entry "<name> (observed)" marks the added day. Matariki is
  listed on the dates the Te Kāhui o Matariki Public Holiday Act 2022
  sets, 2022 to 2052. The regional anniversary days are not listed.
  """
  use Koyomi.Holidays.Country, code: "NZ", language: "en"

  @matariki %{
    2022 => {6, 24},
    2023 => {7, 14},
    2024 => {6, 28},
    2025 => {6, 20},
    2026 => {7, 10},
    2027 => {6, 25},
    2028 => {7, 14},
    2029 => {7, 6},
    2030 => {6, 21},
    2031 => {7, 11},
    2032 => {7, 2},
    2033 => {6, 24},
    2034 => {7, 7},
    2035 => {6, 29},
    2036 => {7, 18},
    2037 => {7, 10},
    2038 => {6, 25},
    2039 => {7, 15},
    2040 => {7, 6},
    2041 => {7, 19},
    2042 => {7, 11},
    2043 => {7, 3},
    2044 => {6, 24},
    2045 => {7, 7},
    2046 => {6, 29},
    2047 => {7, 19},
    2048 => {7, 3},
    2049 => {6, 25},
    2050 => {7, 15},
    2051 => {6, 30},
    2052 => {7, 19}
  }

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)
    new_year = same(date(year, 1, 1), "New Year's Day")
    day_after = same(date(year, 1, 2), "Day after New Year's Day")
    waitangi = same(date(year, 2, 6), "Waitangi Day")
    anzac = same(date(year, 4, 25), "Anzac Day")
    christmas = same(date(year, 12, 25), "Christmas Day")
    boxing = same(date(year, 12, 26), "Boxing Day")

    holidays =
      [
        new_year,
        day_after,
        waitangi,
        same(Date.add(easter, -2), "Good Friday"),
        same(Date.add(easter, 1), "Easter Monday"),
        anzac,
        same(nth_weekday(year, 6, 1, 1), "King's Birthday"),
        matariki(year),
        same(nth_weekday(year, 10, 1, 4), "Labour Day"),
        christmas,
        boxing
      ]
      |> Enum.reject(&is_nil/1)

    mondays =
      for {date, name, _} <- [waitangi, anzac],
          weekend?(date),
          do: same(on_or_after(date, 1), name <> " (observed)")

    substitutes =
      for {day, {_, name, _}} <-
            substitute_days(holidays, [new_year, day_after, christmas, boxing]),
          do: same(day, name <> " (observed)")

    holidays ++ mondays ++ substitutes
  end

  defp matariki(year) do
    case @matariki do
      %{^year => {month, day}} -> same(date(year, month, day), "Matariki")
      _ -> nil
    end
  end

  defp same(date, name), do: {date, name, name}
end
