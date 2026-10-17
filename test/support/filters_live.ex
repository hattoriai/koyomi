defmodule KoyomiTest.FiltersLive do
  @moduledoc "A filter bar with plain params (no changeset), for the tests."
  use Phoenix.LiveView

  import Koyomi.Components

  @presets [:today, :yesterday, {:last, 7, :days}, :this_month, :this_quarter]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, filter: %{"day" => "today", "period" => "last_7_days"})}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :presets, @presets)

    ~H"""
    <form id="filters" phx-change="filter">
      <.date_picker name="filter[day]" value={@filter["day"]} relative presets={@presets} />
      <.date_range_picker
        name="filter[period]"
        value={@filter["period"]}
        keys={{"start", "end"}}
        relative
        presets={@presets}
      />
    </form>
    <p id="filter">{inspect(@filter)}</p>
    """
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end
end
