defmodule KoyomiTest.BookingLive do
  @moduledoc "A LiveView with a picker of each kind, for the tests."
  use Phoenix.LiveView

  import Koyomi.Components

  alias KoyomiTest.Booking

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, form: to_form(Booking.changeset(%{}), as: :booking), changes: %{}, last: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.form for={@form} id="booking-form" phx-change="validate">
      <label id="due-label">Due</label>
      <.date_picker field={@form[:due]} label_id="due-label" rules={Booking.due_rules()} holidays="PT" />
      <.date_range_picker field={@form[:stay]} rules={Booking.stay_rules()} days nights />
      <.dates_picker field={@form[:days]} rules={[max_count: 3]} />
      <.month_picker field={@form[:month]} />
      <.week_picker field={@form[:week]} />
      <.year_picker field={@form[:year]} />
      <.time_picker field={@form[:at]} rules={Booking.time_rules()} />
      <.datetime_picker field={@form[:starts_at]} time_zone="Europe/Lisbon" slots />
      <.recurrence_picker field={@form[:repeat]} start={~D[2027-03-15]} />
    </.form>
    <p id="changes">{inspect(@changes)}</p>
    <p id="errors">{inspect(errors(@form))}</p>
    <p id="last">{inspect(@last)}</p>
    """
  end

  defp errors(form),
    do: Enum.map(form.source.errors, fn {field, {message, _}} -> {field, message} end)

  @impl true
  def handle_event("validate", %{"booking" => params}, socket) do
    changeset = Booking.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, form: to_form(changeset, as: :booking), changes: changeset.changes)}
  end

  def handle_event("koyomi:days", params, socket) do
    Koyomi.Live.handle_days(socket, params, &days/2)
  end

  def handle_event("push", %{"value" => value}, socket) do
    {:noreply, Koyomi.Live.push_value(socket, "booking_due_picker", Date.from_iso8601!(value))}
  end

  defp days(range, "booking_stay_picker") do
    for date <- range, Date.day_of_week(date) == 3, into: %{} do
      {date, [label: "Full", disabled: true, tone: :danger]}
    end
  end

  defp days(range, "booking_starts_at_picker") do
    Map.new(range, fn date ->
      {date, [slots: [~T[09:00:00], %{time: ~T[10:00:00], label: "10:00 – 10:30"}]]}
    end)
  end

  defp days(_range, _id), do: raise("no days for this picker")
end
