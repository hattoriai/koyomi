# Time zones

A time zone matters to a picker in two places: which day is today, and,
for a date and time picker, which instant a wall clock time is. Koyomi
takes IANA zone names, such as `"Europe/Lisbon"` or `"America/New_York"`.

## Today in a zone

`:today` in the rules, the presets, and the day that the calendar marks
as today, are today in a zone. In the rules it is the `:time_zone`
option, `"Etc/UTC"` by default:

```elixir
@rules Koyomi.Rules.new(min: :today, time_zone: "Pacific/Auckland")

# The date in Auckland now, which can be a day ahead of UTC
Koyomi.Rules.today(@rules)
```

In a picker it is the `time_zone` attribute, else
`config :koyomi, time_zone:`, else the zone of its rules:

```heex
<.date_picker field={@form[:due]} min={:today} time_zone="Pacific/Auckland" />
```

```elixir
# config/config.exs
config :koyomi, time_zone: "Europe/Lisbon"
```

The picker's zone replaces the zone of its rules, but only in the
picker. Give the rules of the changeset the same `:time_zone`, so that
both read the same today. Late in the evening in Lisbon, Auckland is
already on the next day, and a `min: :today` read in UTC would refuse the
day that the picker offered.

The server resolves today and gives it to the browser, so the browser's
clock and zone do not change it.

## The date and time picker

```heex
<.datetime_picker field={@form[:starts_at]} label_id="starts-label" time_zone="Europe/Lisbon" />
```

With a time zone, the person picks a wall clock time in that zone, and
the picker posts it with the zone's offset at that moment:

| Picked in `Europe/Lisbon` | Posted |
|---|---|
| 15 January 2027, 14:30 | `2027-01-15T14:30:00Z` |
| 15 July 2027, 14:30 | `2027-07-15T14:30:00+01:00` |

The browser writes an offset of zero as `Z`. A `:utc_datetime` field
casts either form to UTC on its own:

```elixir
schema "events" do
  field :starts_at, :utc_datetime
end
```

The value from the server can be a `DateTime` in any zone: the picker
shows its wall clock time in the picker's zone. `2027-07-15 13:30:00Z`
shows as 14:30 in Lisbon.

Without a time zone (no `time_zone` attribute and no
`config :koyomi, time_zone:`), the picker posts the date and time with
no offset (`2027-07-15T14:30:00`), for a `:naive_datetime` field. With a
zone in the config, every date and time picker posts offsets; there is
no attribute to turn them off for one picker.

The zone is not shown in the field. Say it in the label when the person
may not expect it:

```heex
<label id="starts-label">Starts (Lisbon time)</label>
```

## When the clocks change

On the day the clocks go forward, an hour of wall clock time does not
happen. On the day they go back, an hour happens twice. The picker shows
a notice under the calendar and the time list when the person picks
such a time.

### A time that is skipped

In Lisbon, on 28 March 2027, the clocks go from 01:00 to 02:00. A time
between them does not exist. The notice says so, and the time it
becomes:

> 01:30 is skipped on this day in Europe/Lisbon, when the clocks go
> forward. It becomes 02:30.

The time moves forward by the length of the gap, as `Temporal` and
`java.time` do, and the picker posts the moved time with its offset
(`2027-03-28T02:30:00+01:00`).

### A time that happens twice

On 31 October 2027, the clocks go from 02:00 back to 01:00, and 01:30
happens twice: first at `+01:00`, then at `Z`. The notice says so, and
has a button for each instant, with its offset:

> 01:30 happens twice on this day in Europe/Lisbon, when the clocks go
> back.
>
> [The first (GMT+1)] [The second (GMT)]

A time that the person picks takes the instant that the `ambiguous`
attribute names (`:earlier`, the default, or `:later`) until they press
the other button. The picker posts the chosen one with its offset.

A value from the server names its own instant, and the picker selects
the button that matches it.

The words of the notice are in `Koyomi.Messages` (`gap`, `ambiguous`,
`earlier` and `later`), and can be replaced like the others.

## Casting a wall clock time

Before the hook mounts, and with JavaScript off, the date and time
picker is the browser's own `datetime-local` input, which posts no
offset (`2027-07-15T14:30`). The component fills it with the wall clock
time in the picker's zone. To read that value, or any date and time
without an offset, as a wall clock time in a zone, cast the field with
`Koyomi.Changeset.cast_datetime/5` instead of `cast/4`:

```elixir
def changeset(event, attrs) do
  event
  |> cast(attrs, [:name])
  |> Koyomi.Changeset.cast_datetime(attrs, :starts_at, "Europe/Lisbon")
  |> validate_required([:name, :starts_at])
end
```

`cast_datetime/5` reads:

* a string with an offset, as the picker posts it: the instant it names;
* a string without an offset (`2027-07-15T14:30:00` or
  `2027-07-15T14:30`): the wall clock time in the zone;
* a `DateTime`: shifted to UTC;
* `nil` or `""`: the field is cleared.

Anything else gets the error "is invalid". A field that the params do not
have is left as it is. `params` may have string or atom keys.

Use it with a `:utc_datetime` field, which gets the instant in UTC
(`:utc_datetime_usec` keeps the microseconds). For a `:naive_datetime`
field, a value without an offset is stored as the wall clock time in the
zone.

A wall clock time without an offset can fall on a change of the clocks.
A time that the zone skips gets the error `:gap`, "does not exist in
Europe/Lisbon (the clocks change)". A time that happens twice takes the
first instant, unless the option `:ambiguous` says otherwise:

```elixir
# The second instant
Koyomi.Changeset.cast_datetime(changeset, attrs, :starts_at, "Europe/Lisbon", ambiguous: :later)

# The error :ambiguous, "happens twice in Europe/Lisbon (the clocks change)"
Koyomi.Changeset.cast_datetime(changeset, attrs, :starts_at, "Europe/Lisbon", ambiguous: :error)
```

The option `:message` replaces the messages of these errors, as in the
other functions of `Koyomi.Changeset` (see [Rules](rules.md)).

## Checking a date and time

`Koyomi.Changeset.validate_datetime/4` reads a `DateTime` in the zone of
the rules: its day and its time of day are those of the wall clock
there. Give the rules the picker's zone:

```elixir
@rules Koyomi.Rules.new(min: :today, min_time: ~T[09:00:00], max_time: ~T[18:00:00], time_zone: "Europe/Lisbon")

event
|> Koyomi.Changeset.cast_datetime(attrs, :starts_at, "Europe/Lisbon")
|> Koyomi.Changeset.validate_datetime(:starts_at, @rules)
```

A `:min` or `:max` that is a `DateTime` is compared as an instant.

## The time zone database

Elixir knows only UTC without a time zone database. A picker or rules
with another zone need one on the server, such as
[`tz`](https://hex.pm/packages/tz) or
[`tzdata`](https://hex.pm/packages/tzdata):

```elixir
# mix.exs
{:tz, "~> 0.28"}

# config/config.exs
config :elixir, :time_zone_database, Tz.TimeZoneDatabase
```

Without one, `Koyomi.Rules.today/1` raises `ArgumentError` for a zone
other than `"Etc/UTC"` or `"UTC"`, and so does a picker that resolves
today in it. `cast_datetime/5` raises for a value without an offset
in such a zone.

The browser has its own copy of the zones, in `Intl`, and uses it for
the offsets of the date and time picker. The two copies can differ for a
short time after a country changes its rules: keep the database
package up to date.
