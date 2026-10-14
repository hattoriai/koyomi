defmodule Koyomi.ISOWeek do
  @moduledoc """
  ISO 8601 weeks: weeks start on Monday, and week 1 of a year is the week
  that holds the year's first Thursday. A week is written `2027-W11`.

  The week picker posts weeks in this form, and `Koyomi.Week` stores the
  Monday of the week in a `:date` column.
  """

  @doc """
  The ISO year and week number of a day.

  ## Examples

      iex> Koyomi.ISOWeek.week(~D[2027-01-01])
      {2026, 53}
      iex> Koyomi.ISOWeek.week(~D[2027-03-15])
      {2027, 11}

  """
  @spec week(Date.t()) :: {integer(), 1..53}
  def week(%Date{} = date), do: :calendar.iso_week_number(Date.to_erl(date))

  @doc """
  The Monday of an ISO week, or `:error` when the year has no such week.

  ## Examples

      iex> Koyomi.ISOWeek.monday(2026, 53)
      {:ok, ~D[2026-12-28]}
      iex> Koyomi.ISOWeek.monday(2027, 53)
      :error

  """
  @spec monday(integer(), integer()) :: {:ok, Date.t()} | :error
  def monday(year, week) when is_integer(year) and is_integer(week) do
    if week >= 1 and week <= weeks_in_year(year) do
      jan4 = Date.new!(year, 1, 4)
      {:ok, jan4 |> Date.beginning_of_week(:monday) |> Date.add((week - 1) * 7)}
    else
      :error
    end
  end

  @doc """
  The number of ISO weeks of a year: 52 or 53.

  ## Examples

      iex> Koyomi.ISOWeek.weeks_in_year(2026)
      53

  """
  @spec weeks_in_year(integer()) :: 52 | 53
  def weeks_in_year(year), do: elem(week(Date.new!(year, 12, 28)), 1)

  @doc """
  Writes the week of a day as `YYYY-Www`.

  ## Examples

      iex> Koyomi.ISOWeek.to_iso8601(~D[2027-03-17])
      "2027-W11"

  """
  @spec to_iso8601(Date.t()) :: String.t()
  def to_iso8601(%Date{} = date) do
    {year, week} = week(date)

    "#{year |> Integer.to_string() |> String.pad_leading(4, "0")}-W#{week |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  @doc """
  Reads `YYYY-Www` (or `YYYYWww`) into the Monday of the week.

  ## Examples

      iex> Koyomi.ISOWeek.from_iso8601("2027-W11")
      {:ok, ~D[2027-03-15]}
      iex> Koyomi.ISOWeek.from_iso8601("2027-W54")
      :error

  """
  @spec from_iso8601(String.t()) :: {:ok, Date.t()} | :error
  def from_iso8601(text) when is_binary(text) do
    case Regex.run(~r/^(\d{4})-?W(\d{2})$/, String.trim(text)) do
      [_, year, week] -> monday(String.to_integer(year), String.to_integer(week))
      nil -> :error
    end
  end
end
