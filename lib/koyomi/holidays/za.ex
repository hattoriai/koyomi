defmodule Koyomi.Holidays.ZA do
  @moduledoc """
  The public holidays of South Africa (Public Holidays Act 1994), in
  English, the language South Africans share most.

  When a holiday falls on a Sunday, the Monday after is a public holiday:
  the holiday stays on its date, and an entry "<name> (observed)" marks
  the Monday, unless the Monday is already a holiday (Boxing Day, here
  the Day of Goodwill, after Christmas on a Sunday). Election days and
  days the President declares are not listed.
  """
  use Koyomi.Holidays.Country, code: "ZA", language: "en"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    holidays =
      Enum.map(
        [
          {date(year, 1, 1), "New Year's Day"},
          {date(year, 3, 21), "Human Rights Day"},
          {Date.add(easter, -2), "Good Friday"},
          {Date.add(easter, 1), "Family Day"},
          {date(year, 4, 27), "Freedom Day"},
          {date(year, 5, 1), "Workers' Day"},
          {date(year, 6, 16), "Youth Day"},
          {date(year, 8, 9), "National Women's Day"},
          {date(year, 9, 24), "Heritage Day"},
          {date(year, 12, 16), "Day of Reconciliation"},
          {date(year, 12, 25), "Christmas Day"},
          {date(year, 12, 26), "Day of Goodwill"}
        ],
        fn {date, name} -> {date, name, name} end
      )

    dates = MapSet.new(holidays, &elem(&1, 0))

    mondays =
      for {date, name, _} <- holidays,
          Date.day_of_week(date) == 7,
          monday = Date.add(date, 1),
          not MapSet.member?(dates, monday),
          do: {monday, name <> " (observed)", name <> " (observed)"}

    holidays ++ mondays
  end
end
