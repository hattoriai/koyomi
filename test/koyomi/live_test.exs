defmodule Koyomi.LiveTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint KoyomiTest.Endpoint

  doctest Koyomi.Live

  setup do
    {:ok, view, html} = live(build_conn(), "/booking")
    %{view: view, html: html}
  end

  test "the days of a picker", %{view: view} do
    reply = Koyomi.Test.request_days(view, "booking_stay_picker", ~D[2027-03-15], ~D[2027-03-21])

    assert reply["days"] == %{
             "2027-03-17" => %{"disabled" => true, "label" => "Full", "tone" => "danger"}
           }
  end

  test "slots", %{view: view} do
    reply =
      Koyomi.Test.request_days(view, "booking_starts_at_picker", ~D[2027-03-15], ~D[2027-03-15])

    assert reply["days"]["2027-03-15"]["slots"] == [
             %{"time" => "09:00:00"},
             %{"time" => "10:00:00", "label" => "10:00 – 10:30"}
           ]
  end

  test "a callback that raises replies with an error", %{view: view} do
    log =
      capture_log(fn ->
        assert %{"error" => true} =
                 Koyomi.Test.request_days(
                   view,
                   "booking_due_picker",
                   ~D[2027-03-15],
                   ~D[2027-03-21]
                 )
      end)

    assert log =~ "the days of booking_due_picker failed"
  end

  test "a span too long gets no days", %{view: view} do
    assert %{"days" => %{}} =
             Koyomi.Test.request_days(view, "booking_stay_picker", ~D[2027-01-01], ~D[2029-12-31])
  end

  test "push_value", %{view: view} do
    render_hook(view, "push", %{"value" => "2027-03-15"})

    assert_push_event(view, "koyomi:set", %{"id" => "booking_due_picker", "value" => "2027-03-15"})
  end

  test "normalize_days/2 checks the tones and shifts DateTime slots" do
    days =
      Koyomi.Live.normalize_days(
        %{
          ~D[2027-07-15] => [slots: [~U[2027-07-15 08:00:00Z]], tone: "success", title: "3 left"]
        },
        "Europe/Lisbon"
      )

    assert days == %{
             "2027-07-15" => %{
               "slots" => [%{"time" => "09:00:00"}],
               "tone" => "success",
               "title" => "3 left"
             }
           }

    assert_raise ArgumentError, ~r/tone/, fn ->
      Koyomi.Live.normalize_days(%{~D[2027-07-15] => [tone: :loud]})
    end
  end
end
