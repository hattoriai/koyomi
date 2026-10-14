# Recurrence

The recurrence picker chooses how something repeats: every so many days,
weeks, months or years, on which weekdays or which day of the month, and
until when. It posts a recurrence rule of RFC 5545 (iCalendar), and
`Koyomi.Recurrence` reads it on the server, lists its dates and writes it
out in words.

```heex
<.recurrence_picker field={@form[:repeat]} label_id="repeat-label" start={@event.starts_on} />
```

```elixir
schema "events" do
  field :starts_on, :date
  field :repeat, Koyomi.Recurrence
end
```

## The picker

The field shows the rule in a sentence ("Weekly on Monday and
Wednesday"), or "Does not repeat". Its popover has:

* Repeat: does not repeat, daily, weekly, monthly or yearly.
* Every: the interval, 1 to 999, with its unit ("2 weeks").
* For a weekly rule, a button for each weekday, in the order of the
  locale's week. A weekly rule keeps one weekday at least.
* For a monthly rule, a choice between the day of the month of the start
  ("On day 15") and its weekday in the month ("On the third Monday", or
  "On the last Friday" when the start is in the last week of its month).
* Ends: never, after a number of times (10 at first), or on a day (90
  days after the start at first), picked on a calendar that opens below
  the choices. The days before the start are disabled.
* The rule in a sentence, and the next five dates.

A new weekly rule takes the weekday of the start. A monthly rule takes
the day of the month of the start, and a yearly rule its day and month,
as the rule leaves them out (see [The dates](#the-dates)).

| Attribute | Default | Use |
|---|---|---|
| `start` | today | the first occurrence: a `Date`, `DateTime` or `NaiveDateTime`, of which the picker uses the day |

`start` is not posted: keep it in its own field, such as a date picker
beside the recurrence picker. The picker reads it in each render, so a
new start reaches the sentence and the next dates. It takes a struct,
not a string: to follow a date field while the form changes, give it the
field's value cast to a `Date`, such as
`Ecto.Changeset.get_field(changeset, :starts_on)`.

The picker posts the rule text, `FREQ=WEEKLY;BYDAY=MO,WE`, and an empty
string for "does not repeat". A rule from the server can have parts
that the popover does not show (a `BYSETPOS`, several days of the
month): the popover keeps them while the person changes the interval or
the end, and the sentence and the dates follow the whole rule.

## The Ecto type

`Koyomi.Recurrence` is an `Ecto.Type`, stored as the rule text in a
string column:

```elixir
# The migration
add :repeat, :string
```

`cast/1` takes the text or a struct. An empty string casts to `nil`, and
a rule that does not parse gives the changeset a cast error with the
reason as its message, such as "FREQ=HOURLY is not supported". A text in
the column that does not parse fails to load.

The column holds the rule's canonical text (see below), so one rule is
always stored the same way.

## Rules in code

`parse/1` reads a rule text, and `parse!/1` raises `ArgumentError` when
it cannot:

```elixir
{:ok, rule} = Koyomi.Recurrence.parse("RRULE:FREQ=WEEKLY;BYDAY=WE,MO;COUNT=4")
to_string(rule)
#=> "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4"

Koyomi.Recurrence.parse("FREQ=DAILY;BYHOUR=9")
#=> {:error, "BYHOUR is not supported"}
```

`new/1` builds a rule from the fields of the struct, with the same
checks. `:by_day` also takes bare weekdays, 1 (Monday) to 7 (Sunday), and
`:until` a `DateTime` in any zone, which is shifted to UTC:

```elixir
{:ok, rule} = Koyomi.Recurrence.new(freq: :weekly, interval: 2, by_day: [3, 1])
to_string(rule)
#=> "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE"

Koyomi.Recurrence.new(freq: :weekly, by_month_day: [1])
#=> {:error, "BYMONTHDAY cannot be used with FREQ=WEEKLY"}
```

A `Koyomi.Recurrence` struct has:

| Field | Value |
|---|---|
| `:freq` | `:daily`, `:weekly`, `:monthly` or `:yearly` |
| `:interval` | the periods between two periods with occurrences, `1` by default |
| `:count` | the number of occurrences, the start included, or `nil` |
| `:until` | the last day (a `Date`) or instant (a `DateTime` in UTC), inclusive, or `nil` |
| `:by_day` | `{ordinal, weekday}` tuples: the weekday 1 to 7, the ordinal `nil` for every such day, or a position (`1` the first, `-1` the last) |
| `:by_month_day` | days of the month, `1` to `31` or `-1` (the last) to `-31` |
| `:by_month` | months, `1` to `12` |
| `:by_set_pos` | positions in the days of each period, `1` to `366` or `-1` to `-366` |
| `:week_start` | the first day of the week, `1` (Monday, the default) to `7` |

The lists are sorted and without duplicates. `to_string/1` (and
`String.Chars`) writes the parts in one order: `FREQ`, `INTERVAL` (left
out when 1), `BYMONTH`, `BYMONTHDAY`, `BYDAY`, `BYSETPOS`, `WKST` (left
out when Monday), then `COUNT` or `UNTIL`.

## The supported rules

Koyomi reads a subset of the RFC 5545 `RRULE`, for rules of whole days:

| Part | Values |
|---|---|
| `FREQ` | `DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY` |
| `INTERVAL` | a positive whole number |
| `COUNT` | a positive whole number |
| `UNTIL` | a date, `20271231`, or a UTC date and time, `20271231T235959Z` |
| `BYDAY` | `MO` to `SU`; with an ordinal (`1MO`, `-1FR`) in a monthly rule (up to 5) or a yearly one (up to 53) |
| `BYMONTHDAY` | `1` to `31`, `-1` to `-31` |
| `BYMONTH` | `1` to `12` |
| `BYSETPOS` | `1` to `366`, `-1` to `-366` |
| `WKST` | `MO` to `SU` |

The parts come in any order and any case, with or without a leading
`RRULE:`. These are errors, each with a message that names the part:

* any other part (`BYHOUR`, `BYWEEKNO`, `BYYEARDAY`) and the other
  frequencies (`HOURLY` and shorter);
* a part given twice, or with no value;
* `COUNT` with `UNTIL`;
* `BYMONTHDAY` in a weekly rule;
* `BYDAY` with an ordinal in a daily or weekly rule;
* `BYSETPOS` without `BYDAY`, `BYMONTHDAY` or `BYMONTH`;
* a rule without `FREQ`.

The browser module (`rrule.ts`) parses, writes and expands the same
rules with the same messages, so the picker and the server agree.

## The dates

`occurrences/3` gives the dates of a rule from a start, as a lazy stream
of the start's type: `Date`, `NaiveDateTime` or `DateTime`.

```elixir
rule = Koyomi.Recurrence.parse!("FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4")

rule |> Koyomi.Recurrence.occurrences(~D[2027-03-15]) |> Enum.to_list()
#=> [~D[2027-03-15], ~D[2027-03-17], ~D[2027-03-22], ~D[2027-03-24]]
```

A rule without `COUNT` or `UNTIL` never ends: take what you need from the
stream (`Enum.take/2`), or use `between/5`, which lists the dates whose
day falls between two dates, both included:

```elixir
Koyomi.Recurrence.parse!("FREQ=YEARLY")
|> Koyomi.Recurrence.between(~D[2024-02-29], ~D[2025-01-01], ~D[2032-12-31])
#=> [~D[2028-02-29], ~D[2032-02-29]]
```

The dates follow RFC 5545:

* The start is `DTSTART`. It is always the first date, even when it does
  not match the rule, and `COUNT` counts it: `FREQ=WEEKLY;BYDAY=WE;COUNT=3`
  from Monday 15 March 2027 gives the 15th, the 17th and the 24th.
* A part that the rule leaves out comes from the start: the weekday of a
  weekly rule, the day of the month of a monthly rule, and the day and
  month of a yearly one. A monthly rule that starts on the 31st skips the
  months without one, and a yearly rule from 29 February gives only the
  leap years, as the example above shows.
* Each `BY` part expands or limits the days of a period as the RFC's
  table says: `BYMONTH` expands a yearly rule and limits the others;
  `BYMONTHDAY` expands a monthly or yearly rule and limits a daily one;
  `BYDAY` expands a weekly, monthly or yearly rule, unless `BYMONTHDAY` is
  there, and then limits it.
* An ordinal of `BYDAY` counts in the month for a monthly rule, and for a
  yearly rule with `BYMONTH`; in the year otherwise.
* `BYSETPOS` then picks from the sorted days of each period:
  `FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1` is the last weekday of
  each month.
* `WKST` changes which days fall in a week, so it matters for a weekly
  rule with an interval above one, or with `BYSETPOS`.
* `UNTIL` is inclusive. A date `UNTIL` ends on that day, whatever the
  time. A UTC `UNTIL` compares with the instant of a `DateTime`, with the
  wall clock of a `NaiveDateTime` (taken as UTC), and with the day of a
  `Date`.
* A rule that stops giving dates (`BYMONTH=2;BYMONTHDAY=30`) ends after
  400 years without one, or at the year 9999.

Each date after the start has the start's time of day:

```elixir
Koyomi.Recurrence.parse!("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3")
|> Koyomi.Recurrence.occurrences(~N[2027-01-29 09:30:00])
|> Enum.to_list()
#=> [~N[2027-01-29 09:30:00], ~N[2027-02-26 09:30:00], ~N[2027-03-31 09:30:00]]
```

For a `DateTime`, it is the wall clock time in the start's zone: 09:30 in
Lisbon stays 09:30 when the clocks change. A time that the clocks skip
moves forward by the length of the gap, and a time that happens twice
takes the first instant. The option `:time_zone_database` names the
database (`Calendar.get_time_zone_database/0` by default); a start in a
zone other than UTC needs one (see [Time zones](time_zones.md)).

## In words

`describe/3` writes the rule in a sentence, the same as the picker's:

```elixir
rule = Koyomi.Recurrence.parse!("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10")

Koyomi.Recurrence.describe(rule)
#=> "Every 2 weeks on Monday and Wednesday, 10 times"

Koyomi.Recurrence.describe(rule, "pt-PT")
#=> "A cada 2 semanas à segunda-feira e à quarta-feira, 10 vezes"
```

The languages are English, European Portuguese, Spanish, French, German,
Italian, Dutch and Japanese. A locale with a region (`"pt-BR"`, `"en_GB"`)
takes its language, and another language gets English.

With `:start`, the sentence names the days that the rule takes from the
start:

```elixir
Koyomi.Recurrence.parse!("FREQ=YEARLY;UNTIL=20271231")
|> Koyomi.Recurrence.describe("en", start: ~D[2026-03-15])
#=> "Every year on 15 March until 31 December 2027"
```
