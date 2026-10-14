defmodule Koyomi.Holidays.DK do
  @moduledoc """
  The public holidays of Denmark (helligdage), in Danish.

  Great Prayer Day (Store bededag) is listed up to 2023, its last year.
  Constitution Day (June 5) and Christmas Eve are days off by agreement,
  not public holidays, and are not listed.
  """
  use Koyomi.Holidays.Country, code: "DK", language: "da"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    easter = easter(year)

    [
      {date(year, 1, 1), "Nytårsdag", "New Year's Day"},
      {Date.add(easter, -3), "Skærtorsdag", "Maundy Thursday"},
      {Date.add(easter, -2), "Langfredag", "Good Friday"},
      {easter, "Påskedag", "Easter Sunday"},
      {Date.add(easter, 1), "2. påskedag", "Easter Monday"},
      if(year <= 2023, do: {Date.add(easter, 26), "Store bededag", "Great Prayer Day"}),
      {Date.add(easter, 39), "Kristi himmelfartsdag", "Ascension Day"},
      {Date.add(easter, 49), "Pinsedag", "Whit Sunday"},
      {Date.add(easter, 50), "2. pinsedag", "Whit Monday"},
      {date(year, 12, 25), "Juledag", "Christmas Day"},
      {date(year, 12, 26), "2. juledag", "Second Day of Christmas"}
    ]
    |> Enum.reject(&is_nil/1)
  end
end
