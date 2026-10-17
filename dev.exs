# The Koyomi development server: `mix dev`, then http://localhost:4099.
#
# One Phoenix endpoint with every picker on a few pages, the built bundle
# from priv/static, and a fake availability service for the day content.
# The browser tests in e2e/ run against it.
#
# The bundle rebuilds and the page reloads on a change.
#
# Query params of every page: `locale` (a BCP 47 locale), `calendar` (an
# Intl calendar id), `zone` (an IANA time zone), `theme=sumi`,
# `icons=custom` (icons of the app, with setIcons).
#
# Environment:
#
#   * PORT - the HTTP port (4099).
#   * KOYOMI_DEV_WATCH - "false" starts no esbuild watcher and no live
#     reload, for the browser tests; the bundle must be built first.

port = "PORT" |> System.get_env("4099") |> String.to_integer()
watch? = System.get_env("KOYOMI_DEV_WATCH") != "false"

Application.put_env(:phoenix, :json_library, JSON)
Application.put_env(:elixir, :time_zone_database, Tz.TimeZoneDatabase)
Logger.configure(level: :info)

Application.put_env(:koyomi, KoyomiDev.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  check_origin: false,
  code_reloader: watch?,
  debug_errors: true,
  http: [ip: {127, 0, 0, 1}, port: port],
  live_view: [signing_salt: "koyomi-dev-live-view-salt"],
  pubsub_server: KoyomiDev.PubSub,
  render_errors: [formats: [html: KoyomiDev.ErrorHTML], layout: false],
  secret_key_base: String.duplicate("koyomi-development-secret-", 3),
  server: true,
  url: [host: "localhost"],
  watchers:
    if(watch?,
      do: [koyomi_esm: {Esbuild, :install_and_run, [:koyomi_esm, ~w(--watch)]}],
      else: []
    ),
  live_reload: [
    patterns: [
      ~r"priv/static/.*\.(js|css)$",
      ~r"lib/koyomi/.*\.ex$"
    ]
  ]
)

defmodule KoyomiDev.Event do
  @moduledoc "An embedded schema with a field for each picker, and the same rules as the pickers."
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :due, :date
    field :stay, Koyomi.DateRange
    field :days, Koyomi.Dates, default: []
    field :month, Koyomi.Month
    field :week, Koyomi.Week
    field :year, :integer
    field :at, :time
    field :starts_at, :utc_datetime
    field :local_at, :naive_datetime
    field :repeat, Koyomi.Recurrence
  end

  def due_rules,
    do: Koyomi.Rules.new(min: {:today, -30}, max: {:today, 365}, disabled_weekdays: [7])

  def stay_rules, do: Koyomi.Rules.new(min: :today, min_days: 2, max_days: 14)
  def days_rules, do: Koyomi.Rules.new(max_count: 5)
  def time_rules, do: Koyomi.Rules.new(min_time: ~T[08:00:00], max_time: ~T[18:00:00], step: 15)

  def changeset(event \\ %__MODULE__{}, params, zone) do
    event
    |> cast(params, [:due, :stay, :days, :month, :week, :year, :at, :local_at, :repeat])
    |> Koyomi.Changeset.cast_datetime(params, :starts_at, zone)
    |> Koyomi.Changeset.validate_date(:due, due_rules())
    |> Koyomi.Changeset.validate_range(:stay, stay_rules())
    |> Koyomi.Changeset.validate_dates(:days, days_rules())
    |> Koyomi.Changeset.validate_time(:at, time_rules())
  end
end

defmodule KoyomiDev.Rooms do
  @moduledoc """
  A fake availability service: a price for each night, full on Wednesdays,
  a few bookings as marks, and time slots on weekdays.
  """

  def days(range, _id) do
    Map.new(range, fn date ->
      weekday = Date.day_of_week(date)
      price = 80 + rem(date.day * 7, 40) + if(weekday in [5, 6], do: 30, else: 0)

      cond do
        weekday == 3 ->
          {date, [disabled: true, label: "Full", tone: :danger, title: "No rooms left"]}

        rem(date.day, 5) == 0 ->
          {date,
           [
             label: "€#{price}",
             tone: :success,
             marks: [:warning],
             title: "2 rooms left, €#{price}"
           ]}

        true ->
          {date, [label: "€#{price}", title: "€#{price} a night"]}
      end
    end)
  end

  def slots(range, _id) do
    Map.new(range, fn date ->
      if Date.day_of_week(date) in [6, 7],
        do: {date, [slots: []]},
        else: {date, [slots: day_slots(date), marks: 1]}
    end)
  end

  defp day_slots(date) do
    for hour <- 9..16, minute <- [0, 30] do
      time = Time.new!(hour, minute, 0)

      %{
        time: time,
        label: Calendar.strftime(time, "%H:%M"),
        disabled: rem(date.day + hour, 4) == 0
      }
    end
  end

  def slow(range, id) do
    Process.sleep(800)
    days(range, id)
  end
end

defmodule KoyomiDev.Layouts do
  @moduledoc """
  The root layout: the style sheets, the import map and the LiveSocket.
  `?theme=sumi` also loads koyomi-sumi.css.
  """
  use Phoenix.Component

  def root(assigns) do
    assigns = assign(assigns, :sumi, assigns.conn.params["theme"] == "sumi")

    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>Koyomi development</title>
        <link rel="stylesheet" href="/assets/koyomi.css" />
        <link :if={@sumi} rel="stylesheet" href="/assets/koyomi-sumi.css" />
        <style>
          body { font-family: system-ui, sans-serif; margin: 0; background: #fafaf9; color: #1c1917; }
          body.sumi { background: var(--koyomi-background); color: var(--koyomi-text); font-family: var(--koyomi-font); }
          main { max-width: 56rem; margin: 0 auto; padding: 2rem 1rem; }
          nav a { margin-right: 1rem; }
          .label { display: block; font-weight: 600; margin: 1.25rem 0 0.375rem; }
          .error { color: #b91c1c; font-size: 0.875rem; margin: 0.25rem 0 0; }
          .row { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 1rem 0; }
          dl { display: grid; grid-template-columns: max-content 1fr; gap: 0.25rem 1rem; font-size: 0.875rem; }
          dd { margin: 0; font-family: ui-monospace, monospace; }
          .columns { display: grid; grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr)); gap: 1rem 2rem; }
        </style>
        <script type="importmap">
          {
            "imports": {
              "phoenix": "/vendor/phoenix/phoenix.mjs",
              "phoenix_live_view": "/vendor/phoenix_live_view/phoenix_live_view.esm.js",
              "koyomi": "/assets/koyomi.esm.js"
            }
          }
        </script>
        <script type="module">
          import { Socket } from "phoenix"
          import { LiveSocket } from "phoenix_live_view"
          import { Koyomi, mountKoyomi, setIcons } from "koyomi"

          if (new URLSearchParams(location.search).get("icons") === "custom") {
            setIcons({
              calendar: '<svg class="app-icon" viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="4" width="18" height="17" rx="2"/></svg>',
              chevron: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5l9 7-9 7z"/></svg>',
              close: () => Object.assign(document.createElement("span"), { className: "app-close" })
            })
          }

          if (document.querySelector("[data-phx-main]")) {
            const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
            const liveSocket = new LiveSocket("/live", Socket, {
              hooks: { Koyomi },
              params: { _csrf_token: csrfToken }
            })
            liveSocket.connect()
            window.liveSocket = liveSocket
          } else {
            mountKoyomi()
          }
        </script>
      </head>
      <body class={@sumi && "sumi"} data-theme={@conn.params["dark"] && "dark"}>
        <main>
          <nav>
            <a href="/">Pickers</a><a href="/days">Day content</a><a href="/calendars">Calendars</a><a href="/filters">Filters</a><a href="/plain">Without LiveView</a><a href="/?theme=sumi">Sumi theme</a>
          </nav>
          {@inner_content}
        </main>
      </body>
    </html>
    """
  end
end

defmodule KoyomiDev.Params do
  @moduledoc "The options of a page, from its query params."

  def assign_options(socket, params) do
    Phoenix.Component.assign(socket,
      locale: params["locale"] || "en-GB",
      calendar: params["calendar"],
      zone: params["zone"] || "Europe/Lisbon"
    )
  end
end

defmodule KoyomiDev.PickersLive do
  @moduledoc "A form with every picker, the posted params and the changeset."
  use Phoenix.LiveView

  import Koyomi.Components

  alias KoyomiDev.Event

  @impl true
  def mount(params, _session, socket) do
    socket = KoyomiDev.Params.assign_options(socket, params)

    {:ok,
     assign(socket,
       form: to_form(Event.changeset(%{}, socket.assigns.zone), as: :event),
       posted: %{},
       picked: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Pickers</h1>
    <.form for={@form} id="event-form" phx-change="validate" phx-submit="save">
      <div class="columns">
        <div>
          <label class="label" id="due-label">Due date</label>
          <.date_picker
            field={@form[:due]}
            label_id="due-label"
            rules={Event.due_rules()}
            presets={[:today, :tomorrow, {:in, 1, :week}, {:in, 1, :month}]}
            holidays="PT"
            locale={@locale}
            calendar={@calendar}
          />
          <.error field={@form[:due]} />

          <label class="label" id="stay-label">Stay</label>
          <.date_range_picker
            field={@form[:stay]}
            label_id="stay-label"
            rules={Event.stay_rules()}
            months={2}
            nights
            presets={[:this_week, :next_week, {:next, 7, :days}]}
            locale={@locale}
            calendar={@calendar}
          />
          <.error field={@form[:stay]} />

          <label class="label" id="days-label">Days off</label>
          <.dates_picker field={@form[:days]} label_id="days-label" rules={Event.days_rules()} locale={@locale} calendar={@calendar} />
          <.error field={@form[:days]} />

          <label class="label" id="month-label">Billing month</label>
          <.month_picker field={@form[:month]} label_id="month-label" locale={@locale} />

          <label class="label" id="week-label">Sprint</label>
          <.week_picker field={@form[:week]} label_id="week-label" locale={@locale} />

          <label class="label" id="year-label">Year</label>
          <.year_picker field={@form[:year]} label_id="year-label" locale={@locale} />
        </div>
        <div>
          <label class="label" id="at-label">Time</label>
          <.time_picker field={@form[:at]} label_id="at-label" rules={Event.time_rules()} locale={@locale} />
          <.error field={@form[:at]} />

          <label class="label" id="starts-at-label">Starts at ({@zone})</label>
          <.datetime_picker field={@form[:starts_at]} label_id="starts-at-label" time_zone={@zone} locale={@locale} calendar={@calendar} />
          <.error field={@form[:starts_at]} />

          <label class="label" id="local-at-label">Local date and time</label>
          <.datetime_picker field={@form[:local_at]} label_id="local-at-label" locale={@locale} />

          <label class="label" id="repeat-label">Repeat</label>
          <.recurrence_picker field={@form[:repeat]} label_id="repeat-label" locale={@locale} start={Date.utc_today()} />

          <label class="label" id="calendar-label">Calendar outside the form</label>
          <.calendar id="outside" select="range" on_change="picked" locale={@locale} calendar={@calendar} week_numbers />
          <p>Picked: <code id="picked" data-json={JSON.encode!(@picked)}>{inspect(@picked)}</code></p>
        </div>
      </div>
      <div class="row"><button type="submit">Save</button></div>
    </.form>
    <h2>Posted</h2>
    <pre id="posted" data-json={JSON.encode!(@posted)}>{inspect(@posted, pretty: true)}</pre>
    <h2>Changes</h2>
    <dl id="changes">
      <%= for {field, value} <- @form.source.changes do %>
        <dt>{field}</dt>
        <dd>{inspect(value)}</dd>
      <% end %>
    </dl>
    """
  end

  defp error(assigns) do
    ~H"""
    <p :for={{message, opts} <- if(Phoenix.Component.used_input?(@field), do: @field.errors, else: [])} class="error">
      {Enum.reduce(opts, message, fn {key, value}, acc -> String.replace(acc, "%{#{key}}", to_string(value)) end)}
    </p>
    """
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    changeset = params |> Event.changeset(socket.assigns.zone) |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset, as: :event), posted: params)}
  end

  def handle_event("save", %{"event" => params}, socket) do
    changeset = params |> Event.changeset(socket.assigns.zone) |> Map.put(:action, :insert)
    {:noreply, assign(socket, form: to_form(changeset, as: :event), posted: params)}
  end

  def handle_event("picked", %{"value" => value}, socket),
    do: {:noreply, assign(socket, picked: value)}
end

defmodule KoyomiDev.DaysLive do
  @moduledoc "Day content from the LiveView: prices, full days, marks, slots, a slow answer."
  use Phoenix.LiveView

  import Koyomi.Components

  @impl true
  def mount(params, _session, socket) do
    socket = KoyomiDev.Params.assign_options(socket, params)
    {:ok, assign(socket, form: to_form(%{}, as: :booking), posted: %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Day content</h1>
    <.form for={@form} id="booking-form" phx-change="validate">
      <label class="label" id="room-label">Room, with prices from the server</label>
      <.date_range_picker field={@form[:room]} label_id="room-label" days months={2} nights rules={[min: :today]} locale={@locale} />

      <label class="label" id="slow-label">The same, from a slow server (async)</label>
      <.date_range_picker field={@form[:slow]} label_id="slow-label" days locale={@locale} />

      <label class="label" id="slot-label">An appointment, from the server's slots</label>
      <.datetime_picker field={@form[:slot]} label_id="slot-label" slots time_zone={@zone} rules={[min: :today]} locale={@locale} />
    </.form>
    <label class="label">A calendar of bookings</label>
    <.calendar id="bookings" days holidays={["PT", "GB"]} months={2} locale={@locale} />
    <div class="row">
      <button phx-click="refresh">Refresh the days</button>
      <button phx-click="set">Set the room to next weekend</button>
      <button phx-click="open">Open the slot picker</button>
    </div>
    <pre id="posted" data-json={JSON.encode!(@posted)}>{inspect(@posted, pretty: true)}</pre>
    """
  end

  @impl true
  def handle_event("validate", %{"booking" => params}, socket),
    do: {:noreply, assign(socket, posted: params)}

  def handle_event("koyomi:days", %{"id" => "booking_slow_picker"} = params, socket),
    do: Koyomi.Live.handle_days(socket, params, &KoyomiDev.Rooms.slow/2, async: true)

  def handle_event("koyomi:days", %{"id" => "booking_slot_picker"} = params, socket),
    do: Koyomi.Live.handle_days(socket, params, &KoyomiDev.Rooms.slots/2)

  def handle_event("koyomi:days", params, socket),
    do: Koyomi.Live.handle_days(socket, params, &KoyomiDev.Rooms.days/2)

  def handle_event("refresh", _params, socket),
    do: {:noreply, Koyomi.Live.refresh_days(socket, "booking_room_picker")}

  def handle_event("set", _params, socket) do
    today = Date.utc_today()
    saturday = Date.add(today, rem(6 - Date.day_of_week(today) + 7, 7))

    {:noreply,
     Koyomi.Live.push_value(
       socket,
       "booking_room_picker",
       Date.range(saturday, Date.add(saturday, 1))
     )}
  end

  def handle_event("open", _params, socket),
    do: {:noreply, Koyomi.Live.open(socket, "booking_slot_picker")}

  @impl true
  def handle_async({:koyomi_days, _id, _ref} = name, result, socket),
    do: {:noreply, Koyomi.Live.handle_days_async(socket, name, result)}
end

defmodule KoyomiDev.CalendarsLive do
  @moduledoc "The same day in the calendar systems and locales of the world."
  use Phoenix.LiveView

  import Koyomi.Components

  @systems [
    {"en-GB", "gregory"},
    {"ja-JP", "japanese"},
    {"th-TH", "buddhist"},
    {"zh-TW", "roc"},
    {"fa-IR", "persian"},
    {"ar-SA", "islamic-umalqura"},
    {"he-IL", "hebrew"},
    {"zh-CN", "chinese"},
    {"hi-IN", "indian"},
    {"am-ET", "ethiopic"}
  ]

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, systems: @systems)}

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Calendars</h1>
    <div class="columns">
      <div :for={{locale, calendar} <- @systems}>
        <label class="label" id={"#{calendar}-label"}>{calendar} ({locale})</label>
        <.date_picker name={calendar} id={"#{calendar}-picker"} label_id={"#{calendar}-label"} value={Date.utc_today()} locale={locale} calendar={calendar} />
      </div>
    </div>
    """
  end
end

defmodule KoyomiDev.FiltersLive do
  @moduledoc """
  A filter bar with plain params, as in a dashboard or a search page: a
  relative day and a relative range, with keys of its own, kept in the URL.
  """
  use Phoenix.LiveView

  import Koyomi.Components

  alias Plug.Conn.Query

  @presets [
    :today,
    :yesterday,
    {:last, 7, :days},
    {:last, 30, :days},
    :this_month,
    :last_month,
    :this_quarter,
    :this_year
  ]

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, presets: @presets)}

  @impl true
  def handle_params(params, _uri, socket) do
    filter = Map.get(params, "filter", %{"day" => "today", "period" => "last_7_days"})
    {:noreply, assign(socket, filter: filter, ranges: ranges(filter))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Filters</h1>
    <form id="filters-form" phx-change="filter">
      <div class="columns">
        <div>
          <label class="label" id="day-label">Day</label>
          <.date_picker name="filter[day]" value={@filter["day"]} label_id="day-label" relative presets={@presets} />

          <label class="label" id="period-label">Period</label>
          <.date_range_picker
            name="filter[period]"
            value={@filter["period"]}
            label_id="period-label"
            keys={{"start", "end"}}
            relative
            months={2}
            presets={@presets}
          />
        </div>
        <dl>
          <dt>Today's days</dt>
          <dd id="ranges">{@ranges}</dd>
        </dl>
      </div>
    </form>
    <pre id="posted" data-json={JSON.encode!(@filter)}>{inspect(@filter)}</pre>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    # LiveView marks the fields not yet touched (_unused_...): not filters.
    filter = Map.reject(filter, fn {key, _value} -> String.starts_with?(key, "_unused_") end)
    {:noreply, push_patch(socket, to: "/filters?" <> Query.encode(%{"filter" => filter}))}
  end

  # What a query would run with: a key resolved to today's days.
  defp ranges(filter) do
    day =
      case Koyomi.Presets.to_date(filter["day"] || "") do
        {:ok, date} -> Date.to_iso8601(date)
        :error -> filter["day"]
      end

    period =
      case filter["period"] do
        key when is_binary(key) ->
          case Koyomi.Presets.to_range(key) do
            {:ok, range} -> "#{range.first}/#{range.last}"
            :error -> key
          end

        %{"start" => first, "end" => last} ->
          "#{first}/#{last}"

        _none ->
          ""
      end

    "#{day} · #{period}"
  end
end

defmodule KoyomiDev.PlainController do
  @moduledoc "A page without LiveView: the pickers mount with mountKoyomi()."
  use Phoenix.Controller, formats: [:html]

  import Phoenix.Component, only: [sigil_H: 2]
  import Koyomi.Components

  alias Phoenix.HTML.Safe

  def index(conn, params) do
    assigns = %{params: params}

    inner = ~H"""
    <h1>Without LiveView</h1>
    <form method="get" action="/plain" id="plain-form">
      <label class="label" id="plain-due-label">Due</label>
      <.date_picker name="due" value={@params["due"]} label_id="plain-due-label" locale="en-GB" />
      <label class="label" id="plain-stay-label">Stay</label>
      <.date_range_picker name="stay" value={@params["stay"]} label_id="plain-stay-label" locale="en-GB" />
      <div class="row"><button type="submit">Send</button></div>
    </form>
    <pre id="posted" data-json={JSON.encode!(Map.take(@params, ["due", "stay"]))}>{inspect(Map.take(@params, ["due", "stay"]))}</pre>
    """

    page = KoyomiDev.Layouts.root(%{__changed__: nil, conn: conn, inner_content: inner})
    html(conn, page |> Safe.to_iodata() |> IO.iodata_to_binary())
  end
end

defmodule KoyomiDev.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_root_layout, html: {KoyomiDev.Layouts, :root})
  end

  scope "/" do
    pipe_through(:browser)

    live("/", KoyomiDev.PickersLive)
    live("/days", KoyomiDev.DaysLive)
    live("/calendars", KoyomiDev.CalendarsLive)
    live("/filters", KoyomiDev.FiltersLive)
    get("/plain", KoyomiDev.PlainController, :index)
  end
end

defmodule KoyomiDev.ErrorHTML do
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule KoyomiDev.Endpoint do
  use Phoenix.Endpoint, otp_app: :koyomi

  @session [store: :cookie, key: "_koyomi_dev", signing_salt: "koyomi-dev"]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]])

  if System.get_env("KOYOMI_DEV_WATCH") != "false" do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Static, at: "/assets", from: Path.expand("priv/static", __DIR__))
  plug(Plug.Static, at: "/vendor/phoenix", from: {:phoenix, "priv/static"})
  plug(Plug.Static, at: "/vendor/phoenix_live_view", from: {:phoenix_live_view, "priv/static"})

  plug(Plug.Parsers, parsers: [:urlencoded, :json], pass: ["*/*"], json_decoder: JSON)
  plug(Plug.Session, @session)
  plug(KoyomiDev.Router)
end

# The script's process ends after this file, so the server runs in a task
# that stays alive; `mix run --no-halt` keeps the VM up.
Task.async(fn ->
  if watch?, do: {:ok, _apps} = Application.ensure_all_started(:esbuild)

  {:ok, _pid} =
    Supervisor.start_link(
      [{Phoenix.PubSub, name: KoyomiDev.PubSub}, KoyomiDev.Endpoint],
      strategy: :one_for_one
    )

  IO.puts("Koyomi development server: http://localhost:#{port}")
  Process.sleep(:infinity)
end)
