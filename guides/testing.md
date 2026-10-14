# Testing

A picker is a form field, so most of its tests are tests of a form and
a changeset. `Koyomi.Test` adds two helpers for `Phoenix.LiveViewTest`,
which runs no JavaScript: `pick/3` picks a value as the picker would post
it, and `request_days/4` asks a LiveView for its day content.

The helpers read the rendered HTML with LazyHTML, which
`Phoenix.LiveViewTest` uses too. A Phoenix 1.8 app has it in its test
dependencies.

## Picking a value

```elixir
defmodule MyAppWeb.BookingLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Koyomi.Test

  test "picks a due date and a stay", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/booking")

    pick(view, "booking_due_picker", ~D[2027-03-15])
    html = pick(view, "booking_stay_picker", Date.range(~D[2027-03-01], ~D[2027-03-03]))

    refute html =~ "must be"
  end
end
```

`pick(view, picker_id, value)` finds the picker with that id (a leading
`#` is allowed), finds the form around it, and sends the form's
`phx-change` with the value in the picker's inputs, as the hook does in a
browser. It returns the rendered LiveView, as
`Phoenix.LiveViewTest.render_change/2` does.

The id is the picker's `id`: by default the field's id with `_picker`,
such as `booking_due_picker` for `@form[:due]` of a form built `as:
:booking` (see the [Forms](forms.md) guide).

The event carries:

* the picker's inputs, with the new value;
* every other Koyomi picker of the form, with the value that the server
  last rendered in its `data-value`;
* the other inputs of the form, as they are;
* `_target`, set to the picker's input, as a browser sets it.

The form must have an `id` and a `phx-change`. The test fails with a
message when there is no picker with that id, when the picker is not in a
form, or when the form has no id.

## The values

`value` is what the picker would post:

| Picker | Value |
|---|---|
| date | a `Date`, or `"2027-03-15"` |
| date range | a `Date.Range`, a `{first, last}` tuple, or a map with `"from"` and `"to"` |
| several days | a list of `Date` |
| month | `"2027-03"` |
| year | an integer, `2027` |
| week | `"2027-W11"` |
| time | a `Time` |
| date and time, `time_zone` | a `DateTime`, posted with its offset |
| date and time, no zone | a `NaiveDateTime` |
| recurrence | a `Koyomi.Recurrence`, or the rule text |
| any picker | `nil`, to clear it |

The values are written as the picker writes them: seconds are dropped
from a time, and the days of a list are sorted, without repeats. For a
month or a week picker, give the ISO string: a `Date` is posted as a full
date, which these pickers do not post.

```elixir
pick(view, "booking_days_picker", [~D[2027-03-05], ~D[2027-03-01]])
pick(view, "booking_month_picker", "2027-04")
pick(view, "booking_week_picker", "2027-W11")
pick(view, "booking_year_picker", 2027)
pick(view, "booking_at_picker", ~T[09:15:00])
pick(view, "booking_repeat_picker", "FREQ=WEEKLY;BYDAY=MO,WE")

pick(
  view,
  "booking_starts_at_picker",
  DateTime.new!(~D[2027-07-15], ~T[14:30:00], "Europe/Lisbon")
)
```

The last one posts `2027-07-15T14:30:00+01:00`, which a `:utc_datetime`
field casts to `~U[2027-07-15 13:30:00Z]`. A `DateTime` in a zone other
than UTC needs a time zone database in the test environment.

Clearing a range posts both ends empty, and clearing the several days
picker posts only the empty first entry:

```elixir
html = pick(view, "booking_stay_picker", nil)
```

## Testing the rules

`pick/3` does not check the value against the rules: the LiveView does,
through its changeset. So a test can pick a value that the browser would
disable, to see the server refuse it:

```elixir
test "a Sunday is not available", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/booking")

  html = pick(view, "booking_due_picker", ~D[2027-03-14])

  assert html =~ "is not available"
end
```

The error shows only when the LiveView renders it. With the error helper
of the [Forms](forms.md) guide, a field shows its errors when
`Phoenix.Component.used_input?/1` is true. A value picked with `pick/3`
counts as used: the event has the field, with no `_unused_` entry for it.

The rules themselves are plain data, and most of their tests need no
LiveView. Test the changeset:

```elixir
test "a stay is two to seven days" do
  changeset =
    Booking.changeset(%{"stay" => %{"from" => "2027-03-01", "to" => "2027-03-20"}})

  assert {"must be at most %{count} days", keys} = changeset.errors[:stay]
  assert keys[:kind] == :too_long
  assert keys[:count] == 7
end
```

Each error of `Koyomi.Changeset` has `validation: :koyomi` and `kind:` in
its keys (`:before_min`, `:disabled`, `:too_long` and so on), so a test
can match the kind rather than the message. `Koyomi.Changeset.messages/0`
returns the default message of each kind.

Or test the rules with no changeset at all:

```elixir
rules = Booking.due_rules()

assert Koyomi.Rules.check_date(rules, ~D[2027-02-28]) ==
         {:error, {:before_min, min: ~D[2027-03-01]}}
```

Rules with `:today` read today from the clock, in the zone of the rules.
`Koyomi.Rules` has no option to fix today in a test. Build the expected
values from `Koyomi.Rules.today/1`, or give fixed dates in the rules that
a test uses.

## Day content

`request_days(view, picker_id, first, last)` sends the `koyomi:days`
event of a picker, as the picker sends it for the days it shows, and
returns the reply:

```elixir
test "a full day is disabled", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/booking")

  reply = request_days(view, "booking_stay_picker", ~D[2027-03-15], ~D[2027-03-21])

  assert reply["days"] == %{
           "2027-03-17" => %{"disabled" => true, "label" => "Full", "tone" => "danger"}
         }
end
```

The reply is the map that `Koyomi.Live.handle_days/4` sends to the
browser, keyed by ISO date: each day has `"label"`, `"title"`, `"tone"`,
`"marks"`, `"disabled"` and `"slots"` when the callback gave them.

```elixir
reply = request_days(view, "booking_starts_at_picker", ~D[2027-03-15], ~D[2027-03-15])

assert reply["days"]["2027-03-15"]["slots"] == [
         %{"time" => "09:00:00"},
         %{"time" => "10:00:00", "label" => "10:00 – 10:30"}
       ]
```

A callback that raises replies with `%{"error" => true}` and logs the
error. A span of more than 800 days replies with no days:

```elixir
import ExUnit.CaptureLog

log =
  capture_log(fn ->
    assert %{"error" => true} =
             request_days(view, "booking_due_picker", ~D[2027-03-15], ~D[2027-03-21])
  end)

assert log =~ "the days of booking_due_picker failed"
```

With `async: true`, the reply only says that the days will come
(`"pending" => true`); the days arrive later in a `koyomi:days` push,
which `assert_push_event/3` sees.

## Pushes from the server

The pushes of `Koyomi.Live` are LiveView events, so
`Phoenix.LiveViewTest.assert_push_event/3` checks them. Each carries the
picker's id. Here the LiveView's `"push"` event calls
`Koyomi.Live.push_value(socket, "booking_due_picker", date)`:

```elixir
render_hook(view, "push", %{"value" => "2027-03-15"})

assert_push_event(view, "koyomi:set", %{"id" => "booking_due_picker", "value" => "2027-03-15"})
```

The events are `koyomi:set` (`push_value/3`), `koyomi:open`,
`koyomi:close`, `koyomi:focus` and `koyomi:refresh` (`refresh_days/2`).
Without a browser, nothing acts on them: a test of `push_value/3` sees the
push, not a `phx-change`.

## What these tests do not cover

`Phoenix.LiveViewTest` runs no JavaScript. The segments, the calendar,
the rules in the browser, the typing box and the keyboard are tested in a
browser. Koyomi's own browser tests use Playwright (see `e2e/` in the
repository); an app that wants the same can drive its pages with
Playwright or Wallaby.
