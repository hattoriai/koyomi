defmodule Koyomi.PresetsTest do
  use ExUnit.Case, async: true

  alias Koyomi.Presets

  doctest Presets

  # Monday 15 March 2027.
  @today ~D[2027-03-15]

  defp values(presets, kind, first_day \\ 1),
    do: presets |> Presets.resolve(kind, @today, first_day) |> Enum.map(& &1["value"])

  test "days" do
    assert values(
             [:today, :yesterday, {:in, 2, :weeks}, {:ago, 1, :month}, {:in, 1, :year}],
             :date
           ) ==
             ["2027-03-15", "2027-03-14", "2027-03-29", "2027-02-15", "2028-03-15"]
  end

  test "periods, for a range and for a date" do
    assert values([:this_week, :last_month, :this_quarter, :next_week], :range) == [
             %{"from" => "2027-03-15", "to" => "2027-03-21"},
             %{"from" => "2027-02-01", "to" => "2027-02-28"},
             %{"from" => "2027-01-01", "to" => "2027-03-31"},
             %{"from" => "2027-03-22", "to" => "2027-03-28"}
           ]

    assert values([:this_week], :range, 7) == [%{"from" => "2027-03-14", "to" => "2027-03-20"}]
    assert values([:next_month], :date) == ["2027-04-01"]
    assert values([:today], :range) == [%{"from" => "2027-03-15", "to" => "2027-03-15"}]
  end

  test "the browser labels the built-in presets" do
    [last, ytd, week] =
      Presets.resolve([{:last, 30, :days}, :year_to_date, :next_week], :range, @today)

    assert last["message"] == "lastDays" and last["n"] == 30
    assert ytd["message"] == "yearToDate"
    assert week["relative"] == %{"n" => 1, "unit" => "week"}
  end

  test "the app's own presets" do
    [christmas, school] =
      Presets.resolve(
        [
          {"Christmas", ~D[2027-12-25]},
          {"Term", fn today -> Date.range(today, Date.add(today, 90)) end}
        ],
        :range,
        @today
      )

    assert christmas == %{
             "id" => "preset-0",
             "label" => "Christmas",
             "value" => %{"from" => "2027-12-25", "to" => "2027-12-25"}
           }

    assert school["value"] == %{"from" => "2027-03-15", "to" => "2027-06-13"}
  end

  test "unknown presets" do
    assert_raise ArgumentError, ~r/unknown preset/, fn ->
      Presets.resolve([:someday], :date, @today)
    end

    assert_raise ArgumentError, ~r/unknown unit/, fn ->
      Presets.resolve([{:in, 1, :fortnight}], :date, @today)
    end
  end
end
