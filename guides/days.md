# Day content

A picker can show what the LiveView knows about each day: a price, a
day that is full, a few marks for the bookings, a longer description for
screen readers, and the times that are free. The picker asks for the
days it shows, and the LiveView answers with a callback.

```heex
<.date_range_picker field={@form[:room]} label_id="room-label" days months={2} nights rules={[min: :today]} />
```

```elixir
def handle_event("koyomi:days", params, socket) do
  Koyomi.Live.handle_days(socket, params, &days/2)
end

# Called with the range of days and the id of the picker.
defp days(range, _id) do
  for room <- MyApp.Rooms.availability(range), into: %{} do
    {room.date, [label: "€#{room.price}", disabled: room.full?, marks: room.bookings]}
  end
end
```

## When the picker asks

With `days`, the picker pushes a `koyomi:days` event for the days that
its calendar shows: from the first day of the first grid to the last day
of the last one, so the outside days of the previous and next months are
included. A calendar on the page (`calendar/1`, or `inline`) asks when it
is shown; a popover asks when it opens. Each month that the person moves
to is a new request.

The picker keeps the days it has, and does not ask again for days it
has loaded. While a request is out, the calendar has `aria-busy="true"`.

The payload of the event is:

| Key | Value |
|---|---|
| `"id"` | the picker's id |
| `"from"`, `"to"` | the first and the last day, ISO 8601 |
| `"ref"` | the reference of the request, for the reply |
| `"timeZone"` | the picker's zone, or `nil` |

A page with several pickers gets one event for each. Match on the id to
give each picker its own callback:

```elixir
def handle_event("koyomi:days", %{"id" => "booking_slot_picker"} = params, socket),
  do: Koyomi.Live.handle_days(socket, params, &MyApp.Rooms.slots/2)

def handle_event("koyomi:days", params, socket),
  do: Koyomi.Live.handle_days(socket, params, &MyApp.Rooms.days/2)
```

In a LiveComponent, give the picker `phx-target={@myself}`: the event
then goes to the component's `handle_event/3`.

## Answering

`Koyomi.Live.handle_days/4` reads the payload, calls the callback with a
`Date.Range` and the picker's id, and returns the reply of the event,
`{:reply, map, socket}`. It is the whole `handle_event/3` clause.

The callback takes the range and the id, or only the range. It returns a
map from `Date` to the day, or a list of `{date, day}` tuples. A date may
also be an ISO 8601 string. Days that it leaves out have no content.

A payload without valid days, or a span of more than 800 days, gets a
reply with no days and the callback is not called. A callback that
raises replies with an error: the error is logged, and the picker says
"The days could not be loaded".

## The day

A day is one of:

* `:disabled` or `false`: the day may not be chosen.
* a string: a short label under the day's number.
* `true` or `nil`: no content.
* a keyword list or a map with these keys:

| Key | Value |
|---|---|
| `:label` | a short label under the day's number: a price, "Full" |
| `:title` | a longer description, shown on hover and read by screen readers: "3 rooms left" |
| `:tone` | `:accent`, `:success`, `:warning`, `:danger` or `:muted`, for the label and the day |
| `:marks` | dots under the number: a count (three at most), or a list of tones (the first three) |
| `:disabled` | `true` when the day may not be chosen |
| `:slots` | the times that may be chosen on the day, for a date and time picker with `slots` (see below) |

For example, from the dev app's fake availability service:

```elixir
cond do
  Date.day_of_week(date) == 3 ->
    {date, [disabled: true, label: "Full", tone: :danger, title: "No rooms left"]}

  rem(date.day, 5) == 0 ->
    {date, [label: "€#{price}", tone: :success, marks: [:warning], title: "2 rooms left, €#{price}"]}

  true ->
    {date, [label: "€#{price}", title: "€#{price} a night"]}
end
```

The tone is in the day's `data-tone` attribute, and each mark is a
`koyomi-mark` with its own `data-tone`, for the theme to style. A screen
reader reads the date, the holiday, the title (or the label when there is
no title) and "Unavailable" for a disabled day. A holiday's name takes
the place of the title on hover.

An unknown tone raises `ArgumentError`. `Koyomi.Live.normalize_days/2`
shows what the picker receives:

```elixir
Koyomi.Live.normalize_days(%{~D[2027-03-15] => [label: "€90", marks: 2]})
#=> %{"2027-03-15" => %{"label" => "€90", "marks" => ["accent", "accent"]}}
```

### Disabled days on the server

A day disabled in the day content is disabled in the browser: the
calendar refuses it, and a range cannot hold it unless the rules have
`allow_disabled_in_range: true`. `Koyomi.Rules` does not know these days,
so check them in the changeset with your own validation:

```elixir
def changeset(booking, attrs) do
  booking
  |> cast(attrs, [:room])
  |> validate_required([:room])
  |> Koyomi.Changeset.validate_range(:room, @room_rules)
  |> validate_change(:room, fn :room, range ->
    case Enum.find(range, &MyApp.Rooms.full?/1) do
      nil -> []
      date -> [room: "includes a full night (#{date})"]
    end
  end)
end
```

## A slow callback

With `async: true`, the callback runs in a task of the LiveView
(`Phoenix.LiveView.start_async/3`), and the reply tells the picker that
the days will come. Give the result to `Koyomi.Live.handle_days_async/3`
in `handle_async/3`, which pushes the days to the picker:

```elixir
def handle_event("koyomi:days", params, socket) do
  Koyomi.Live.handle_days(socket, params, &days/2, async: true)
end

def handle_async({:koyomi_days, _id, _ref} = name, result, socket) do
  {:noreply, Koyomi.Live.handle_days_async(socket, name, result)}
end
```

The task's name is `{:koyomi_days, id, ref}`, one for each request. A
task that fails is logged, and the picker says that the days could not
be loaded.

## Time slots

```heex
<.datetime_picker field={@form[:slot]} label_id="slot-label" slots time_zone="Europe/Lisbon" rules={[min: :today]} />
```

With `slots`, the date and time picker asks for the days as `days` does,
and its time list shows the slots of the chosen day instead of a time
every `:step` minutes. The day's `:slots` are a list of:

* `Time`: a wall clock time in the picker's zone;
* `DateTime`: shifted to the picker's zone;
* `NaiveDateTime`: its time of day;
* a keyword list or a map with `:time` (one of the above), `:label` (the
  text in the list, instead of the time in the locale's format) and
  `:disabled` (`true` shows the slot and refuses it).

```elixir
def slots(range, _id) do
  Map.new(range, fn date ->
    if Date.day_of_week(date) in [6, 7] do
      {date, [slots: []]}
    else
      slots =
        for hour <- 9..16, minute <- [0, 30] do
          %{time: Time.new!(hour, minute, 0), disabled: MyApp.Calendar.booked?(date, hour, minute)}
        end

      {date, [slots: slots, marks: 1]}
    end
  end)
end
```

A day with `slots: []`, or a loaded day with no slots, shows "No times
are free on this day"; a day that is still loading shows "Loading…".
Slots before `:min_time` or after `:max_time` are refused.

The person can still type any time in the field's segments: the slots
are a help in the browser, as disabled days are. Check the time on the
server.

## When the days change

When the days change on the server (someone else books a room), call
`Koyomi.Live.refresh_days/2` with the picker's id. The picker forgets the
days it has and asks again for those it shows; a closed popover asks when
it next opens.

```elixir
def handle_info({:booked, _booking}, socket) do
  {:noreply, Koyomi.Live.refresh_days(socket, "booking_room_picker")}
end
```

## Driving a picker from the server

`Koyomi.Live` has a few more pushes, each for one picker, by its id:

| Function | Does |
|---|---|
| `push_value/3` | sets the value as if the person had picked it: the picker shows it and posts it with the form, and a `phx-change` follows |
| `open/2` | opens the popover |
| `close/2` | closes the popover |
| `focus/2` | moves the focus to the field |

```elixir
def handle_event("next_weekend", _params, socket) do
  saturday = Date.add(Date.utc_today(), rem(6 - Date.day_of_week(Date.utc_today()) + 7, 7))
  range = Date.range(saturday, Date.add(saturday, 1))
  {:noreply, Koyomi.Live.push_value(socket, "booking_room_picker", range)}
end
```

`push_value/3` takes a `Date`, a `Date.Range`, a list of `Date`, a
`Time`, a `DateTime`, a `NaiveDateTime`, a `Koyomi.Recurrence`, an ISO
string, or `nil` to clear the picker. A picker also takes a new `value`
(or field value) in a later render; `push_value/3` is for a value that
the form does not have yet.

The id of a picker with a `field` is the field's id with `_picker`:
`booking_room_picker` for `@form[:room]` of a form `as: :booking`.

## A complete example

`dev.exs` in the Koyomi repository has a page of day content:
`KoyomiDev.Rooms` is a fake availability service (prices, a full day each
week, marks and slots, and a slow answer), and `KoyomiDev.DaysLive` shows
a range picker, a slow range picker with `async: true`, a date and time
picker with slots, and a calendar of bookings, with buttons that refresh
the days, set a value and open a picker. Run it with `mix dev`.
