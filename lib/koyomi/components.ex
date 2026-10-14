defmodule Koyomi.Components do
  @moduledoc """
  Function components for the Koyomi pickers.

      import Koyomi.Components

      <.form for={@form} phx-change="validate" phx-submit="save">
        <label id="due-label">Due</label>
        <.date_picker field={@form[:due]} label_id="due-label" min={:today} />

        <label id="stay-label">Stay</label>
        <.date_range_picker field={@form[:stay]} label_id="stay-label" months={2} />
      </.form>

  The pickers need the `Koyomi` hook in the LiveSocket and the Koyomi CSS
  (see the README). Each picker is a field for a form: it posts its value
  with the form, in the form of the browser's own inputs (`2027-03-15`,
  `2027-03`, `2027-W11`, `14:30:00`), so the form's own `phx-change` and
  `phx-submit` events have it, and the Ecto types of the field cast it.

  Before the hook mounts (and with JavaScript off), the picker is the
  browser's own input of its kind, with the same name and value.

  ## The pickers

    * `date_picker/1` - a day (`:date`).
    * `date_range_picker/1` - a range of days (`Koyomi.DateRange`, or two
      `:date` fields).
    * `dates_picker/1` - several days (`Koyomi.Dates`).
    * `month_picker/1`, `year_picker/1`, `week_picker/1` - a month
      (`Koyomi.Month`), a year (`:integer`), an ISO week (`Koyomi.Week`).
    * `time_picker/1` - a time of day (`:time`).
    * `datetime_picker/1` - a day and a time (`:utc_datetime` with a
      `time_zone`, else `:naive_datetime`), from a free choice or from the
      time slots that the LiveView offers.
    * `recurrence_picker/1` - a repeat rule (`Koyomi.Recurrence`).
    * `calendar/1` - a calendar on the page, to show days and to pick one
      or more outside a form.

  Every picker has the attributes below (the shared ones); the docs of
  each picker list its own.
  """

  use Phoenix.Component

  import Koyomi.Components.Shared

  alias Koyomi.{DateRange, Holidays, ISOWeek, Messages, Month, Presets, Recurrence, Rules}
  alias Phoenix.HTML.FormField

  @v 1

  @doc """
  Renders a date picker: a field with a segment for each part of the date
  (typed, or changed with the arrow keys), and a calendar in a popover.

  The value is a `Date`; the picker posts `YYYY-MM-DD`, and nothing (an
  empty string) when it is cleared.
  """
  shared_attrs()

  def date_picker(assigns) do
    assigns |> prepare(:date) |> picker()
  end

  @doc """
  Renders a date range picker: a field with the first and the last day,
  and a calendar where the first click starts the range and the second
  ends it, with the range drawn as the pointer moves.

  Give it one field of the `Koyomi.DateRange` type (`field`), which it
  posts as `field[from]` and `field[to]`, or two `:date` fields (`from` and
  `to`), which it posts as they are. It posts only whole ranges: while one
  end is chosen, the form keeps the previous value.

  The rules `:min_days`, `:max_days` and `:allow_disabled_in_range` apply
  to the range; days that the range could not reach from its first day
  are disabled while the second is chosen.
  """
  shared_attrs()

  attr :from, FormField, default: nil, doc: "the field of the first day, with `to`"
  attr :to, FormField, default: nil, doc: "the field of the last day, with `from`"

  attr :nights, :boolean,
    default: false,
    doc: "when `true`, the picker counts nights (days minus one), as for a stay"

  def date_range_picker(assigns) do
    assigns |> prepare(:range) |> picker()
  end

  @doc """
  Renders a picker of several days, each added or removed with a click,
  and listed in the field.

  The value is a list of `Date`; the picker posts `field[]` for each day,
  after an empty first entry, so that a form with no day still posts the
  field (see `Koyomi.Dates`). The rules `:min_count` and `:max_count`
  apply.
  """
  shared_attrs()

  def dates_picker(assigns) do
    assigns |> prepare(:dates) |> picker()
  end

  @doc """
  Renders a month picker: a field with the month and the year, and a grid
  of the months of a year. It posts `YYYY-MM`; the `Koyomi.Month` type
  stores it as the first day of the month.
  """
  shared_attrs()

  def month_picker(assigns) do
    assigns |> prepare(:month) |> picker()
  end

  @doc """
  Renders a year picker: a field with the year, and a grid of years. It
  posts the year as an integer.
  """
  shared_attrs()

  def year_picker(assigns) do
    assigns |> prepare(:year) |> picker()
  end

  @doc """
  Renders an ISO week picker: a calendar with week numbers, where a click
  picks the whole week. It posts `YYYY-Www`; the `Koyomi.Week` type stores
  it as the Monday of the week.
  """
  shared_attrs()

  def week_picker(assigns) do
    assigns |> prepare(:week) |> picker()
  end

  @doc """
  Renders a time picker: a field with the hour, the minutes (and the
  seconds with `seconds`), in the 12 or 24-hour clock of the locale, and a
  list of times in a popover.

  It posts `HH:MM:SS`. The rules `:min_time`, `:max_time` and `:step`
  apply; `step` is also the step of the list (30 minutes when not given).
  """
  shared_attrs()

  attr :seconds, :boolean, default: false, doc: "when `true`, the field has seconds"

  attr :hour_cycle, :string,
    default: nil,
    values: [nil, "h12", "h23"],
    doc: "the 12 or 24-hour clock; the default is the locale's"

  def time_picker(assigns) do
    assigns |> prepare(:time) |> picker()
  end

  @doc """
  Renders a date and time picker: the date field and calendar of
  `date_picker/1` with the time field and list of `time_picker/1`.

  With a `time_zone`, the person picks a wall clock time in that zone, and
  the picker posts it with the zone's offset at that moment
  (`2027-03-15T14:30:00+01:00`, or `Z` when the offset is zero), which a
  `:utc_datetime` field casts to
  UTC; a time that the zone skips or repeats on that day (when the clocks
  change) is shown and resolved before it is posted. Without a
  `time_zone`, it posts a date and time without an offset, for a
  `:naive_datetime` field.

  With `slots`, the times come from the LiveView, for the day that is
  chosen (the `slots` of the day content, see `Koyomi.Live`), as for a
  booking; the calendar then also asks for the days (`days`).
  """
  shared_attrs()

  attr :seconds, :boolean, default: false, doc: "when `true`, the field has seconds"

  attr :hour_cycle, :string,
    default: nil,
    values: [nil, "h12", "h23"],
    doc: "the 12 or 24-hour clock; the default is the locale's"

  attr :slots, :boolean,
    default: false,
    doc: "when `true`, the times of a day are the slots that the LiveView gives"

  attr :ambiguous, :atom,
    default: :earlier,
    values: [:earlier, :later],
    doc:
      "the instant of a wall clock time that happens twice (when the clocks go back), until the person picks the other"

  def datetime_picker(assigns) do
    assigns |> prepare(:datetime) |> picker()
  end

  @doc """
  Renders a recurrence picker: how often something repeats (every day,
  week, month or year, every so many), on which days, and until when,
  with a sentence that says it and the next dates.

  It posts an RFC 5545 rule (`FREQ=WEEKLY;BYDAY=MO,WE`), or nothing for
  "does not repeat"; the `Koyomi.Recurrence` type casts it.
  """
  shared_attrs()

  attr :start, :any,
    default: nil,
    doc:
      "the first occurrence (a `Date` or a `DateTime`), for the days and the next dates; today by default"

  def recurrence_picker(assigns) do
    assigns |> prepare(:recurrence) |> picker()
  end

  @doc """
  Renders a calendar on the page, with no field: to show days and their
  content, and to pick a day, a range or several days outside a form.

  With `select`, a click picks, and the picker pushes `on_change` with the
  value. With a `name`, it also posts the value with a form.
  """
  shared_attrs()

  attr :select, :string,
    default: nil,
    values: [nil, "date", "range", "dates"],
    doc: "what a click picks; nothing by default"

  def calendar(assigns) do
    assigns |> assign(:inline, true) |> prepare(:calendar) |> picker()
  end

  # The element of every picker. Its children are the inputs that the form
  # posts; the hook keeps them and builds the picker around them, and
  # phx-update="ignore" keeps a render from taking them back. The server's
  # later values and options reach the hook through data-value and
  # data-config, which a render updates.
  defp picker(assigns) do
    ~H"""
    <div
      id={@id}
      class={["koyomi", "koyomi-#{@kind_class}", @inline && "koyomi-inline", @class]}
      phx-hook="Koyomi"
      phx-update="ignore"
      data-config={@config}
      data-value={@wire}
      {@rest}
    >
      <.native_inputs {assigns} />
    </div>
    """
  end

  defp native_inputs(%{kind: :range} = assigns) do
    ~H"""
    <input
      :for={{part, name, value, label} <- @range_inputs}
      type="date"
      class="koyomi-native"
      data-part={part}
      name={name}
      value={value}
      min={@native_min}
      max={@native_max}
      required={@required}
      disabled={@disabled}
      readonly={@readonly}
      aria-label={label}
    />
    """
  end

  defp native_inputs(%{kind: :dates} = assigns) do
    ~H"""
    <input type="hidden" name={@input_name <> "[]"} value="" data-part="sentinel" />
    <input
      :for={value <- @dates_values ++ [""]}
      type="date"
      class="koyomi-native"
      data-part="date"
      name={@input_name <> "[]"}
      value={value}
      min={@native_min}
      max={@native_max}
      disabled={@disabled}
      readonly={@readonly}
      {@label_attrs}
    />
    """
  end

  defp native_inputs(%{kind: :calendar, input_name: nil} = assigns), do: ~H""

  defp native_inputs(%{kind: :calendar} = assigns) do
    ~H"""
    <input type="hidden" name={@input_name} value={@native_value} data-part="value" />
    """
  end

  defp native_inputs(assigns) do
    ~H"""
    <input
      type={@native_type}
      class="koyomi-native"
      data-part="value"
      id={@input_id}
      name={@input_name}
      value={@native_value}
      min={@native_min}
      max={@native_max}
      step={@native_step}
      required={@required}
      disabled={@disabled}
      readonly={@readonly}
      {@label_attrs}
    />
    """
  end

  # Everything the template and the hook need, from the attributes.
  defp prepare(assigns, kind) do
    field = assigns.field
    rules = rules(assigns)
    locale = assigns.locale || Application.get_env(:koyomi, :locale, "en")
    time_zone = assigns.time_zone || Application.get_env(:koyomi, :time_zone)
    rules = if time_zone, do: %{rules | time_zone: time_zone}, else: rules
    today = Rules.today(rules)
    input_name = input_name(assigns, field)
    value = value(assigns, field, kind)
    id = assigns.id || default_id(assigns, field, input_name, kind)
    {rest, described_by, aria_invalid} = take_aria(assigns.rest)
    invalid = aria_invalid || invalid?(field)
    label = assigns.label || default_label(field, input_name)

    assigns =
      assigns
      |> assign(:kind, kind)
      |> assign(:kind_class, kind_class(kind, assigns))
      |> assign(:id, id)
      |> assign(:rest, rest)
      |> assign(:input_name, input_name)
      |> assign(:input_id, field && field.id)
      |> assign(:label_attrs, label_attrs(assigns.label_id, label))
      |> assign(:required, assigns.required)

    wire = wire(kind, value, assigns)

    assigns
    |> assign(:wire, JSON.encode!(wire))
    |> assign(
      :config,
      JSON.encode!(
        config(assigns, %{
          kind: kind,
          rules: rules,
          locale: locale,
          time_zone: time_zone,
          today: today,
          described_by: described_by,
          invalid: invalid,
          label: label
        })
      )
    )
    |> assign_native(kind, wire, rules)
  end

  defp kind_class(:calendar, %{select: select}) when is_binary(select), do: "calendar"
  defp kind_class(kind, _assigns), do: Atom.to_string(kind)

  defp rules(assigns) do
    rules = Rules.new(assigns.rules)
    shortcuts = Enum.reject([min: assigns.min, max: assigns.max], fn {_k, v} -> is_nil(v) end)
    if shortcuts == [], do: rules, else: Rules.merge(rules, shortcuts)
  end

  defp input_name(%{name: name}, _field) when is_binary(name), do: name
  defp input_name(_assigns, %FormField{name: name}), do: name
  defp input_name(%{from: %FormField{}}, nil), do: nil
  defp input_name(_assigns, nil), do: nil

  defp value(%{field: %FormField{value: value}}, _field, _kind), do: value
  defp value(%{value: value}, _field, _kind), do: value

  defp default_id(_assigns, %FormField{id: id}, _name, _kind), do: id <> "_picker"
  defp default_id(%{from: %FormField{id: id}}, nil, _name, _kind), do: id <> "_range_picker"

  defp default_id(_assigns, nil, name, _kind) when is_binary(name),
    do: String.replace(name, ~r/[^A-Za-z0-9_-]+/, "_") <> "_picker"

  defp default_id(_assigns, nil, nil, kind) do
    raise ArgumentError,
          "Koyomi.Components: a #{kind} picker needs an `id`, a `field` or a `name`"
  end

  defp take_aria(rest) do
    described_by = rest[:"aria-describedby"]
    aria_invalid = rest[:"aria-invalid"] in [true, "true"]
    {Map.drop(rest, [:"aria-describedby", :"aria-invalid"]), described_by, aria_invalid}
  end

  defp invalid?(%FormField{errors: [_ | _]} = field), do: Phoenix.Component.used_input?(field)
  defp invalid?(_field), do: false

  defp default_label(%FormField{field: field}, _name), do: humanize(field)
  defp default_label(nil, name) when is_binary(name), do: humanize(name)
  defp default_label(nil, nil), do: nil

  defp humanize(name) do
    name
    |> to_string()
    |> String.split(["[", "]"], trim: true)
    |> List.last()
    |> Phoenix.Naming.humanize()
  end

  defp label_attrs(label_id, _label) when is_binary(label_id),
    do: %{"aria-labelledby" => label_id}

  defp label_attrs(nil, label) when is_binary(label), do: %{"aria-label" => label}
  defp label_attrs(nil, nil), do: %{}

  # The value as the hook reads it from data-value: an ISO string, a map
  # of from and to, a list of ISO dates, or null.
  defp wire(:date, value, _assigns), do: iso_date(value)

  defp wire(:range, _value, %{from: %FormField{} = from, to: %FormField{} = to}),
    do: %{"from" => iso_date(from.value), "to" => iso_date(to.value)}

  defp wire(:range, value, _assigns), do: range_wire(value)

  defp wire(:dates, value, _assigns), do: dates_wire(value)

  defp wire(:month, %Date{} = date, _assigns), do: Month.to_iso8601(date)
  defp wire(:month, value, _assigns), do: blank_to_nil(value)

  defp wire(:year, value, _assigns) when is_integer(value), do: Integer.to_string(value)
  defp wire(:year, %Date{year: year}, _assigns), do: Integer.to_string(year)
  defp wire(:year, value, _assigns), do: blank_to_nil(value)

  defp wire(:week, %Date{} = date, _assigns), do: ISOWeek.to_iso8601(date)
  defp wire(:week, value, _assigns), do: blank_to_nil(value)

  defp wire(:time, %Time{} = time, _assigns),
    do: time |> Time.truncate(:second) |> Time.to_iso8601()

  defp wire(:time, value, _assigns), do: blank_to_nil(value)

  defp wire(:datetime, %DateTime{} = value, _assigns),
    do: value |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp wire(:datetime, %NaiveDateTime{} = value, _assigns),
    do: value |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()

  defp wire(:datetime, value, _assigns), do: blank_to_nil(value)

  defp wire(:recurrence, %Recurrence{} = rule, _assigns), do: Recurrence.to_string(rule)
  defp wire(:recurrence, value, _assigns), do: blank_to_nil(value)

  defp wire(:calendar, value, %{select: "range"}), do: range_wire(value)
  defp wire(:calendar, value, %{select: "dates"}), do: dates_wire(value)
  defp wire(:calendar, value, _assigns), do: iso_date(value)

  defp iso_date(%Date{} = date), do: Date.to_iso8601(date)
  defp iso_date(%DateTime{} = value), do: value |> DateTime.to_date() |> Date.to_iso8601()

  defp iso_date(%NaiveDateTime{} = value),
    do: value |> NaiveDateTime.to_date() |> Date.to_iso8601()

  defp iso_date(value), do: blank_to_nil(value)

  defp range_wire(%Date.Range{} = range), do: DateRange.to_params(range)

  defp range_wire(%{} = map) when not is_struct(map) do
    %{
      "from" => iso_date(Map.get(map, "from", Map.get(map, :from))),
      "to" => iso_date(Map.get(map, "to", Map.get(map, :to)))
    }
  end

  defp range_wire(text) when is_binary(text) do
    case String.split(text, "/") do
      [from, to] -> %{"from" => blank_to_nil(from), "to" => blank_to_nil(to)}
      _other -> %{"from" => nil, "to" => nil}
    end
  end

  defp range_wire(_value), do: %{"from" => nil, "to" => nil}

  defp dates_wire(list) when is_list(list) do
    list |> Enum.map(&iso_date/1) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()
  end

  defp dates_wire(text) when is_binary(text), do: text |> String.split(",") |> dates_wire()
  defp dates_wire(_value), do: []

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value) when is_binary(value), do: String.trim(value)
  defp blank_to_nil(value), do: to_string(value)

  # The browser's own inputs, for the first paint and without JavaScript.
  defp assign_native(assigns, kind, wire, rules) do
    {type, value, native_min, native_max, step} = native(kind, wire, rules, assigns)

    assigns
    |> assign(:native_type, type)
    |> assign(:native_value, value)
    |> assign(:native_min, native_min)
    |> assign(:native_max, native_max)
    |> assign(:native_step, step)
    |> assign(:dates_values, if(kind == :dates, do: wire, else: []))
    |> assign(:range_inputs, range_inputs(kind, wire, assigns))
  end

  defp native(kind, wire, rules, _assigns) when kind in [:date, :range, :dates] do
    min = rules |> Rules.min_date() |> iso()
    max = rules |> Rules.max_date() |> iso()
    {"date", if(kind == :date, do: wire), min, max, nil}
  end

  defp native(:month, wire, rules, _assigns),
    do:
      {"month", wire, bound(rules, :min, &Month.to_iso8601/1),
       bound(rules, :max, &Month.to_iso8601/1), nil}

  defp native(:year, wire, rules, _assigns),
    do: {"number", wire, bound(rules, :min, & &1.year), bound(rules, :max, & &1.year), 1}

  defp native(:week, wire, rules, _assigns),
    do:
      {"week", wire, bound(rules, :min, &ISOWeek.to_iso8601/1),
       bound(rules, :max, &ISOWeek.to_iso8601/1), nil}

  defp native(:time, wire, rules, assigns),
    do: {"time", wire, time(rules.min_time), time(rules.max_time), time_step(rules, assigns)}

  defp native(:datetime, wire, rules, assigns),
    do: {"datetime-local", naive_local(wire, assigns), nil, nil, time_step(rules, assigns)}

  defp native(:recurrence, wire, _rules, _assigns), do: {"text", wire, nil, nil, nil}

  defp native(:calendar, wire, _rules, _assigns),
    do: {"hidden", calendar_value(wire), nil, nil, nil}

  defp bound(rules, :min, fun), do: rules |> Rules.min_date() |> then(&(&1 && fun.(&1)))
  defp bound(rules, :max, fun), do: rules |> Rules.max_date() |> then(&(&1 && fun.(&1)))

  defp iso(nil), do: nil
  defp iso(%Date{} = date), do: Date.to_iso8601(date)

  defp time(nil), do: nil
  defp time(%Time{} = time), do: time |> Time.truncate(:second) |> Time.to_iso8601()

  defp time_step(rules, assigns) do
    cond do
      rules.step -> rules.step * 60
      assigns[:seconds] -> 1
      true -> nil
    end
  end

  # The browser's datetime-local input has no zone: it shows the wall clock
  # of the picker's zone when the server knows it, else the time as given.
  defp naive_local(nil, _assigns), do: nil

  defp naive_local(wire, assigns) do
    with zone when is_binary(zone) <- assigns[:time_zone],
         {:ok, instant, _offset} <- DateTime.from_iso8601(wire),
         {:ok, local} <- DateTime.shift_zone(instant, zone) do
      local |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()
    else
      _other -> wire |> String.replace(~r/(Z|[+-]\d{2}:\d{2})$/, "")
    end
  end

  defp calendar_value(%{"from" => from, "to" => to}) when is_binary(from) and is_binary(to),
    do: from <> "/" <> to

  defp calendar_value(list) when is_list(list), do: Enum.join(list, ",")
  defp calendar_value(value) when is_binary(value), do: value
  defp calendar_value(_value), do: ""

  defp range_inputs(:range, wire, %{from: %FormField{} = from, to: %FormField{} = to} = assigns) do
    [
      {"from", from.name, wire["from"], part_label(assigns, "from")},
      {"to", to.name, wire["to"], part_label(assigns, "to")}
    ]
  end

  defp range_inputs(:range, wire, assigns) do
    name = assigns.input_name

    [
      {"from", name && name <> "[from]", wire["from"], part_label(assigns, "from")},
      {"to", name && name <> "[to]", wire["to"], part_label(assigns, "to")}
    ]
  end

  defp range_inputs(_kind, _wire, _assigns), do: []

  defp part_label(assigns, "from"),
    do: Messages.for_locale(locale(assigns), assigns.messages)["startDate"]

  defp part_label(assigns, "to"),
    do: Messages.for_locale(locale(assigns), assigns.messages)["endDate"]

  defp locale(assigns), do: assigns.locale || Application.get_env(:koyomi, :locale, "en")

  # The options of the hook, in data-config: the field's, then the
  # calendar's, then the kind's own. Empty values are left out.
  defp config(assigns, context) do
    assigns
    |> field_config(context)
    |> Map.merge(calendar_config(assigns, context))
    |> Map.merge(kind_config(assigns, context))
    |> Enum.reject(fn {_key, value} -> value in [nil, false, [], %{}] end)
    |> Map.new()
  end

  defp field_config(assigns, context) do
    %{
      "v" => @v,
      "kind" => Atom.to_string(context.kind),
      "locale" => context.locale,
      "typing" => assigns.typing,
      "clearable" => clearable(assigns),
      "required" => assigns.required,
      "disabled" => assigns.disabled,
      "readonly" => assigns.readonly,
      "display" => assigns.display,
      "label" => context.label,
      "labelId" => assigns.label_id,
      "describedBy" => context.described_by,
      "invalid" => context.invalid,
      "rules" => Rules.to_client(context.rules),
      "onChange" => assigns.on_change,
      "messages" => Messages.for_locale(context.locale, assigns.messages)
    }
  end

  defp clearable(%{clearable: nil, required: required}), do: not required
  defp clearable(%{clearable: clearable}), do: clearable

  defp calendar_config(assigns, context) do
    %{
      "calendar" => assigns.calendar,
      "timeZone" => context.time_zone,
      "today" => Date.to_iso8601(context.today),
      "firstDay" => assigns.first_day,
      "months" => assigns.months,
      "inline" => assigns.inline,
      "weekNumbers" => assigns.week_numbers or context.kind == :week,
      "outsideDays" => assigns.outside_days,
      "presets" => presets(assigns, context.kind, context.today, assigns.first_day || 1),
      "holidays" => holidays(assigns.holidays, context.rules, context.today, context.locale),
      "days" => assigns.days or Map.get(assigns, :slots, false)
    }
  end

  # The attributes that only some pickers have.
  defp kind_config(assigns, context) do
    %{
      "slots" => Map.get(assigns, :slots, false),
      "seconds" => Map.get(assigns, :seconds, false),
      "hourCycle" => Map.get(assigns, :hour_cycle),
      "ambiguous" => assigns |> Map.get(:ambiguous) |> atom_string(),
      "nights" => Map.get(assigns, :nights, false),
      "select" => Map.get(assigns, :select),
      "start" => start(Map.get(assigns, :start), context.today)
    }
  end

  defp atom_string(nil), do: nil
  defp atom_string(atom), do: Atom.to_string(atom)

  defp presets(%{presets: nil}, _kind, _today, _first_day), do: nil

  defp presets(%{presets: presets}, kind, today, first_day) do
    kind = if kind == :calendar, do: :date, else: kind
    Presets.resolve(presets, kind, today, first_day)
  end

  defp holidays(nil, _rules, _today, _locale), do: nil

  defp holidays(sources, rules, today, locale) do
    first_year = max(year(Rules.min_date(rules), today.year - 2), today.year - 10)
    last_year = min(year(Rules.max_date(rules), today.year + 3), today.year + 10)
    first_year = min(first_year, last_year)

    Holidays.to_client(
      sources,
      Date.range(Date.new!(first_year, 1, 1), Date.new!(last_year, 12, 31)),
      locale
    )
  end

  defp year(nil, default), do: default
  defp year(%Date{year: year}, _default), do: year

  defp start(nil, _today), do: nil

  # After a phx-change the field's value is the posted string.
  defp start(text, today) when is_binary(text) do
    case Date.from_iso8601(String.slice(text, 0, 10)) do
      {:ok, date} -> start(date, today)
      {:error, _reason} -> nil
    end
  end

  defp start(%Date{} = date, _today), do: Date.to_iso8601(date)
  defp start(%DateTime{} = value, _today), do: value |> DateTime.to_date() |> Date.to_iso8601()

  defp start(%NaiveDateTime{} = value, _today),
    do: value |> NaiveDateTime.to_date() |> Date.to_iso8601()
end
