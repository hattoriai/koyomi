# Known limits

These are the known limits of Koyomi 0.1.

## Browsers

The browser tests run in Chromium, Firefox and WebKit (the engine of
Safari), with the Playwright versions of these browsers, as desktop
browsers, in the `en-GB` locale and the `Europe/Lisbon` time zone. They
do not run in Safari on macOS or iOS, in a mobile browser, or with a
screen reader.

## Weeks without `Intl` week data

The first day of the week, the weekend and the first week of the year
come from `Intl.Locale`'s week info (`getWeekInfo()`, or `weekInfo` in
older engines). An engine without either uses a table built into the
bundle, by region, from the CLDR data. The table may differ from a newer
CLDR in a few regions. A locale with `-u-fw-` sets the first day in both
cases, and the `first_day` attribute replaces it.

A week picker always starts its weeks on Monday, and every week number
is an ISO 8601 week, whatever the locale.

## Calendar systems

* A picker in the Japanese calendar shows Japanese era years in the
  calendar and in its labels, but its segments take Gregorian numbers:
  the year is typed as `2027`, not as Reiwa 9.
* The month, week and year pickers use Gregorian months and years. A
  `calendar` other than Gregorian, ISO, Japanese, Buddhist or ROC is
  replaced by the Gregorian calendar in these pickers.
* The other calendars (Hebrew, Chinese, Islamic, Persian and so on) read
  their months from `Intl`. Where the browser has `Temporal`, the picker
  uses it to turn a typed date into a day; without it, the picker finds
  the day by a search through `Intl`, which gives the same days more
  slowly. `Temporal` is used only when the browser has it: the bundle has
  no polyfill.
* A calendar that the browser cannot format falls back to Gregorian.

The value that a picker posts is always an ISO 8601 date, whatever the
calendar it shows.

## Plain words

The typing box reads words in English, Portuguese, Spanish, French,
German, Italian, Dutch and Japanese. A locale in another language reads
English words, the locale's own month and weekday names (from `Intl`),
and numeric dates in the locale's order. ASCII and full-width digits are
read; other digits, such as Arabic-Indic, are read in the segments but
not in the typing box. See the [Typing dates](typing.md) guide.

## Holidays

`Koyomi.Holidays` lists national public holidays, computed by rule, for
the countries of `Koyomi.Holidays.countries/0`. Regional, local and
religious days that only some people keep are not listed, nor are days
off by custom. The rules are those in force in 2026: changes since 2010
are followed, and earlier years follow the rules of 2010. One-off
holidays are not listed. For the days off of a region or a business,
write a `Koyomi.Holidays.Provider`.

A picker gives the browser the holidays of a span of years: from the
year of `:min` (else two years before today) to the year of `:max` (else
three years after), and never more than ten years from today. Days
outside that span show no holidays.

## Day content

One `koyomi:days` event asks for at most 800 days. `Koyomi.Live.handle_days/4`
answers a longer span with no days, and does not call the callback.

A picker asks only for the days it shows that it has not asked for yet,
in spans of at most a year.

Days disabled in the day content are disabled only in the browser.
Check them in the changeset with your own validation.

## A value posted is a value whole

A picker posts only a value that it can read as a whole. A range posts
when both of its ends are chosen; until then, the form keeps the
previous value, and a range left half chosen when the popover closes is
dropped. A date typed in segments posts when every segment has a value,
or when every segment is empty. See the [Forms](forms.md) guide.

## Echoes of posted values

A picker ignores a rendered value that equals one of the last eight
values it posted, so that a slow render cannot undo what the person
typed since. This list is cleared when a render brings the picker's
current value. So a render that sets the field back to a value that the
person posted a moment ago, for example after an undo in the LiveView,
does not change the picker. Push such a value with
`Koyomi.Live.push_value/3`, which the picker always takes. See the
[Forms](forms.md) guide.

## Rules checked only on the server

Two rules are checked only by the changeset:

* `:min_count`: the several days picker lets the person choose fewer
  days, and the changeset refuses them.
* The time of day of a `DateTime` or `NaiveDateTime` bound in `:min` or
  `:max`: the browser disables the days before the bound's date, and
  allows every time on that day.

The time segments take any minute: `:step` limits the times of the time
list, and a typed time off the step shows the rule's message under the
field.

## Errors of the several days and recurrence pickers

The several days and recurrence pickers have no segments, so an invalid
value is marked only with the `koyomi-invalid` class of the field. No
element of these pickers has `aria-invalid`, and `aria-describedby`
given to them reaches no element. Show the error message next to the
picker, where a person reading the form finds it.

## Times that the clocks skip or repeat

A date and time picker with a `time_zone` shows a notice when the wall
clock time is skipped (the hour the clocks go forward) or happens twice
(the hour they go back). A skipped time is moved forward by the gap. A
time that happens twice takes the first instant, or the second with
`ambiguous: :later`, and the notice lets the person choose the other.
On the server, `Koyomi.Changeset.cast_datetime/5` reads a time posted with
an offset as that instant. A wall clock time posted with no offset (with
JavaScript off) takes the first instant, or the second with its own
`:ambiguous` option, and a skipped one gets the error `:gap`. A date and time
picker with no zone posts the wall clock, and knows no clock changes.

## No range of dates and times

`Koyomi.DateTimeRange` is an Ecto type for a span of time (a
`tstzrange`), but there is no picker for it. Use two date and time
pickers, one for each end, and cast their two values as a map with
`"from"` and `"to"`.

## Ranges outside PostgreSQL

`Koyomi.DateRange` and `Koyomi.DateTimeRange` store PostgreSQL range
columns (`daterange`, `tstzrange`) by default. With `storage: :string`
or `storage: :map` they store an ISO 8601 interval or a map in any
database (SQLite, MySQL) and in embedded schemas, but the database sees
text: a query for the ranges that hold a day, or that overlap, needs
PostgreSQL's range columns, or the two ends in two fields.

A range needs both ends: a range with one end is invalid, and a stored
range with no bound (infinite) or an empty range reads back as `nil`.

## Recurrence rules

`Koyomi.Recurrence` reads a subset of RFC 5545 `RRULE`: `FREQ`
(`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`), `INTERVAL`, `COUNT`, `UNTIL`,
`BYDAY`, `BYMONTHDAY`, `BYMONTH`, `BYSETPOS` and `WKST`. Any other part
is an error, among them `HOURLY`, `MINUTELY`, `SECONDLY`, `BYHOUR`,
`BYMINUTE`, `BYSECOND`, `BYWEEKNO` and `BYYEARDAY`. A rule has no
`DTSTART`, `EXDATE` or `RDATE`: the start is given apart, to
`occurrences/3` and to the picker's `start`.

The editor of the recurrence picker edits less than the type reads: how
often, every how many, the weekdays of a weekly rule, the day of the
month or the nth weekday of a monthly rule (both from `start`), and the
end. A rule with other parts, such as `BYMONTH` or `BYSETPOS`, is shown
in words, and its other parts stay until the person changes the
frequency.
