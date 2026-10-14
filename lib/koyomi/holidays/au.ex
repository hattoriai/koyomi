defmodule Koyomi.Holidays.AU do
  @moduledoc """
  The public holidays of Australia kept in every state and territory, in
  English.

  When New Year's Day, Christmas Day or Boxing Day falls on a weekend,
  every state adds the next free weekday (see
  `Koyomi.Holidays.Rules.substitute_days/2`), and Australia Day on a
  weekend moves to the Monday after. The holiday stays on its date, and
  an entry "<name> (observed)" marks the added day. Anzac Day on a
  weekend gets another day in some states only, so none is added. The
  King's Birthday, Easter Saturday and Labour Day, on dates that differ by
  state, are not listed.
  """
  use Koyomi.Holidays.Country, code: "AU", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)
    new_year = same(date(year, 1, 1), "New Year's Day")
    australia_day = date(year, 1, 26)
    christmas = same(date(year, 12, 25), "Christmas Day")
    boxing = same(date(year, 12, 26), "Boxing Day")

    holidays = [
      new_year,
      same(australia_day, "Australia Day"),
      same(Date.add(easter, -2), "Good Friday"),
      same(Date.add(easter, 1), "Easter Monday"),
      same(date(year, 4, 25), "Anzac Day"),
      christmas,
      boxing
    ]

    australia_day_observed =
      if weekend?(australia_day),
        do: [same(on_or_after(australia_day, 1), "Australia Day (observed)")],
        else: []

    substitutes =
      for {day, {_, name, _}} <- substitute_days(holidays, [new_year, christmas, boxing]),
          do: same(day, name <> " (observed)")

    holidays ++ australia_day_observed ++ substitutes
  end

  defp same(date, name), do: {date, name, name}
end
