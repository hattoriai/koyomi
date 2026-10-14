# Rules

The rules of a picker say which days, ranges and times a person may
choose. Build them once with `Koyomi.Rules.new/1`, and give the same
rules to the component and to `Koyomi.Changeset`:

```elixir
@stay_rules Koyomi.Rules.new(min: :today, disabled_weekdays: [7], max_days: 14)
```

```heex
<.date_range_picker field={@form[:stay]} rules={@stay_rules} />
```

```elixir
def changeset(booking, attrs) do
  booking
  |> cast(attrs, [:stay])
  |> validate_required([:stay])
  |> Koyomi.Changeset.validate_range(:stay, @stay_rules)
end
```

The picker disables in the browser what the rules refuse, and the
changeset refuses it on the server. The browser is only a help to the
person: the changeset is the check that counts.

## The options

| Option | Value | Use |
|---|---|---|
| `:min`, `:max` | a `Date`, `:today` or `{:today, days}`; for a date and time picker also a `DateTime` or a `NaiveDateTime` | the first and the last day that may be chosen |
| `:disabled_dates` | a list of `Date` | days that may not be chosen |
| `:disabled_ranges` | a list of `Date.Range` (step 1 or -1) or `{first, last}` tuples | spans of days that may not be chosen |
| `:disabled_weekdays` | ISO weekdays, 1 (Monday) to 7 (Sunday) | weekdays that may not be chosen |
| `:min_days`, `:max_days` | positive integers | the shortest and the longest range, both ends counted: Monday to Wednesday is 3 days |
| `:allow_disabled_in_range` | `false` | `true` lets a range span disabled days, such as a stay over a closed day |
| `:min_count`, `:max_count` | integers (`:min_count` may be 0) | the fewest and the most days of the several days picker |
| `:min_time`, `:max_time` | a `Time` | the earliest and the latest time of day |
| `:step` | minutes, a positive integer | the minutes between the times that may be chosen, counted from midnight: with `15`, 09:15 may be chosen and 09:20 may not |
| `:time_zone` | an IANA zone, `"Etc/UTC"` by default | the zone of `:today` |

`Koyomi.Rules.new/1` raises `ArgumentError` for an unknown option or a
value of the wrong kind, so that a mistake shows when the rules are
built:

```elixir
Koyomi.Rules.new(max_days: 0)
** (ArgumentError) Koyomi.Rules: :max_days must be a positive integer, got: 0
```

The `rules` attribute also takes the options as a keyword list. The `min`
and `max` attributes replace `:min` and `:max`. The picker's zone (the
`time_zone` attribute, else `config :koyomi, time_zone:`) replaces
`:time_zone`, but only in the picker: give the rules of the changeset the
same `:time_zone`, so that both read the same today. `Koyomi.Rules.merge/2` does the same in
code:

```elixir
Koyomi.Rules.merge(@stay_rules, max: ~D[2027-12-31])
```

## Today

`:today` is today in the zone of the rules, and `{:today, days}` a day
relative to it: `{:today, 1}` is tomorrow, `{:today, -30}` thirty days
ago. They are read again on each check and each render, so rules built
once, in a module attribute, stay right the next day.

The picker's today is the server's: the component resolves today in the
picker's zone and gives it to the browser. A zone other than UTC needs a
time zone database (see the [Time zones](time_zones.md) guide).

## The rules in the browser

The component gives the browser a copy of the rules
(`Koyomi.Rules.to_client/1`), with `:today` resolved. The browser makes
the same checks as `Koyomi.Rules`:

* The calendar disables days before `:min`, after `:max`, and the
  disabled dates, ranges and weekdays.
* While the second end of a range is chosen, it disables the days that
  would make the range too long, or hold a disabled day.
* The several days picker refuses a day past `:max_count`, and says why.
* The time list starts at `:min_time` and ends at `:max_time`, every
  `:step` minutes.
* Presets that the rules refuse are disabled.

The browser also shows why a value is refused, under the field, when the
person typed it or picked it:

* A date typed in the segments or in words is taken even when the rules
  refuse it. The picker posts it, and shows the message.
* A range shorter than `:min_days` can be picked: the picker posts it, and
  shows "Choose at least 3 days".

The changeset then refuses these values. Two rules are checked only on
the server: `:min_count`, and the time of day of a `DateTime` or
`NaiveDateTime` bound (the browser disables the days before the bound's
date, as the bound is written).

Days that the LiveView marks disabled in the day content are disabled in
the browser too, but the server's rules do not know them. Check them in
the changeset with your own validation (see [Day content](days.md)).

## Checking values in code

`Koyomi.Rules` checks values without a changeset:

```elixir
rules = Koyomi.Rules.new(min: ~D[2027-03-01], disabled_weekdays: [6, 7])

Koyomi.Rules.allowed?(rules, ~D[2027-03-15])
#=> true

Koyomi.Rules.check_date(rules, ~D[2027-02-28])
#=> {:error, {:before_min, min: ~D[2027-03-01]}}

Koyomi.Rules.check_range(rules, Date.range(~D[2027-03-05], ~D[2027-03-08]))
#=> {:error, {:disabled_in_range, date: ~D[2027-03-06]}}
```

The checks are `check_date/2`, `check_range/2`, `check_dates/2`,
`check_time/2` and `check_datetime/2`. `min_date/1` and `max_date/1` give
the bounds with `:today` resolved, and `disabled?/2` tells whether a
day is disabled by a date, range or weekday rule.

## The changeset functions

| Function | Field | Checks |
|---|---|---|
| `validate_date/4` | `:date`, `Koyomi.Month`, `Koyomi.Week` | the day |
| `validate_range/4` | `Koyomi.DateRange`, or `{from, to}` of two `:date` fields | each end, the length, the days inside |
| `validate_dates/4` | `Koyomi.Dates`, `{:array, :date}` | each day, and the count |
| `validate_time/4` | `:time` | `:min_time`, `:max_time`, `:step` |
| `validate_datetime/4` | `:utc_datetime`, `:naive_datetime` and their `_usec` forms | the day, the time of day in the zone of the rules, the bounds as instants |
| `cast_datetime/5` | `:utc_datetime`, `:naive_datetime` | casts a date and time without an offset as a wall clock time in a zone (see [Time zones](time_zones.md)) |

A month or week field holds the first day of the month or the Monday of
the week, so `validate_date/4` checks that day.

Each validation checks the field only when it has a value (a change, or
the data's own value), skips a field that already has an error, and adds
at most one error.

## The errors

An error has `validation: :koyomi`, `kind:` (the reason), and the values
of its message:

| Kind | Message | Keys |
|---|---|---|
| `:before_min` | must be on or after %{min} | `min` |
| `:after_max` | must be on or before %{max} | `max` |
| `:disabled` | is not available | `date` |
| `:disabled_in_range` | includes a day that is not available (%{date}) | `date` |
| `:reversed` | must end on or after its start | |
| `:too_short` | must be at least %{count} days | `count`, `min_days` |
| `:too_long` | must be at most %{count} days | `count`, `max_days` |
| `:too_few` | must have at least %{count} days | `count`, `min_count` |
| `:too_many` | must have at most %{count} days | `count`, `max_count` |
| `:time_before_min` | must be at or after %{min_time} | `min_time` |
| `:time_after_max` | must be at or before %{max_time} | `max_time` |
| `:time_step` | must be in steps of %{count} minutes | `count`, `step` |
| `:gap` | does not exist in %{time_zone} (the clocks change) | `time_zone` |
| `:ambiguous` | happens twice in %{time_zone} (the clocks change) | `time_zone` |

For example:

```elixir
changeset.errors
#=> [due: {"is not available", [validation: :koyomi, kind: :disabled, date: ~D[2027-03-13]]}]
```

`min` and `max` are a `Date`, or the `DateTime` or `NaiveDateTime` of an
instant bound; `date` is a `Date`; `min_time` and `max_time` are a
`Time`. `Koyomi.Changeset.messages/0` returns the default messages.

Give other messages with `:message`, one for every error or a map by
kind. The kinds that the map does not name keep the default message:

```elixir
|> Koyomi.Changeset.validate_range(:stay, @stay_rules, message: %{too_long: "a stay is two weeks at most"})
```

`Koyomi.Changeset.validate_range/4` also returns `:reversed`, and the
date and time casts `:gap` and `:ambiguous`; the types return their own
errors for input they cannot cast ("must have a start and an end", "is
invalid").

## Translating the errors

The messages are in English, with `%{...}` placeholders, as Ecto's own.
The `translate_error/1` of a Phoenix app translates them with Gettext, and
uses `count` for the plural forms:

```elixir
def translate_error({msg, opts}) do
  if count = opts[:count] do
    Gettext.dngettext(MyAppWeb.Gettext, "errors", msg, msg, count, opts)
  else
    Gettext.dgettext(MyAppWeb.Gettext, "errors", msg, opts)
  end
end
```

Add the messages to `priv/gettext/errors.pot` (or run `mix gettext.extract`
on a module that names them with `dgettext_noop/2`), and translate them in
each locale. A date in a message is written as ISO 8601 (`2027-03-01`).
To write it in the person's locale, match the Koyomi errors first:

```elixir
def translate_error({msg, [validation: :koyomi, kind: kind] ++ _ = opts})
    when kind in [:before_min, :after_max] do
  key = if kind == :before_min, do: :min, else: :max
  opts = Keyword.update!(opts, key, &format_date/1)
  Gettext.dgettext(MyAppWeb.Gettext, "errors", msg, opts)
end
```

where `format_date/1` is your own formatter. Koyomi puts
`validation: :koyomi` and `kind:` first in the keys of its errors.

The picker's own messages in the browser ("Choose a day on or after
1 Mar 2027") come from `Koyomi.Messages`, already in eight languages, and
write dates in the picker's locale.

## Two fields for a range

To query the ends as dates in a database without range columns (SQLite,
MySQL), keep them in two `:date` fields, and give the picker `from` and
`to` instead of `field`. (`Koyomi.DateRange` with `storage: :string` or
`storage: :map` also stores a range there, but as text.)

```heex
<.date_range_picker from={@form[:check_in]} to={@form[:check_out]} label_id="stay-label" rules={@stay_rules} />
```

The picker posts each end with its own name (`booking[check_in]`,
`booking[check_out]`), and its id is the first field's id with
`_range_picker`. In the changeset, give the two fields as a tuple:

```elixir
booking
|> cast(attrs, [:check_in, :check_out])
|> validate_required([:check_in, :check_out])
|> Koyomi.Changeset.validate_range({:check_in, :check_out}, @stay_rules)
```

The range is checked only when both fields have a date. The error goes
on `check_in` for a `:before_min` or `:disabled` error of the first day,
and on `check_out` for the others.
