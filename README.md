# Koyomi

![Koyomi — Dates for Phoenix](https://raw.githubusercontent.com/hattoriai/koyomi/main/media/banner.png)

Koyomi (暦, "calendar") is dates for Phoenix. It gives your app:

* pickers for LiveView forms: a day, a range of days, several days, a
  month, an ISO week, a year, a time, a day and a time (in a time zone,
  or from the time slots your LiveView offers), and a repeat rule;
* fields of segments in the order of the locale (`15/03/2027`,
  `03/15/2027`, `2027/03/15`), typed or changed with the arrow keys, and
  dates typed in words, with a preview: "next friday", "in 3 weeks",
  "15–20 mar", "amanhã às 9h";
* calendars in any locale and in the calendar systems of the browser:
  Japanese, Buddhist, Persian, Islamic, Hebrew, Chinese and more, with the
  locale's digits, first day of the week and direction;
* `Koyomi.Rules`, the same rules in the browser and in your changeset, so
  that what the calendar disables is what the server refuses;
* Ecto types for what the pickers post, PostgreSQL `daterange` and
  `tstzrange` included, and the same ranges as text or JSON for SQLite
  and MySQL;
* day content from your LiveView: prices, full days, marks and time
  slots, as for a booking;
* `Koyomi.Test`, to pick values in `Phoenix.LiveViewTest` with no
  browser.

The pickers are a prebuilt JavaScript bundle in the Hex package. Your app
does not run Node.js for them: you add the hook and one style sheet.

## Try it: Notebook

![Koyomi in Notebook: a due date, a range of days, a repeat rule, and a day and time picker open on its time slots, with the weekends and the past days disabled by the rules](https://raw.githubusercontent.com/hattoriai/koyomi/main/media/notebook-pickers.png)

[Notebook](https://github.com/hattoriai/notebook) is a complete Phoenix
app made with Koyomi and Kotoba. Each page has a due date, the days it
covers, a review on a day and a time from the free slots, and a repeat
rule; the changeset checks the same rules as the calendar, and the
notebook's own calendar shows the days of every page. Clone it, run
`mix setup` and `mix phx.server`, and sign in as Hattori Hanzo (its
README has the details) to try every picker in your browser.

## What the pickers do

| | |
| --- | --- |
| Pickers | `date_picker`, `date_range_picker`, `dates_picker`, `month_picker`, `week_picker`, `year_picker`, `time_picker`, `datetime_picker`, `recurrence_picker`, and `calendar` for a calendar on the page |
| Fields | segments in the locale's order and digits, typed or changed with the arrow keys, the number keyboard on a phone, two-digit years, paste |
| Words | dates, ranges and times typed in words, in English, Portuguese, Spanish, French, German, Italian, Dutch and Japanese, and month and weekday names in every locale, with a preview |
| Calendar | one or more months side by side, a list of months that scrolls on a phone, months and years to jump to, week numbers, holidays of 26 countries, presets |
| Ranges | drawn as the pointer moves, the length in days or nights, days out of reach disabled while the end is chosen |
| Rules | bounds relative to today, disabled days, ranges and weekdays, the shortest and longest range, counts, times and steps; the same in `Koyomi.Changeset` |
| Locales | names, digits, first day of the week and weekend from the browser's CLDR data, right-to-left languages, the 12 or 24-hour clock |
| Calendars | Gregorian, ISO, Japanese, Buddhist, ROC, Persian, Islamic (four kinds), Hebrew, Chinese, Dangi, Indian, Ethiopic, Coptic |
| Time zones | today in a zone, wall clock times posted with the zone's offset, the hour the clocks skip or repeat shown and resolved |
| Day content | labels, tones, marks, descriptions, disabled days and time slots from the LiveView, in sync or async, refreshed on demand |
| Forms | the forms of the browser's own inputs (`2027-03-15`, `2027-W11`), the browser's own input before the hook mounts, `phx-change` and `used_input?`, pages without LiveView |
| Filters | plain params and URLs as well as Ecto forms: a range's keys of your own (`start` and `end`), and relative values, where a chosen preset posts its key (`last_7_days`) and stays relative in a shared link |
| Types | `Koyomi.DateRange`, `Koyomi.DateTimeRange`, `Koyomi.Dates`, `Koyomi.Month`, `Koyomi.Week`, `Koyomi.Recurrence` |
| Repeat | daily, weekly, monthly and yearly rules (RFC 5545), said in words in eight languages, with the next dates |
| Theming | CSS custom properties, the Sumi theme, dark mode, forced colours, reduced motion |
| Accessibility | a labelled group of spinbuttons, a dialog, the WAI-ARIA grid with one tab stop, announcements, 44px targets on touch screens |

## Install

Koyomi needs Elixir 1.18 or later (it uses the built-in `JSON` module),
Phoenix 1.7.14 or 1.8, and Phoenix LiveView 1.1 or later.

Add `koyomi` to the deps in `mix.exs`:

```elixir
def deps do
  [
    {:koyomi, "~> 0.2"}
  ]
end
```

Then run:

```sh
mix deps.get
mix koyomi.install
```

The installer adds the hook to `assets/js/app.js` and the style sheet to
`assets/css/app.css`, and prints what it changed. Give `--dry-run` to see
the changes first. It does not add what a file already has, so you can
run it again.

### The manual steps

To make the same changes by hand, import the hook in `assets/js/app.js`
and add it to the hooks of the `LiveSocket`:

```js
import { Koyomi } from "koyomi"

const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, Koyomi},
})
```

Import the style sheet in `assets/css/app.css` (and the Sumi theme, if you
want it: Sumi is the design system of Hattori AI, the makers of Koyomi
and Kotoba). Put these lines below the other `@import` lines of
`app.css`:

```css
@import "../../deps/koyomi/priv/static/koyomi.css";
/* @import "../../deps/koyomi/priv/static/koyomi-sumi.css"; */
```

A date and time picker with a `time_zone` other than UTC, and rules with a
`:time_zone`, need a time zone database on the server, such as
[`tz`](https://hex.pm/packages/tz) or
[`tzdata`](https://hex.pm/packages/tzdata):

```elixir
config :elixir, :time_zone_database, Tz.TimeZoneDatabase
```

### `NODE_PATH=deps`

`import { Koyomi } from "koyomi"` resolves through the `NODE_PATH` of your
esbuild profile, which must have `deps/`. The Phoenix generators already
set it. If your profile has no `NODE_PATH`, add it in `config/config.exs`:

```elixir
env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
```

## Use

```elixir
schema "bookings" do
  field :check_in, :date
  field :stay, Koyomi.DateRange
end

@stay_rules Koyomi.Rules.new(min: :today, max_days: 14)

def changeset(booking, attrs) do
  booking
  |> cast(attrs, [:check_in, :stay])
  |> Koyomi.Changeset.validate_range(:stay, @stay_rules)
end
```

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <label id="stay-label">Stay</label>
  <.date_range_picker field={@form[:stay]} label_id="stay-label" rules={@stay_rules} months={2} nights />
</.form>
```

Import the components in the `html_helpers` of your web module:

```elixir
import Koyomi.Components
```

Each picker posts its value with the form, in the form of the browser's
own inputs (`2027-03-15`, or `stay[from]` and `stay[to]` for a range), so
the form's own `phx-change` and `phx-submit` events have it, and the Ecto
type of the field casts it.

## Guides

* [Quickstart](guides/quickstart.md): install, the schema, the form and
  the changeset.
* [Pickers](guides/pickers.md): every picker, what it posts and its
  attributes.
* [Forms](guides/forms.md): what the pickers post, errors, pages without
  LiveView, values set by the server.
* [Filters and URLs](guides/filters.md): plain params, a range's own keys,
  and relative values that stay relative in a URL.
* [Rules](guides/rules.md): `Koyomi.Rules` and `Koyomi.Changeset`.
* [Typing](guides/typing.md): the segments, and dates typed in words.
* [Calendars and locales](guides/calendars.md): locales, calendar systems,
  week numbers and holidays.
* [Time zones](guides/time_zones.md): today in a zone, offsets, the hours
  the clocks skip or repeat.
* [Day content](guides/days.md): labels, marks, disabled days and time
  slots from the LiveView.
* [Recurrence](guides/recurrence.md): the repeat picker and
  `Koyomi.Recurrence`.
* [Testing](guides/testing.md): `Koyomi.Test` with `Phoenix.LiveViewTest`.
* [Theming](guides/theming.md): the `--koyomi-*` properties and the Sumi
  theme.
* [Accessibility](guides/accessibility.md): the roles and the keyboard.
* [Known limits](guides/limits.md).

## Development

The picker source is TypeScript in `assets/`. The built files in
`priv/static` are not in the repository; the Hex package has them.

```sh
mix deps.get
mix koyomi.build    # npm ci in assets/ when necessary, then esbuild
mix dev             # the development server on http://localhost:4099
```

`mix koyomi.build` runs in the `:dev` environment and needs `npm`. It
empties `priv/static` and writes the four files of the package:
`koyomi.esm.js`, `koyomi.cjs.js`, `koyomi.css` and `koyomi-sumi.css`.

`mix dev` runs `dev.exs`: a Phoenix endpoint with every picker in a form
(`/`), day content from a fake availability service, slow and async
(`/days`), the calendar systems of the world (`/calendars`), a page
without LiveView (`/plain`), and the Sumi theme at `/?theme=sumi` (and
`&dark=1`). Every page takes `locale`, `calendar` and `zone` query
params. Set `PORT` for another port. An esbuild watcher rebuilds the
bundle, and the page reloads.

### Tests

```sh
mix test                   # the ExUnit suite
mix test --include build   # also mix koyomi.build and mix hex.build
mix test.js                # the unit tests of the TypeScript modules
mix test.e2e               # the Playwright browser tests
mix precommit              # compile, format, credo --strict and test
mix dialyzer
```

`mix test.js` runs the tests of the pure modules in `assets/test/` (the
date arithmetic, the locales and calendars, the words parser and the
recurrence rules) with Node's test runner. `test/fixtures/recurrence.json`
holds the recurrence rules to the same results in Elixir and in
TypeScript.

The browser tests in `e2e/` use Playwright, in Chromium, Firefox and
WebKit (the engine of Safari). Install the browsers once:

```sh
cd e2e && npm ci && npx playwright install chromium firefox webkit
```

`mix test.e2e` runs every spec in the three browsers, and `E2E_BROWSERS`
picks some of them. It runs `npm ci` in `e2e/` when `e2e/node_modules`
is missing, builds the bundle, and starts its own development server,
without watchers, on port 4098 (set `E2E_PORT` for another port). A
`mix dev` on port 4099 can keep running.

### Release

`mix release` (in this repository, an alias that replaces Mix's `release`
task) builds the bundle, checks that `priv/static` holds only the four
bundle files (`mix koyomi.release_check`), publishes to Hex, and tags
and pushes `v<version>`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md): when a change needs an issue
first, and what a pull request needs. Report a security problem
privately, as [SECURITY.md](SECURITY.md) says.

## License

Koyomi is released under the MIT License. See `LICENSE`.

The icons are from Lucide (ISC License; some from Feather, MIT License),
and the table of week data by region follows the Unicode CLDR (Unicode
License v3). See `NOTICE`.
