# Pickers

`Koyomi.Components` has ten function components. Each one is a form
field: it posts its value with the form, in the form of the browser's own
inputs, and an Ecto type casts it.

| Component | Picks | Posts | Ecto type |
|---|---|---|---|
| `date_picker/1` | a day | `2027-03-15` | `:date` |
| `date_range_picker/1` | a range of days | `field[from]`, `field[to]` | `Koyomi.DateRange`, or two `:date` fields |
| `dates_picker/1` | several days | `field[]`, one entry per day | `Koyomi.Dates` |
| `month_picker/1` | a month | `2027-03` | `Koyomi.Month` |
| `year_picker/1` | a year | `2027` | `:integer` |
| `week_picker/1` | an ISO week | `2027-W11` | `Koyomi.Week` |
| `time_picker/1` | a time of day | `14:30:00` | `:time` |
| `datetime_picker/1` | a day and a time | `2027-03-15T14:30:00+01:00`, or `2027-03-15T14:30:00` without a zone | `:utc_datetime`, or `:naive_datetime` |
| `recurrence_picker/1` | a repeat rule | `FREQ=WEEKLY;BYDAY=MO,WE` | `Koyomi.Recurrence` |
| `calendar/1` | nothing, a day, a range or several days | only with a `name` | as the picker of the same selection |

A cleared picker posts an empty string (`field[from]` and `field[to]`
empty for a range, only the empty first entry for several days). The
[Forms](forms.md) guide has the details.

## Date

```heex
<.date_picker field={@form[:due]} label_id="due-label" min={:today} />
```

A field with a segment for each part of the date, in the order of the
locale, and a calendar in a popover. The segments are typed, or changed
with the arrow keys (see [Typing dates](typing.md)). A click on a day
picks it and closes the popover.

## Date range

```heex
<.date_range_picker field={@form[:stay]} label_id="stay-label" months={2} nights />
```

Two date fields, the first and the last day, and a calendar where the
first click starts the range and the second ends it. The range is drawn
as the pointer moves. While the second day is chosen, the days that the
range could not reach from its first day are disabled.

The picker posts only whole ranges: while one end is chosen, the form
keeps the previous value. A range left half chosen when the popover
closes is dropped.

Its own attributes:

| Attribute | Default | Use |
|---|---|---|
| `from`, `to` | `nil` | two `:date` fields instead of `field`; the picker posts each one with its own name |
| `nights` | `false` | count nights (days minus one) in the text of the range, as for a stay |

The rules `:min_days`, `:max_days` and `:allow_disabled_in_range` apply
to the range.

## Several days

```heex
<.dates_picker field={@form[:days_off]} label_id="days-off-label" rules={[max_count: 5]} />
```

Each click adds or removes a day. The field lists the days as chips, each
with a button to remove it. The popover stays open while days are added;
Done, Escape or a press outside closes it.
The rules `:min_count` and `:max_count` apply (the browser checks only
`:max_count`: see [Known limits](limits.md)).

## Month, year and week

```heex
<.month_picker field={@form[:billing_month]} label_id="month-label" />
<.year_picker field={@form[:year]} label_id="year-label" />
<.week_picker field={@form[:sprint]} label_id="sprint-label" />
```

* The month picker has a field with the month and the year, and a grid of
  the twelve months of a year. `Koyomi.Month` stores the first day of the
  month in a `:date` column.
* The year picker has a field with the year, and a grid of twelve years.
  It posts the year as an integer.
* The week picker has a field with the week number and its year, and a
  calendar with week numbers, where a click picks the whole week. Its
  weeks always start on Monday. `Koyomi.Week` stores the Monday of the
  week in a `:date` column; `Koyomi.ISOWeek` gives the week number of a
  date.

## Time

```heex
<.time_picker field={@form[:at]} label_id="at-label" rules={[min_time: ~T[09:00:00], max_time: ~T[17:00:00], step: 15]} />
```

A field with the hour and the minutes, in the 12 or 24-hour clock of the
locale, and a list of times in a popover. It always posts seconds
(`14:30:00`). The list has a time every `:step` minutes of the rules, or
every 30 minutes without a step, from `:min_time` (or midnight) to
`:max_time` (or the end of the day). The Now button picks the current
time.

| Attribute | Default | Use |
|---|---|---|
| `seconds` | `false` | the field has a seconds segment |
| `hour_cycle` | the locale's | `"h12"` or `"h23"` |

## Date and time

```heex
<.datetime_picker field={@form[:starts_at]} label_id="starts-label" time_zone="Europe/Lisbon" />
```

The date field and calendar of the date picker, with the time field and
list of the time picker. With a `time_zone`, the person picks a wall clock
time in that zone, and the picker posts it with the zone's offset at that
moment, for a `:utc_datetime` field. Without one, it posts a date and
time with no offset, for a `:naive_datetime` field. The
[Time zones](time_zones.md) guide has the details.

| Attribute | Default | Use |
|---|---|---|
| `seconds` | `false` | the field has a seconds segment |
| `hour_cycle` | the locale's | `"h12"` or `"h23"` |
| `slots` | `false` | the times of a day are the slots that the LiveView gives (see [Day content](days.md)); the picker also asks for the days |
| `ambiguous` | `:earlier` | `:earlier` or `:later`, the instant of a wall clock time that happens twice (see [Known limits](limits.md)) |

## Recurrence

```heex
<.recurrence_picker field={@form[:repeat]} label_id="repeat-label" start={@event.starts_on} />
```

How often something repeats, every so many days, weeks, months or years,
on which weekdays or which day of the month, and until when. The panel
writes the rule out in a sentence and lists the next five dates. The
[Recurrence](recurrence.md) guide has the details.

| Attribute | Default | Use |
|---|---|---|
| `start` | today | the first occurrence, a `Date`, `DateTime` or `NaiveDateTime`, for the weekday and day of the month that a new rule takes, the sentence and the next dates |

## Calendar

```heex
<.calendar id="bookings" days holidays={["PT", "GB"]} months={2} />
<.calendar id="pick-a-day" select="date" on_change="day_picked" />
```

A calendar on the page, with no field and no popover: to show days and
their content, and to pick one or more outside a form.

| Attribute | Default | Use |
|---|---|---|
| `select` | `nil` | what a click picks: `"date"`, `"range"` or `"dates"`; nothing by default |

With `on_change`, each pick pushes that event to the LiveView. With a
`name`, the calendar also posts the value in a hidden input: a date, a
range as `2027-03-01/2027-03-07`, or several days separated by commas.
`Koyomi.DateRange` and `Koyomi.Dates` cast these forms too.

## The shared attributes

Every picker has these attributes.

| Attribute | Default | Use |
|---|---|---|
| `field` | `nil` | the form field, for example `@form[:due]` |
| `id` | the field's id with `_picker` | the id of the picker element; a picker with no `field` needs an `id` or a `name` |
| `name` | the field's name | the input name, without a `field` |
| `value` | the field's value | the value, without a `field` |
| `label_id` | `nil` | the id of the element that labels the picker (`aria-labelledby`) |
| `label` | the field name in words | the accessible name when there is no `label_id` (`aria-label`) |
| `rules` | `nil` | a `Koyomi.Rules`, or its options as a keyword list; give the same to `Koyomi.Changeset` |
| `min`, `max` | `nil` | shortcuts for the `:min` and `:max` rules; they replace the ones in `rules` |
| `locale` | `config :koyomi, locale:`, else `"en"` | a BCP 47 locale for names, digits, the order of the fields and the first day of the week |
| `calendar` | `"gregory"` | the calendar system of the display (see [Locales and calendars](calendars.md)) |
| `time_zone` | `config :koyomi, time_zone:`, else UTC | the IANA time zone of today and, for a date and time picker, of the wall clock |
| `first_day` | the locale's | the first day of the week, ISO: 1 is Monday, 7 is Sunday |
| `presets` | `nil` | the presets beside the calendar (see `Koyomi.Presets`) |
| `holidays` | `nil` | public holidays to mark: a country code (`"PT"`), a `Koyomi.Holidays.Provider` module, or a list of them |
| `days` | `false` | ask the LiveView for the content of the days shown (see [Day content](days.md)) |
| `inline` | `false` | always show the calendar, with no field and no popover |
| `months` | `1` | the months shown side by side, 1 to 12 |
| `week_numbers` | `false` | show ISO week numbers (always on in the week picker) |
| `outside_days` | `true` | `false` leaves the days of the previous and next months blank |
| `typing` | `true` | `false` leaves out the box for typing a date in words |
| `clearable` | `true` unless `required` | a clear button in the field, and Clear in the popover |
| `required` | `false` | `required` on the browser's own inputs |
| `disabled` | `false` | the picker cannot be focused or changed |
| `readonly` | `false` | the picker shows its value and cannot be changed |
| `display` | `"medium"` | `short`, `medium`, `long` or `full`; the 0.1 bundle does not read it yet (see [Known limits](limits.md)) |
| `on_change` | `nil` | an event that the picker pushes with `%{"id" => id, "value" => value}` on each change |
| `messages` | `nil` | words that replace the built-in ones (see `Koyomi.Messages`) |
| `class` | `nil` | classes for the picker element |

Other attributes go on the picker element, such as `phx-target` in a
LiveComponent and `form`. `aria-describedby` and `aria-invalid` go to the
field's segments instead (see the [Forms](forms.md) guide).

A change of an attribute in a later render reaches the picker: it builds
its field and panel again and keeps its value.

## Presets

```heex
<.date_range_picker field={@form[:period]} presets={[{:last, 7, :days}, :this_month, :year_to_date]} />
<.date_picker field={@form[:due]} presets={[:today, :tomorrow, {:in, 1, :week}, {:in, 1, :month}]} />
```

Presets are buttons beside the calendar. The server computes each value
from today in the picker's zone, and the browser labels the built-in ones
in the picker's locale ("Next week", "In 30 days", "Hoje"). A preset that
the rules refuse is disabled. `Koyomi.Presets` lists them.

Presets show in the date, range, several days, date and time pickers and
the calendar. In a date picker, a range preset gives its first day; in a
range picker, a day preset gives a range of one day. The week presets
(`:this_week`, `:next_week`, `:last_week`) start on `first_day`, or on
Monday when the picker has none.

## The words

Month names, weekday names, numbers and dates come from the browser
(`Intl`), in any locale. The other words (button labels, hints,
announcements, messages) are in `Koyomi.Messages`, in English,
Portuguese, Spanish, French, German, Italian, Dutch and Japanese. A
locale with a region (`pt-BR`) takes the words of its language, and
another language gets English. Replace words for one picker with
`messages`, or for every picker in the config:

```heex
<.date_picker field={@form[:due]} messages={%{"today" => gettext("Today")}} />
```

```elixir
config :koyomi, messages: %{"fr" => %{"today" => "Aujourd'hui"}}
```

An unknown key raises `ArgumentError`, so that a typo shows. The keys are
in `Koyomi.Messages.keys/0`.
