# Locales and calendars

A picker writes its dates in a locale, and can show them in a calendar
system other than the Gregorian. The value does not change with either:
every picker posts ISO 8601 dates (`2027-03-15`), and the server reads
them as `Date` values.

```heex
<.date_picker field={@form[:due]} label_id="due-label" locale="ar-EG" />
<.date_picker field={@form[:due]} label_id="due-label" locale="ja-JP" calendar="japanese" />
```

## Locales

The `locale` attribute is a BCP 47 tag, such as `"en-GB"`, `"pt-PT"` or
`"ar-EG"`. Without it, the picker takes `config :koyomi, locale:`, else
`"en"`. The browser's `Intl` gives the picker, in that locale:

* the names of the months and the weekdays;
* the digits of the numbers (Arabic-Indic digits in `ar-EG`; a
  `-u-nu-` extension chooses others, as in `"en-u-nu-thai"`);
* the order of the date segments and their separators (day, month, year
  in `en-GB`; month, day, year in `en-US`);
* the 12 or 24-hour clock of the time segments;
* the dates written in full, such as the labels that a screen reader
  reads for each day.

The segments read any Unicode digits that a person types or pastes, and
turn them into numbers. See [Typing dates](typing.md).

### The week

The first day of the week and the weekend come from the locale's
region, as CLDR gives them. The picker asks the browser
(`Intl.Locale.prototype.getWeekInfo`), and uses a copy of the CLDR table
when the browser does not have it:

| Region | First day | Weekend |
|---|---|---|
| most of Europe (`en-GB`, `fr-FR`, `de-DE`) | Monday | Saturday and Sunday |
| `en-US`, `ja-JP`, `pt-BR`, `pt-PT` | Sunday | Saturday and Sunday |
| `ar-EG` | Saturday | Friday and Saturday |
| `hi-IN` | Sunday | Sunday |

A locale with no region (`"en"`, `"pt"`) gets the region that the browser
adds to it. A `-u-fw-` extension sets the first day (`"en-US-u-fw-mon"`),
and the `first_day` attribute replaces both, as an ISO weekday (1 is
Monday, 7 is Sunday):

```heex
<.date_picker field={@form[:due]} locale="en-US" first_day={1} />
```

The week picker always starts its weeks on Monday, as ISO weeks do.

The calendar marks the weekend columns and days with the
`koyomi-weekend` class, for the theme to style. The weekend does not
disable a day: use the `:disabled_weekdays` rule for that (see
[Rules](rules.md)).

### Right to left

A locale written right to left (Arabic, Hebrew, Persian, Urdu and the
other right-to-left scripts) puts `dir="rtl"` on the picker and on its
calendar. The picker asks the browser for the direction
(`Intl.Locale.prototype.getTextInfo`), and else reads it from the
locale's script. In the calendar, the left arrow then moves to the next
day and the right arrow to the day before.

## Calendar systems

The `calendar` attribute shows the dates in another calendar system:

```heex
<.date_picker field={@form[:due]} locale="he-IL" calendar="hebrew" />
<.date_range_picker field={@form[:stay]} locale="fa-IR" calendar="persian" />
```

The calendar systems are:

| Calendar | Value |
|---|---|
| Gregorian | `gregory` |
| ISO 8601 | `iso8601` |
| Thai Buddhist | `buddhist` |
| Japanese imperial | `japanese` |
| Republic of China (Minguo) | `roc` |
| Persian (Solar Hijri) | `persian` |
| Islamic | `islamic`, `islamic-umalqura`, `islamic-civil`, `islamic-tbla` |
| Hebrew | `hebrew` |
| Chinese | `chinese` |
| Korean (Dangi) | `dangi` |
| Indian national | `indian` |
| Ethiopian | `ethiopic` |
| Coptic | `coptic` |

Without the attribute, a `-u-ca-` extension of the locale chooses the
calendar (`"th-TH-u-ca-buddhist"`), else it is `gregory`. A value that is
not in the list, or a calendar that the browser cannot format, falls
back to `gregory`.

The calendar system changes what the person sees: the month grid, the
names of the months, the year, and the dates written in full. A Hebrew
month runs from its own first day to its last, and a Hebrew leap year has
13 months. The rules, the presets, the holidays and the posted value stay
in ISO dates.

`iso8601` is the Gregorian calendar; the picker writes its months as
`gregory` does. The Gregorian-like systems (`gregory`, `iso8601`,
`buddhist`, `japanese`, `roc`) have the Gregorian months, and differ in
their years. The others have months of their own, which the browser
computes, with `Temporal` when it has it.

### The segments

The segments keep the locale's order, and take the numbers of the
calendar:

* `gregory`, `iso8601` and `japanese`: the ISO numbers. In `japanese`,
  the segments take `2027` for the year, while the calendar and the dates
  written in full show the era (令和9年).
* The other calendars: their own numbers. In `buddhist` the year of
  2027 is 2570; in `hebrew`, the month segment takes 1 to 13, and a
  day that the month does not have is not a date.

### Month, year and week pickers

The month, year and week pickers work in Gregorian months and years: a
month picker posts `2027-03`, which is not a month of the Hebrew
calendar. With a `calendar` that is not Gregorian-like, these pickers
use `gregory`. With `buddhist`, `japanese` or `roc`, they keep the
calendar, whose months are the Gregorian ones.

## Week numbers

```heex
<.date_picker field={@form[:due]} week_numbers />
```

With `week_numbers`, the calendar shows a column of ISO 8601 week
numbers, in every locale and every calendar system. ISO weeks start on
Monday, and week 1 of a year is the week that holds its first Thursday,
so each row of the calendar is numbered by the ISO week of its Thursday,
also when the week starts on another day. The week picker always shows them.

On the server, `Koyomi.ISOWeek` gives the same numbers:

```elixir
Koyomi.ISOWeek.week(~D[2027-01-01])
#=> {2026, 53}

Koyomi.ISOWeek.to_iso8601(~D[2027-03-15])
#=> "2027-W11"

Koyomi.ISOWeek.monday(2027, 11)
#=> {:ok, ~D[2027-03-15]}
```

`weeks_in_year/1` gives 52 or 53, and `from_iso8601/1` reads `2027-W11`
into the Monday of the week.

## Holidays

```heex
<.date_picker field={@form[:due]} holidays="PT" />
<.calendar id="team" holidays={["PT", "GB", MyApp.Closures]} months={2} />
```

The `holidays` attribute marks public holidays in the calendar. It takes
a country code, a provider module, or a list of them. A holiday day has
the `koyomi-holiday` class, its name as a tooltip, and its name in the
label that a screen reader reads. A holiday is not disabled: add the
days to the rules when they may not be chosen.

### The countries

`Koyomi.Holidays.countries/0` lists the built-in countries, by ISO 3166-1
alpha-2 code, in any case:

AR, AT, AU, BE, BR, CA, CH, DE, DK, ES, FI, FR, GB, IE, IN, IT, JP, MX,
NL, NO, NZ, PL, PT, SE, US, ZA.

The holidays are computed by rule, with no data to download. They are
the national public holidays: the days off that the law gives in the
whole country. Regional and local days, and days off by custom (such as
Christmas Eve in many countries), are not listed. The module of each
country, such as `Koyomi.Holidays.PT`, says what it keeps and leaves out.

The rules are those in force in 2026. A holiday that began or ended
since 2010 is listed only in the years it was kept; earlier years follow
the rules of 2010. One-off holidays are not listed.

Where the law gives another day off for a holiday on a weekend, the
holiday stays on its date, and a second entry marks the day off
("Christmas Day (substitute day)").

### The names

Each holiday has a name in the main language of its country, and an
English name. The picker shows the first to a locale in that language,
and the English name to the others: `Natal` in `pt-PT` and `pt-BR`,
`Christmas Day` in `en-GB`. Two holidays on one day are joined with
` · `.

### In code

```elixir
Koyomi.Holidays.list("PT", 2027)
#=> [%Koyomi.Holiday{date: ~D[2027-01-01], name: "Ano Novo", english: "New Year's Day", country: "PT"}, ...]

Koyomi.Holidays.between(["PT", "DE"], Date.range(~D[2027-12-24], ~D[2028-01-01]))

Koyomi.Holidays.to_client(["PT", "DE"], Date.range(~D[2027-12-25], ~D[2027-12-25]), "pt-PT")
#=> %{"2027-12-25" => "Natal · Christmas Day"}
```

An unknown country code raises `ArgumentError`, with the list of codes.

### A provider of your own

A module that implements `Koyomi.Holidays.Provider` gives the holidays
of a region, or the days a business is closed. `holidays/1` returns the
holidays of a year as `{date, name, english}` tuples:

```elixir
defmodule MyApp.Closures do
  @behaviour Koyomi.Holidays.Provider

  @impl true
  def holidays(year) do
    [{Date.new!(year, 12, 24), "Fermeture", "Office closed"}]
  end

  @impl true
  def language, do: "fr"
end
```

`language/0` is optional: it says which locales see `name`, and the
others see `english`. A provider without it always shows `name`.
`country/0`, also optional, sets the `country` of its
`Koyomi.Holiday` structs. `Koyomi.Holidays.Rules` has the date rules that
the built-in countries use: `easter/1`, `nth_weekday/4`, `on_or_after/2`,
`on_or_before/2` and `substitute_days/2`.

### The years in the page

The component computes the holidays on the server, and puts them in the
page as a map from ISO date to name. It covers whole years:

* from two years before today, or from the year of the `:min` rule;
* to three years after today, or to the year of the `:max` rule;
* never more than ten years before or after today.

A calendar shown outside these years has no holidays marked. Give the
rules a `:min` and a `:max` to choose the years, for example for a
picker of past dates.
