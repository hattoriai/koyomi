defmodule Koyomi.Holidays.IN do
  @moduledoc """
  The three national holidays of India, in Hindi: Republic Day,
  Independence Day and Gandhi Jayanti.

  The other holidays (Diwali, Holi, Eid and others) follow lunar
  calendars and differ by state, and are not listed.
  """
  use Koyomi.Holidays.Country, code: "IN", language: "hi"

  @impl true
  @spec holidays(integer()) :: [Koyomi.Holidays.Provider.entry()]
  def holidays(year) do
    [
      {date(year, 1, 26), "गणतंत्र दिवस", "Republic Day"},
      {date(year, 8, 15), "स्वतंत्रता दिवस", "Independence Day"},
      {date(year, 10, 2), "गांधी जयंती", "Gandhi Jayanti"}
    ]
  end
end
