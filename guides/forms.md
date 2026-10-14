# Forms

Each Koyomi picker is a form field. It posts its value with the other
fields of the form, in the form of the browser's own inputs, and the
field's Ecto type casts it in the changeset.

## The element

```heex
<.form for={@form} id="booking-form" phx-change="validate" phx-submit="save">
  <label id="due-label">Due</label>
  <.date_picker field={@form[:due]} label_id="due-label" />
</.form>
```

A picker renders one element with `phx-hook="Koyomi"` and
`phx-update="ignore"`, its id (`booking_due_picker` here: the field's id
with `_picker`), and the inputs that the form posts. The hook builds the
field and the popover around these inputs, and hides the inputs. The
server's later values and options reach the hook through the
`data-value` and `data-config` attributes of the element, which every
render updates.

## What each picker posts

| Picker | Inputs | Example | Cleared |
|---|---|---|---|
| date | `due` | `2027-03-15` | `""` |
| date range, one field | `stay[from]`, `stay[to]` | `2027-03-01`, `2027-03-07` | both `""` |
| date range, `from` and `to` | `check_in`, `check_out` | `2027-03-01`, `2027-03-07` | both `""` |
| several days | `days[]`, an empty first entry, then one per day | `""`, `2027-03-01`, `2027-03-05` | `""` |
| month | `month` | `2027-03` | `""` |
| year | `year` | `2027` | `""` |
| week | `week` | `2027-W11` | `""` |
| time | `at` | `14:30:00` | `""` |
| date and time, `time_zone` | `starts_at` | `2027-03-15T14:30:00+01:00`, or `Z` at offset zero | `""` |
| date and time, no zone | `starts_at` | `2027-03-15T14:30:00` | `""` |
| recurrence | `repeat` | `FREQ=WEEKLY;BYDAY=MO,WE` | `""` (does not repeat) |
| calendar with a `name` | one hidden input | `2027-03-15`, `2027-03-01/2027-03-07`, or `2027-03-01,2027-03-05` | `""` |

The empty first entry of the several days picker makes a form with no day
still post the field. `Koyomi.Dates` drops empty entries, removes repeated
days and sorts the rest.

The types cast more than the picker posts: `Koyomi.DateRange` also casts
a `Date.Range`, a `{first, last}` tuple and an ISO 8601 interval
(`2027-03-01/2027-03-07`); `Koyomi.Month` a `Date` and a map with `"year"`
and `"month"`; `Koyomi.Week` a `Date`; `Koyomi.Dates` a list of `Date` and
a comma-separated string. A range with one end, or one that ends before
it starts, is invalid.

## The form events

On each change, the hook writes the value to the inputs and dispatches
`input` and `change` events on the last input it changed. The form's own
`phx-change` sees them, with `_target` set to that input's name, and
`phx-submit` posts the inputs. The LiveView needs no other event for a
picker.

A picker posts a value when it is whole. A range posts when both ends are
chosen. In the date, month and date and time pickers, a date typed in
segments posts when every segment has a value, or when every segment is
empty; a half-typed date posts nothing.

## Errors

The picker marks its field invalid when the form field has errors and
`Phoenix.Component.used_input?/1` is true for it, so that a field the
person has not touched does not show an error. The segments then have
`aria-invalid="true"` and the field the class `koyomi-invalid`. The
several days and recurrence pickers have no segments, so only the class
marks them (see [Known limits](limits.md)). Once the
person has picked a value, the picker marks every one of its inputs as
used (`phx-no-unused-field`), so the other end of a range counts too.

Show the messages next to the picker, and give their id to the picker as
`aria-describedby`:

```heex
<.date_picker
  field={@form[:due]}
  label_id="due-label"
  aria-describedby={if errors(@form[:due]) != [], do: "due-error"}
/>
<p :for={msg <- errors(@form[:due])} id="due-error" class="error">{msg}</p>
```

```elixir
defp errors(field) do
  if used_input?(field), do: Enum.map(field.errors, &translate_error/1), else: []
end
```

`aria-describedby` and `aria-invalid` given to the picker go to its
segments, not to the picker element. `aria-invalid={true}` marks the field
invalid whatever its errors. A change of either in a later render reaches
the picker without building it again.

The picker also checks the value with its rules in the browser, as the
changeset will, and shows why a value is refused under the field
("Choose a day on or after 1 Mar 2027"), in a polite live region that the
segments name in `aria-describedby`. The changeset still decides: see the
[Rules](rules.md) guide.

## Before the hook mounts, and without JavaScript

Until the hook mounts, the inputs of a picker are the browser's own
inputs of its kind, with the same name and value, and the `min`, `max`
and `step` of the rules:

| Picker | Before the hook |
|---|---|
| date | `<input type="date">` |
| date range | two `<input type="date">`, labelled "Start date" and "End date" |
| several days | one `<input type="date">` per day, and an empty one |
| month | `<input type="month">` |
| year | `<input type="number">` |
| week | `<input type="week">` |
| time | `<input type="time">`, with the rule's `:step` in seconds |
| date and time | `<input type="datetime-local">`, the wall clock in the picker's zone |
| recurrence | `<input type="text">` with the rule text |
| calendar | a hidden input, only with a `name` |

So a form works with JavaScript off. The browser's `datetime-local` input
has no zone: it posts `2027-03-15T14:30`, with no offset and no seconds.
Cast it with `Koyomi.Changeset.cast_datetime/5` (see the
[Time zones](time_zones.md) guide). Some browsers show `month` and `week`
inputs as plain text boxes.

## A picker outside a form

A `calendar/1` with `select`, or any picker with `on_change`, pushes an
event on each change:

```heex
<.calendar id="plan" select="range" on_change="planned" />
```

```elixir
def handle_event("planned", %{"id" => "plan", "value" => value}, socket) do
  # value is %{"from" => "2027-03-01", "to" => "2027-03-07"}
  {:ok, plan} = Koyomi.DateRange.cast(value)
  {:noreply, assign(socket, plan: plan)}
end
```

The value is the picker's wire form: an ISO string, a map of `"from"` and
`"to"` for a range, a list of ISO dates for several days, or `nil`. The
event goes to the `phx-target` of the picker, when it has one. A picker
in a form can have `on_change` too: it then posts with the form and also
pushes the event.

## A page without LiveView

On a page that a controller renders, the hook does not run. Import
`mountKoyomi` in the page's script and call it after the page loads:

```js
import { mountKoyomi } from "koyomi"

window.addEventListener("DOMContentLoaded", () => mountKoyomi())
```

`mountKoyomi(root)` mounts every picker under `root` (the document by
default), skips a picker it already mounted, and returns the pickers. The
pickers post with a plain HTML form, as they do in a LiveView. They have
no day content and no server events, and `on_change` pushes nothing.
Render them with `name` and `value`, or with a field of a form built with
`Phoenix.Component.to_form/2`:

```heex
<form method="get" action="/search">
  <label id="stay-label">Stay</label>
  <.date_range_picker name="stay" value={@params["stay"]} label_id="stay-label" />
  <button>Search</button>
</form>
```

## Values from the server

A picker takes the value of each render: the field's value, or `value`.
A changeset that changes the field, for example to clear it, changes the
picker.

To set a value that the form does not have yet, push it:

```elixir
socket = Koyomi.Live.push_value(socket, "booking_stay_picker", Date.range(~D[2027-03-06], ~D[2027-03-07]))
```

`Koyomi.Live.push_value/3` sends `koyomi:set` to the picker with that id.
The picker shows the value and posts it with the form, as if the person
had picked it: a `phx-change` follows. The value is a `Date`, a
`Date.Range`, a list of `Date`, a `Time`, a `DateTime`, a `NaiveDateTime`,
a `Koyomi.Recurrence`, an ISO string, or `nil` to clear it. For a month
or a week picker, give the ISO string (`"2027-03"`, `"2027-W11"`): a
`Date` is sent as a full date, which these pickers do not read.

The other pushes of `Koyomi.Live` are `open/2`, `close/2` and `focus/2`
for the popover and the focus, and `refresh_days/2` (see
[Day content](days.md)). Each carries the picker's id, so only that picker
acts on it.

## Echoes

A picker posts a value, the LiveView casts it, and the next render brings
the value back in `data-value`. The picker must not take back a value
that it posted itself, or a slow render would undo what the person typed
since. So:

* A rendered value equal to the picker's current value means the server
  is in step: nothing changes.
* A rendered value equal to one of the last eight values the picker
  posted is an echo, and the picker ignores it.
* Any other rendered value is the server's own, and the picker takes it,
  without posting it.

Values are compared in their wire form; a date and time with an offset
compares as an instant, so the server's UTC form of a posted local time
is an echo too.

So a render that sets the field back to a value that the person posted a
moment ago is ignored. To set such a value, use `push_value/3`. See
[Known limits](limits.md).

## A LiveComponent

In a LiveComponent, give `phx-target={@myself}`. The picker then sends its
events (`koyomi:days`, and the `on_change` event) to the component, and
the component must handle them:

```heex
<.date_picker field={@form[:due]} phx-target={@myself} days />
```

## More than one picker

Give each picker its own `id`, or let each take its field's id. Every
event from a picker has its `id`, and every server push names the picker,
so two pickers on a page do not act on the events of the other.
