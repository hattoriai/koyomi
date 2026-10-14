defmodule Koyomi.Components.Shared do
  @moduledoc false

  # The attributes that every picker of Koyomi.Components has, declared
  # once. `shared_attrs/0` expands into `attr` calls, in the component
  # module, before each picker function.

  defmacro shared_attrs do
    quote do
      attr :field, Phoenix.HTML.FormField,
        default: nil,
        doc: "the form field, for example `@form[:due]`"

      attr :id, :string,
        default: nil,
        doc: "the id of the picker element; the default is the field's id with `_picker`"

      attr :name, :string,
        default: nil,
        doc: "the input name, without a `field`"

      attr :value, :any, default: nil, doc: "the value, without a `field`"

      attr :label_id, :string,
        default: nil,
        doc:
          "the id of the element that labels the picker (`aria-labelledby`); without it, the picker gets `aria-label` from `label`"

      attr :label, :string,
        default: nil,
        doc:
          "the accessible name when there is no `label_id`; the default is the field name in words"

      attr :rules, :any,
        default: nil,
        doc:
          "the rules of the picker, a `Koyomi.Rules` or its options; give the same to `Koyomi.Changeset`"

      attr :min, :any, default: nil, doc: "a shortcut for the `:min` rule"
      attr :max, :any, default: nil, doc: "a shortcut for the `:max` rule"

      attr :locale, :string,
        default: nil,
        doc:
          "a BCP 47 locale for names, numbers, the order of the fields and the first day of the week; the default is `config :koyomi, locale:`, else \"en\""

      attr :calendar, :string,
        default: nil,
        doc:
          "the calendar system of the display: `gregory` (the default), `japanese`, `buddhist`, `islamic-umalqura`, `hebrew`, `persian`, ... (see the Calendars guide)"

      attr :time_zone, :string,
        default: nil,
        doc:
          "the IANA time zone of today and, for a date and time picker, of the wall clock; the default is UTC"

      attr :first_day, :integer,
        default: nil,
        doc:
          "the first day of the week, ISO (1 is Monday, 7 is Sunday); the default is the locale's"

      attr :presets, :list,
        default: nil,
        doc: "the presets beside the calendar, see `Koyomi.Presets`"

      attr :holidays, :any,
        default: nil,
        doc:
          "public holidays to mark: a country code (\"PT\"), a `Koyomi.Holidays.Provider` module, or a list of them"

      attr :days, :boolean,
        default: false,
        doc:
          "when `true`, the picker asks the LiveView for the content of the days it shows (`koyomi:days`), see the Day content guide"

      attr :inline, :boolean,
        default: false,
        doc: "when `true`, the calendar is always shown, with no field and no popover"

      attr :months, :integer, default: 1, doc: "the months shown side by side"

      attr :week_numbers, :boolean,
        default: false,
        doc: "when `true`, the calendar shows ISO week numbers"

      attr :outside_days, :boolean,
        default: true,
        doc: "when `false`, the days of the previous and next months are left blank"

      attr :typing, :boolean,
        default: true,
        doc: "when `false`, the popover has no box for typing a date in words"

      attr :clearable, :boolean,
        default: nil,
        doc: "when `true`, the field has a clear button; the default is `true` unless `required`"

      attr :required, :boolean, default: false
      attr :disabled, :boolean, default: false
      attr :readonly, :boolean, default: false

      attr :display, :string,
        default: "medium",
        values: ~w(short medium long full),
        doc: "the length of the dates that the picker writes out (`Intl` `dateStyle`)"

      attr :on_change, :string,
        default: nil,
        doc:
          "an event that the picker pushes with `%{\"id\", \"value\"}` on each change, for a picker outside a form"

      attr :messages, :map,
        default: nil,
        doc: "words that replace the built-in ones, see `Koyomi.Messages`"

      attr :class, :any, default: nil, doc: "classes for the picker element"

      attr :rest, :global,
        include: ~w(form),
        doc:
          "attributes for the picker element, such as `phx-target`; `aria-describedby` goes to the field"
    end
  end
end
