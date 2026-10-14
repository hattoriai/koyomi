# Backlog

Known gaps in Koyomi, each to become an issue.

## `aria-invalid` on the several days and recurrence pickers

These pickers have no segments, so `aria-invalid` and `aria-describedby`
reach no element; only the `koyomi-invalid` class marks an error. Put
them on the field's group, or on the chips and the summary.

## `:min_count` in the browser

The several days picker does not check `:min_count`; only the changeset
does. Show the message under the field, as for `:max_count`.

## `:step` in the time segments

The time segments take any minute, and only the rules' message says that
a time is off the step. The arrow keys could move by the step.

## Times of a `DateTime` bound in the browser

A `:min` or `:max` that is a `DateTime` or a `NaiveDateTime` disables
the days before its date, but every time of its own day stays
available in the browser.

## Echoes of an undone value

A render that sets a field back to a value that the picker posted in its
last eight posts is ignored as an echo, so an undo in the LiveView does
not reach the picker without `Koyomi.Live.push_value/3`. Ignore echoes
only for a short time after each post, or only until the server has
answered the post.

## A picker for a range of dates and times

`Koyomi.DateTimeRange` has no component. A range picker with a time at
each end, posting `from` and `to` with offsets, would fill the gap.

## More of a rule in the recurrence editor

The editor edits the frequency, the interval, the weekdays of a weekly
rule, one day or nth weekday of a monthly rule, and the end. It cannot
edit `BYMONTH`, `BYSETPOS`, `WKST`, several days of the month, or a
yearly rule's day: a rule from the server with these parts is shown in
words, and editing it replaces them.

## Wider `RRULE` support

`HOURLY`, `MINUTELY`, `SECONDLY`, `BYHOUR`, `BYMINUTE`, `BYSECOND`,
`BYWEEKNO` and `BYYEARDAY` are errors. `EXDATE` and `RDATE` are not
read.

## Japanese era years in the segments

A picker in the Japanese calendar takes Gregorian years in its segments.
An era segment (Reiwa, Heisei) and the year of the era would match what
the calendar shows.

## Other calendars in the month, week and year pickers

These pickers fall back to Gregorian for the Hebrew, Chinese, Islamic,
Persian, Indian, Ethiopic and Coptic calendars.

## Digits in the typing box

The typing box reads ASCII and full-width digits only. Arabic-Indic,
Persian and Devanagari digits are read in the segments; `parseDigits`
could fold them in the typing box too.

## Plain words in more languages

The typing box has word tables for English, Portuguese, Spanish, French,
German, Italian, Dutch and Japanese. Other locales read English words.

## Holidays outside the span of years sent

A picker sends the holidays from the year of `:min` (or two years ago)
to the year of `:max` (or three years ahead), within ten years of today.
A calendar moved further shows no holidays. Load them with the day
content, or on demand.

## Regional holidays

`Koyomi.Holidays` lists national holidays only. Regions (German states,
Swiss cantons, Spanish communities) need a provider of the app's own.

## Browser tests on mobile and with screen readers

The Playwright tests run desktop Chromium, Firefox and WebKit. There
are no runs on iOS Safari, Android Chrome, or with a screen reader.
