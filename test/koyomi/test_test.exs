defmodule Koyomi.TestTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Koyomi.Test

  @endpoint KoyomiTest.Endpoint

  setup do
    {:ok, view, _html} = live(build_conn(), "/booking")
    %{view: view}
  end

  test "picks a date, a range, days, a month, a week, a year and a time", %{view: view} do
    pick(view, "booking_due_picker", ~D[2027-03-15])
    pick(view, "booking_stay_picker", Date.range(~D[2027-03-01], ~D[2027-03-03]))
    pick(view, "booking_days_picker", [~D[2027-03-05], ~D[2027-03-01]])
    pick(view, "booking_month_picker", "2027-04")
    pick(view, "booking_week_picker", "2027-W11")
    pick(view, "booking_year_picker", 2027)
    html = pick(view, "booking_at_picker", ~T[09:15:00])

    changes = html |> LazyHTML.from_fragment() |> LazyHTML.query("#changes") |> LazyHTML.text()
    assert changes =~ "due: ~D[2027-03-15]"
    assert changes =~ "stay: Date.range(~D[2027-03-01], ~D[2027-03-03])"
    assert changes =~ "days: [~D[2027-03-01], ~D[2027-03-05]]"
    assert changes =~ "month: ~D[2027-04-01]"
    assert changes =~ "week: ~D[2027-03-15]"
    assert changes =~ "year: 2027"
    assert changes =~ "at: ~T[09:15:00]"
  end

  test "picks a date and time with its offset, and a recurrence", %{view: view} do
    pick(
      view,
      "booking_starts_at_picker",
      DateTime.new!(~D[2027-07-15], ~T[14:30:00], "Europe/Lisbon")
    )

    html = pick(view, "booking_repeat_picker", "FREQ=WEEKLY;BYDAY=MO,WE")
    changes = html |> LazyHTML.from_fragment() |> LazyHTML.query("#changes") |> LazyHTML.text()
    assert changes =~ "starts_at: ~U[2027-07-15 13:30:00Z]"

    assert changes =~
             "freq: :weekly, interval: 1, count: nil, until: nil, by_day: [nil: 1, nil: 3]"
  end

  test "a value that the rules refuse shows the server's error", %{view: view} do
    html = pick(view, "booking_due_picker", ~D[2027-03-14])

    assert html |> LazyHTML.from_fragment() |> LazyHTML.query("#errors") |> LazyHTML.text() =~
             "is not available"
  end

  test "clearing", %{view: view} do
    pick(view, "booking_stay_picker", Date.range(~D[2027-03-01], ~D[2027-03-03]))
    html = pick(view, "booking_stay_picker", nil)

    refute html |> LazyHTML.from_fragment() |> LazyHTML.query("#changes") |> LazyHTML.text() =~
             "stay:"
  end

  test "an unknown picker fails the test", %{view: view} do
    assert_raise ExUnit.AssertionError, ~r/no picker with the id "nope"/, fn ->
      pick(view, "nope", ~D[2027-03-15])
    end
  end
end
