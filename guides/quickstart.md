# Quickstart

This guide adds date pickers to a Phoenix 1.8 app with LiveView 1.2. At
the end, a LiveView form has a date picker and a range picker, the schema
stores a date and a range of days, and the changeset checks the same
rules as the pickers.

Your app does not run Node.js for Koyomi. The Hex package has the built
bundle, and your esbuild profile imports it from `deps/`.

## 1. Add the dependency

In `mix.exs`:

```elixir
def deps do
  [
    {:koyomi, "~> 0.1"}
  ]
end
```

Then run `mix deps.get`.

Koyomi needs Elixir 1.18 or later. The `Koyomi.DateRange` type of this
guide stores a PostgreSQL `daterange`, so it needs `:postgrex`, which a
Phoenix app with Ecto already has.

## 2. Run the installer

```sh
mix koyomi.install --dry-run   # shows the changes as a diff
mix koyomi.install
```

The installer changes two files, and prints what it changed:

* `assets/js/app.js`: it adds `import { Koyomi } from "koyomi"` and puts
  `Koyomi` in the `hooks` of the `LiveSocket`.
* `assets/css/app.css`: it adds the Koyomi style sheet, and the Sumi theme
  import as a comment.

It does not add what a file already has, so you can run it again. When it
cannot find the `new LiveSocket(...)` call, or its `hooks` are not an
object or a variable, it changes nothing in `app.js` and prints the lines
to add. After the edits it prints a note on `NODE_PATH` (see step 3) and
how to start the pickers on a page without LiveView.

## 2b. Or make the changes by hand

```js
// assets/js/app.js
import { Koyomi } from "koyomi"

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, Koyomi},
})
```

Put the CSS lines below the other `@import` lines of `app.css`:

```css
/* assets/css/app.css */
@import "../../deps/koyomi/priv/static/koyomi.css";
/* The Sumi theme, when you want it: */
/* @import "../../deps/koyomi/priv/static/koyomi-sumi.css"; */
```

## 3. Let esbuild find `koyomi` in `deps/`

The import `from "koyomi"` resolves through `NODE_PATH`. The Phoenix
generators already give the esbuild profile a `NODE_PATH` with `deps/`.
If your profile has no `NODE_PATH`, add it in `config/config.exs`:

```elixir
config :esbuild,
  my_app: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]
```

The installer prints this note when the profile has no `NODE_PATH`.

### A path dependency

Mix does not copy a path dependency (`{:koyomi, path: "../koyomi"}`) into
`deps/`. The installer then points the `@import` lines of `app.css` at the
dependency's directory, and prints the `NODE_PATH` entry that esbuild
needs: the directory that holds the dependency, relative to `config/`:

```elixir
env: %{
  "NODE_PATH" => [
    Path.expand("../deps", __DIR__),
    Path.expand("../..", __DIR__),
    Mix.Project.build_path()
  ]
}
```

A checkout of Koyomi has no built bundle until `mix koyomi.build` runs in
it, so run that task in the Koyomi directory before the app's
`mix assets.build`.

## 4. Choose the locale and the time zone

Each picker takes a `locale` and a `time_zone`. Without them, it reads
the config, and then uses `"en"` and UTC:

```elixir
# config/config.exs
config :koyomi, locale: "en-GB", time_zone: "Europe/Lisbon"
```

The time zone decides what "today" is, for the `:today` rule and the
Today button. A zone other than UTC needs a time zone database on the
server, such as `tz` or `tzdata`. See the [Time zones](time_zones.md)
guide.

## 5. Add the fields to a schema

```elixir
# The migration
alter table(:bookings) do
  add :due, :date
  add :stay, :daterange
end
```

```elixir
defmodule MyApp.Bookings.Booking do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookings" do
    field :due, :date
    field :stay, Koyomi.DateRange

    timestamps()
  end

  @due_rules Koyomi.Rules.new(min: :today, disabled_weekdays: [6, 7])
  @stay_rules Koyomi.Rules.new(min: :today, min_days: 2, max_days: 14)

  def due_rules, do: @due_rules
  def stay_rules, do: @stay_rules

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:due, :stay])
    |> validate_required([:due, :stay])
    |> Koyomi.Changeset.validate_date(:due, @due_rules)
    |> Koyomi.Changeset.validate_range(:stay, @stay_rules)
  end
end
```

`Koyomi.DateRange` stores a `Date.Range` with both ends included.
Without PostgreSQL, keep the two ends in two `:date` fields: see
"Two fields for a range" in the [Rules](rules.md) guide.

`:today` is read again on each check, so rules built once, in a module
attribute, stay right the next day.

## 6. Put the pickers in a LiveView form

Import the components, for example in the `html_helpers` of your web
module (`lib/my_app_web.ex`). The installer does not add this line:

```elixir
import Koyomi.Components
```

Then a LiveView with the form:

```elixir
defmodule MyAppWeb.BookingLive.New do
  use MyAppWeb, :live_view

  alias MyApp.Bookings.Booking
  alias MyApp.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(Booking.changeset(%Booking{}, %{})))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form for={@form} id="booking-form" phx-change="validate" phx-submit="save">
      <label id="due-label">Due</label>
      <.date_picker field={@form[:due]} label_id="due-label" rules={Booking.due_rules()} />
      <p :for={msg <- errors(@form[:due])} class="error">{msg}</p>

      <label id="stay-label">Stay</label>
      <.date_range_picker
        field={@form[:stay]}
        label_id="stay-label"
        rules={Booking.stay_rules()}
        months={2}
        nights
      />
      <p :for={msg <- errors(@form[:stay])} class="error">{msg}</p>

      <.button>Book</.button>
    </.form>
    """
  end

  defp errors(field) do
    if used_input?(field), do: Enum.map(field.errors, &translate_error/1), else: []
  end

  @impl true
  def handle_event("validate", %{"booking" => params}, socket) do
    changeset = Booking.changeset(%Booking{}, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"booking" => params}, socket) do
    case %Booking{} |> Booking.changeset(params) |> Repo.insert() do
      {:ok, _booking} -> {:noreply, put_flash(socket, :info, "Booked")}
      {:error, changeset} -> {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
```

`translate_error/1` is the function of your app's `CoreComponents`.

Give the same rules to the picker and to the changeset. The picker
disables in the calendar what the rules refuse, and the changeset refuses
it on the server, so the two never disagree.

The pickers post their values with the form, so the form's own
`phx-change` and `phx-submit` events have them, and the LiveView needs no
other event. The date picker posts `due` as `2027-03-15`; the range picker
posts `stay[from]` and `stay[to]`, which `Koyomi.DateRange` casts. The
[Forms](forms.md) guide has the wire form of each picker.

To edit a booking, build the form from it (`Booking.changeset(booking,
%{})`): each picker starts with the field's value.

## 7. Done

Start the server and open the page. Before the hook mounts, and with
JavaScript off, each picker is the browser's own input of its kind
(`<input type="date">`), with the same name and value, so the form still
works.

## Next

* [Pickers](pickers.md): every picker, what it posts, and its attributes.
* [Forms](forms.md): the wire forms, errors, server pushes, pages without
  LiveView.
* [Rules](rules.md): the rules, the changeset functions and their errors.
* [Typing dates](typing.md): segments and plain words.
* [Locales and calendars](calendars.md), [Time zones](time_zones.md),
  [Day content](days.md) and [Recurrence](recurrence.md).
* [Testing](testing.md) and [Theming](theming.md).
* [Accessibility](accessibility.md) and [Known limits](limits.md).
