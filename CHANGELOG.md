# Changelog

All notable changes to Koyomi are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and Koyomi follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The Sumi theme follows Sumi's seven themes and their accents: where a
  theme's accent is the hue of the holiday or of a tone, that one takes
  another hue in that theme (Smoke, Stone, Lacquer, Snow, Silk). `mix dev`
  shows every page in each (`?sumi=smoke`). See the Theming guide.

### Fixed

- `Koyomi.Live.refresh_days/2` left a calendar on the page, and an open
  popover, without day content: it cleared the days but asked for them
  again only when the months shown changed, which a refresh does not do.
  It now asks for the days of the months shown at once (a closed popover
  still asks when it opens).

### Fixed

- The Sumi theme gave Sumi's dark themes other than Ink the light
  palette, and Sumi's light themes other than Paper the dark one on a
  system in dark mode. Its warning tone, on a page without Sumi, is
  Sumi's warning.

## [0.2.0] - 2026-10-17

### Added

- Filters and URLs: the pickers work with plain params as well as
  with Ecto forms. See the new Filters and URLs guide.
  - `keys` on the range picker names the two days in the posted map and
    in the value: `keys={{"start", "end"}}` posts `field[start]` and
    `field[end]`, and reads a value with those keys as the params have
    it.
  - `relative` on the date and range pickers: a chosen preset posts its
    key (`last_7_days`, `this_month`, `yesterday`) instead of the days it
    covers today, so that a filter in a shared link stays relative. The
    field shows the preset and its days, a key as the value shows that
    preset, and words typed in the popover that give a preset's days
    choose that preset.
  - Each preset has a key: the built-in ones their own
    (`Koyomi.Presets.key/1`), the others the key of a keyword list
    (`presets={[recent: {:last, 7, :days}]}`), which names the app's own
    presets too.
  - `Koyomi.Presets.to_date/2` and `to_range/2` give the days of a
    preset or of its key on a day, and `Koyomi.Presets.parse/1` the
    preset of a key.
  - `Koyomi.DateRange` casts a map with `"start"` and `"end"`, and the
    key of a built-in preset (today's days, in UTC).
  - `Koyomi.Test.pick/3` picks a preset by its key in a relative picker.
  - The development server has a Filters page.
- Phoenix 1.7 and LiveView 1.1 are supported: Koyomi needs Phoenix
  1.7.14 or 1.8 (it needed 1.8) and LiveView 1.1 or later (it needed
  1.2). Koyomi needed no change of code for them. CI tests the oldest
  versions.

### Fixed

- A browser test of the date picker's presets no longer fails on
  Saturdays, when the development page's rules disable tomorrow.

## [0.1.2] - 2026-10-14

### Added

- `setIcons` in the JavaScript bundle replaces the icons of the pickers
  with the app's own (an SVG, or an element such as a Phoenix Heroicon),
  and each icon has a `data-icon` attribute for styles. See the Icons
  section of the theming guide.

### Changed

- The icons of the pickers are Lucide's (`calendar`, `clock`, `repeat`,
  `x`, `chevron-right`), as in Kotoba, drawn with a stroke of 2 instead
  of 1.75. `NOTICE` has the Lucide and Feather licences.

### Fixed

- The end day of a recurrence ("Ends on") is picked on a Koyomi calendar
  that opens in the popover, and no longer on the browser's date input.
  It follows the locale and the theme, and the days before the start
  are disabled. Escape closes the calendar and keeps the popover open.

## [0.1.1] - 2026-10-14

### Added

- SQLite and MySQL: `Koyomi.DateRange` and `Koyomi.DateTimeRange` take
  `storage: :string` (an ISO 8601 interval in a text column) or
  `storage: :map` (a JSON column), besides the PostgreSQL range columns
  of the default `storage: :postgres`. Embedded schemas take them too.

### Fixed

- `Koyomi.Dates` reads back the JSON array of ISO dates that SQLite
  keeps for an `{:array, :date}` field.

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
