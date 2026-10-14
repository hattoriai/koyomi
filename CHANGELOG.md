# Changelog

All notable changes to Koyomi are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Koyomi follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-13

### Added

- The pickers, in `Koyomi.Components`: `date_picker/1`,
  `date_range_picker/1`, `dates_picker/1`, `month_picker/1`,
  `week_picker/1`, `year_picker/1`, `time_picker/1`, `datetime_picker/1`,
  `recurrence_picker/1` and `calendar/1`. Each is a field for a form that
  posts the forms of the browser's own inputs, and is the browser's own
  input before the hook mounts.
- A field of segments (day, month, year, hour, minute, day period) in the
  order of the locale, typed or changed with the arrow keys, with the
  number keyboard on a phone.
- Dates typed in words, with a preview: "next friday", "in 3 weeks",
  "15–20 mar", "tomorrow 9am", in English, Portuguese, Spanish, French,
  German, Italian, Dutch and Japanese, and month and weekday names in any
  locale.
- Calendars in any locale and in the calendar systems of `Intl`
  (Japanese, Buddhist, ROC, Persian, Islamic, Hebrew, Chinese, Indian,
  Ethiopic and Coptic), with the locale's digits, first day of the week
  and direction.
- `Koyomi.Rules`, the same rules in the browser and in `Koyomi.Changeset`:
  bounds (relative to today), disabled days, ranges and weekdays, range
  lengths, counts, times and steps.
- Ecto types: `Koyomi.DateRange` (PostgreSQL `daterange`),
  `Koyomi.DateTimeRange` (`tstzrange`), `Koyomi.Dates`, `Koyomi.Month`,
  `Koyomi.Week` and `Koyomi.Recurrence`.
- Time zones: date and time pickers in a zone post the zone's offset, and
  show and resolve a time that the clocks skip or repeat;
  `Koyomi.Changeset.cast_datetime/5` for wall clock times.
- Day content from the LiveView (`Koyomi.Live.handle_days/4`): labels,
  tones, marks, descriptions, disabled days and time slots, in sync or
  async.
- Presets (`Koyomi.Presets`), public holidays of 26 countries
  (`Koyomi.Holidays`) and recurrence rules (`Koyomi.Recurrence`, a subset
  of RFC 5545, with descriptions in eight languages).
- The words of the pickers in eight languages (`Koyomi.Messages`).
- `Koyomi.Test`, to pick values in `Phoenix.LiveViewTest`.
- `mix koyomi.install`, the `--koyomi-*` properties and the Sumi theme.
