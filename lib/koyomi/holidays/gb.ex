defmodule Koyomi.Holidays.GB do
  @moduledoc """
  The bank holidays of England and Wales, in English. Scotland and
  Northern Ireland have other lists, and are not covered.

  When New Year's Day, Christmas Day or Boxing Day is on a weekend, the
  next free weekday is a substitute day (see
  `Koyomi.Holidays.Rules.substitute_days/2`). The holiday stays on its
  date, and an entry "<name> (substitute day)" marks the day off. One-off
  bank holidays and moved ones (for a jubilee or a coronation) are not
  listed.
  """
  use Koyomi.Holidays.Country, code: "GB", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)
    new_year = same(date(year, 1, 1), "New Year's Day")
    christmas = same(date(year, 12, 25), "Christmas Day")
    boxing = same(date(year, 12, 26), "Boxing Day")

    holidays = [
      new_year,
      same(Date.add(easter, -2), "Good Friday"),
      same(Date.add(easter, 1), "Easter Monday"),
      same(nth_weekday(year, 5, 1, 1), "Early May bank holiday"),
      same(nth_weekday(year, 5, 1, :last), "Spring bank holiday"),
      same(nth_weekday(year, 8, 1, :last), "Summer bank holiday"),
      christmas,
      boxing
    ]

    substitutes =
      for {day, {_, name, _}} <- substitute_days(holidays, [new_year, christmas, boxing]),
          do: same(day, name <> " (substitute day)")

    holidays ++ substitutes
  end

  defp same(date, name), do: {date, name, name}
end
