# Filters and URLs

A picker is not only a field of an Ecto form. A dashboard's filter bar, a
search page, a report or an inbox keeps its dates in plain params, often
in the URL, so that a page can be shared and bookmarked. Two attributes
make that work with no code of your own:

* `keys` names the two days of a range in the params (`start` and `end`,
  `lower` and `upper`, as your app has them);
* `relative` keeps a preset as a preset: "Last 7 days" stays the last
  seven days tomorrow, in a link someone opened a week later.

## A filter bar

```heex
<form id="filters" phx-change="filter">
  <label id="day-label">Day</label>
  <.date_picker name="filter[day]" value={@filter["day"]} label_id="day-label"
    relative presets={[:today, :yesterday]} />

  <label id="period-label">Period</label>
  <.date_range_picker name="filter[period]" value={@filter["period"]} label_id="period-label"
    keys={{"start", "end"}} relative months={2}
    presets={[:today, {:last, 7, :days}, {:last, 30, :days}, :this_month, :this_quarter, :this_year]} />
</form>
```

```elixir
def handle_params(params, _uri, socket) do
  {:noreply, assign(socket, filter: Map.get(params, "filter", %{"period" => "last_7_days"}))}
end

def handle_event("filter", %{"filter" => filter}, socket) do
  {:noreply, push_patch(socket, to: ~p"/reports?#{%{filter: filter}}")}
end
```

The pickers take their value from the params as they come
(`value={@filter["period"]}`), with no form and no changeset, and the
form's `phx-change` posts them back. The URL is the state:

| The person | The params |
|---|---|
| chooses "Last 7 days" | `filter[period]=last_7_days` |
| picks the 1st to the 7th of March | `filter[period][start]=2027-03-01&filter[period][end]=2027-03-07` |
| chooses "Yesterday" | `filter[day]=yesterday` |
| picks the 15th of March | `filter[day]=2027-03-15` |
| clears a picker | `filter[day]=` |

LiveView marks the fields of a form that no one has touched yet with
`_unused_` params (see `Phoenix.Component.used_input?/1`); drop the keys
that start with `_unused_` before you put the params in a URL.

## The keys of a range

`keys` gives the names of the two days in the posted map, and in the
value the picker reads:

```heex
<.date_range_picker name="booking[nights]" value={@params["nights"]} keys={{"check_in", "check_out"}} />
```

It posts `booking[nights][check_in]` and `booking[nights][check_out]`. The
keys are strings or atoms; the default is `{"from", "to"}`. A value with
`from` and `to` (from `Koyomi.DateRange.to_params/1`) works too.

`Koyomi.DateRange` casts a map with `"from"` and `"to"`, or with
`"start"` and `"end"`. For other keys, cast the two days yourself, or
rename them in the changeset's params.

## Relative values

With `relative`, a picker posts the key of the preset a person chooses,
instead of the days it covers today:

* the field shows the preset and its days, "Last 7 days 10–16 Mar", in
  the picker's locale; a click opens the calendar on them, Backspace
  clears it, and a letter starts typing words;
* a date typed or picked in the calendar is posted as days, as in any
  picker;
* words typed in the popover that give the same days as a preset
  ("last 7 days", "yesterday") choose that preset;
* a key as the value (`value="last_7_days"`, or `value={:last_7_days}`)
  shows that preset; any other value shows its days.

A relative picker posts the key under the field's own name and the days
under their names, and only one of the two at a time: the other inputs
are disabled. It needs a `field` or a `name` for that.

### The keys of the presets

Each built-in preset has a key, which `Koyomi.Presets.key/1` gives:

| Preset | Key |
|---|---|
| `:today`, `:tomorrow`, `:yesterday` | `today`, `tomorrow`, `yesterday` |
| `:this_week`, `:last_month`, `:this_quarter`, `:last_year`... | the same name |
| `{:last, 7, :days}`, `{:next, 14, :days}` | `last_7_days`, `next_14_days` |
| `{:in, 1, :week}`, `{:ago, 2, :month}` | `in_1_week`, `ago_2_month` |
| `:month_to_date`, `:year_to_date` | `month_to_date`, `year_to_date` |

A keyword list gives presets keys of your own, and names an app's own
presets, which have no key otherwise:

```heex
<.date_range_picker name="period" relative
  presets={[recent: {:last, 7, :days}, payday: {"Since payday", &since_payday/1}]} />
```

### From a key to days

The params keep the key; the query needs the days. `Koyomi.Presets`
turns a built-in key into the days it covers on a day:

```elixir
{:ok, range} = Koyomi.Presets.to_range("last_7_days", today: Koyomi.Rules.today(rules))
{:ok, date} = Koyomi.Presets.to_date("yesterday")
```

`to_range/2` gives a day preset as a range of one day, and `to_date/2` a
range preset as its first day, as the pickers do. Give `:today` in the
time zone of your users (today in UTC by default), and `:first_day` for
the week presets when your weeks do not start on Monday.

`Koyomi.DateRange` casts a built-in key too, as today's days in UTC: an
Ecto field of that type stores the days, not the key. Keep the key in a
`:string` field when the stored value must stay relative.

## Without a form

A picker with `on_change` pushes its value on each change, with no form:

```heex
<.date_range_picker id="period" value={@period} keys={{"start", "end"}} relative
  presets={[{:last, 7, :days}, :this_month]} on_change="period" />
```

```elixir
def handle_event("period", %{"id" => "period", "value" => value}, socket) do
  # "last_7_days", or %{"from" => "2027-03-01", "to" => "2027-03-07"}
  {:noreply, push_patch(socket, to: ~p"/reports?#{%{period: value}}")}
end
```

The pushed value is the picker's wire form: a preset's key, an ISO date,
or a map with `"from"` and `"to"` (the wire form does not use `keys`).

## Testing

`Koyomi.Test.pick/3` picks a preset by its key in a relative picker, and
days by their usual values, in a form with plain params as in an Ecto
form:

```elixir
html = pick(view, "filter_period__picker", :this_month)
assert html =~ "This month"

pick(view, "filter_period__picker", Date.range(~D[2027-03-01], ~D[2027-03-07]))
```
