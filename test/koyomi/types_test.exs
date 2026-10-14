defmodule Koyomi.TypesTest do
  use ExUnit.Case, async: true

  alias Koyomi.{DateRange, Dates, DateTimeRange, ISOWeek, Month, Week}

  doctest DateRange
  doctest DateTimeRange
  doctest Month
  doctest ISOWeek

  describe "Koyomi.DateRange" do
    test "casts the picker's params, intervals, tuples and ranges" do
      range = Date.range(~D[2027-03-01], ~D[2027-03-07])
      assert {:ok, ^range} = DateRange.cast(%{"from" => "2027-03-01", "to" => "2027-03-07"})
      assert {:ok, ^range} = DateRange.cast("2027-03-01/2027-03-07")
      assert {:ok, ^range} = DateRange.cast({~D[2027-03-01], ~D[2027-03-07]})
      assert {:ok, ^range} = DateRange.cast(range)
      assert {:ok, nil} = DateRange.cast(%{"from" => "", "to" => ""})
      assert {:ok, nil} = DateRange.cast("")
    end

    test "refuses one end, a reversed range and garbage" do
      assert {:error, message: "must have a start and an end"} =
               DateRange.cast(%{"from" => "2027-03-01", "to" => ""})

      assert {:error, message: "must end on or after its start"} =
               DateRange.cast("2027-03-07/2027-03-01")

      assert :error = DateRange.cast(%{"from" => "2027-02-30", "to" => "2027-03-01"})
      assert :error = DateRange.cast(42)
    end

    test "dumps the canonical daterange and loads any form" do
      range = Date.range(~D[2027-03-01], ~D[2027-03-07])

      assert {:ok,
              %Postgrex.Range{
                lower: ~D[2027-03-01],
                upper: ~D[2027-03-08],
                lower_inclusive: true,
                upper_inclusive: false
              }} =
               DateRange.dump(range)

      assert {:ok, ^range} =
               DateRange.load(%Postgrex.Range{
                 lower: ~D[2027-03-01],
                 upper: ~D[2027-03-08],
                 lower_inclusive: true,
                 upper_inclusive: false
               })

      assert {:ok, ^range} =
               DateRange.load(%Postgrex.Range{
                 lower: ~D[2027-02-28],
                 upper: ~D[2027-03-07],
                 lower_inclusive: false,
                 upper_inclusive: true
               })

      assert {:ok, nil} = DateRange.load(%Postgrex.Range{lower: :unbound, upper: ~D[2027-03-07]})
    end
  end

  test "Koyomi.DateTimeRange casts instants with offsets to UTC" do
    assert {:ok, %DateTimeRange{from: ~U[2027-03-15 13:00:00Z], to: ~U[2027-03-15 15:00:00Z]}} =
             DateTimeRange.cast(%{
               "from" => "2027-03-15T14:00:00+01:00",
               "to" => "2027-03-15T16:00:00+01:00"
             })

    assert {:error, _} =
             DateTimeRange.cast(%{
               "from" => "2027-03-15T16:00:00Z",
               "to" => "2027-03-15T14:00:00Z"
             })

    assert {:ok, %Postgrex.Range{upper_inclusive: false}} =
             DateTimeRange.dump(%DateTimeRange{
               from: ~U[2027-03-15 13:00:00Z],
               to: ~U[2027-03-15 15:00:00Z]
             })
  end

  test "Koyomi.Dates drops the sentinel, repeats and sorts" do
    assert {:ok, [~D[2027-03-01], ~D[2027-03-05]]} =
             Dates.cast(["", "2027-03-05", "2027-03-01", "2027-03-05"])

    assert {:ok, [~D[2027-03-01]]} = Dates.cast("2027-03-01, ")
    assert {:ok, []} = Dates.cast([""])
    assert :error = Dates.cast(["nope"])
  end

  test "Koyomi.Month and Koyomi.Week" do
    assert {:ok, ~D[2027-03-01]} = Month.cast("2027-03")
    assert {:ok, ~D[2027-03-01]} = Month.cast(~D[2027-03-19])
    assert {:ok, ~D[2027-03-01]} = Month.cast(%{"year" => "2027", "month" => "3"})
    assert :error = Month.cast("2027-13")
    assert {:ok, ~D[2027-03-15]} = Week.cast("2027-W11")
    assert {:ok, ~D[2027-03-15]} = Week.cast(~D[2027-03-21])
    assert :error = Week.cast("2027-W54")
  end
end
