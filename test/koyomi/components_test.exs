defmodule Koyomi.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Koyomi.Components

  defp make_form(params, types) do
    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> to_form(as: :event)
  end

  defp picker(html, id) do
    node = html |> LazyHTML.from_fragment() |> LazyHTML.query_by_id(id)
    [config] = LazyHTML.attribute(node, "data-config")
    [value] = LazyHTML.attribute(node, "data-value")
    {node, JSON.decode!(config), JSON.decode!(value)}
  end

  defp inputs(node) do
    node
    |> LazyHTML.query("input")
    |> Enum.map(fn input ->
      Map.new(~w(type name value data-part min max), fn attr ->
        {attr, input |> LazyHTML.attribute(attr) |> List.first()}
      end)
    end)
  end

  test "a date picker: the hook, the config, the value and the browser's own input" do
    assigns = %{form: make_form(%{"due" => "2027-03-15"}, %{due: :date})}

    html =
      rendered_to_string(~H"""
      <Components.date_picker field={@form[:due]} label_id="due-label" min={~D[2027-03-01]} locale="pt-PT" presets={[:today]} />
      """)

    {node, config, value} = picker(html, "event_due_picker")
    assert LazyHTML.attribute(node, "phx-hook") == ["Koyomi"]
    assert LazyHTML.attribute(node, "phx-update") == ["ignore"]
    assert value == "2027-03-15"
    assert config["kind"] == "date"
    assert config["locale"] == "pt-PT"
    assert config["labelId"] == "due-label"
    assert config["rules"] == %{"min" => "2027-03-01"}
    assert config["messages"]["today"] == "Hoje"
    assert [%{"id" => "today"}] = config["presets"]
    refute Map.has_key?(config, "inline")

    assert [
             %{
               "type" => "date",
               "name" => "event[due]",
               "value" => "2027-03-15",
               "data-part" => "value",
               "min" => "2027-03-01"
             }
           ] =
             inputs(node)
  end

  test "a range picker posts from and to, as one field or two" do
    assigns = %{form: make_form(%{"stay" => "2027-03-01/2027-03-07"}, %{stay: Koyomi.DateRange})}

    html =
      rendered_to_string(~H"<Components.date_range_picker field={@form[:stay]} months={2} />")

    {node, config, value} = picker(html, "event_stay_picker")
    assert value == %{"from" => "2027-03-01", "to" => "2027-03-07"}
    assert config["months"] == 2

    assert Enum.map(inputs(node), &{&1["name"], &1["value"]}) == [
             {"event[stay][from]", "2027-03-01"},
             {"event[stay][to]", "2027-03-07"}
           ]

    assigns = %{
      form: make_form(%{"check_in" => "2027-03-01"}, %{check_in: :date, check_out: :date})
    }

    html =
      rendered_to_string(
        ~H"<Components.date_range_picker from={@form[:check_in]} to={@form[:check_out]} />"
      )

    {node, _config, value} = picker(html, "event_check_in_range_picker")
    assert value == %{"from" => "2027-03-01", "to" => nil}
    assert Enum.map(inputs(node), & &1["name"]) == ["event[check_in]", "event[check_out]"]
  end

  test "a dates picker posts a list with an empty first entry" do
    assigns = %{form: make_form(%{"days" => ["2027-03-05", "2027-03-01"]}, %{days: Koyomi.Dates})}
    html = rendered_to_string(~H"<Components.dates_picker field={@form[:days]} />")
    {node, _config, value} = picker(html, "event_days_picker")
    assert value == ["2027-03-01", "2027-03-05"]

    assert Enum.map(inputs(node), &{&1["data-part"], &1["value"]}) == [
             {"sentinel", ""},
             {"date", "2027-03-01"},
             {"date", "2027-03-05"},
             {"date", ""}
           ]
  end

  test "month, week, year and time pickers use the browser's forms of the value" do
    assigns = %{
      form:
        make_form(
          %{"month" => "2027-03", "week" => "2027-W11", "year" => "2027", "at" => "14:30:00"},
          %{
            month: Koyomi.Month,
            week: Koyomi.Week,
            year: :integer,
            at: :time
          }
        )
    }

    html =
      rendered_to_string(~H"""
      <Components.month_picker field={@form[:month]} />
      <Components.week_picker field={@form[:week]} />
      <Components.year_picker field={@form[:year]} />
      <Components.time_picker field={@form[:at]} rules={[step: 15]} />
      """)

    assert {_, %{"kind" => "month"}, "2027-03"} = picker(html, "event_month_picker")

    assert {_, %{"kind" => "week", "weekNumbers" => true}, "2027-W11"} =
             picker(html, "event_week_picker")

    assert {_, %{"kind" => "year"}, "2027"} = picker(html, "event_year_picker")
    {node, config, "14:30:00"} = picker(html, "event_at_picker")
    assert config["rules"] == %{"step" => 15}
    assert [%{"type" => "time"}] = inputs(node)
    assert node |> LazyHTML.query("input") |> LazyHTML.attribute("step") == ["900"]
  end

  test "a date and time picker shows the zone's wall clock in the browser's own input" do
    assigns = %{form: make_form(%{"at" => "2027-07-15T13:30:00Z"}, %{at: :utc_datetime})}

    html =
      rendered_to_string(
        ~H|<Components.datetime_picker field={@form[:at]} time_zone="Europe/Lisbon" />|
      )

    {node, config, value} = picker(html, "event_at_picker")
    assert value == "2027-07-15T13:30:00Z"
    assert config["timeZone"] == "Europe/Lisbon"
    assert [%{"type" => "datetime-local", "value" => "2027-07-15T14:30:00"}] = inputs(node)
  end

  test "holidays and errors reach the config" do
    changeset =
      {%{}, %{due: :date}}
      |> Ecto.Changeset.cast(%{"due" => "2027-12-25"}, [:due])
      |> Ecto.Changeset.add_error(:due, "is taken")
      |> Map.put(:action, :validate)

    assigns = %{form: to_form(changeset, as: :event)}

    html =
      rendered_to_string(
        ~H|<Components.date_picker field={@form[:due]} holidays="PT" locale="pt" aria-describedby="due-help" />|
      )

    {node, config, _value} = picker(html, "event_due_picker")
    assert config["holidays"]["2027-12-25"] == "Natal"
    assert config["invalid"] == true
    assert config["describedBy"] == "due-help"
    assert LazyHTML.attribute(node, "aria-describedby") == []
  end

  test "a calendar without a field, and a picker without an id" do
    assigns = %{}

    html =
      rendered_to_string(
        ~H|<Components.calendar id="cal" select="range" value={Date.range(~D[2027-03-01], ~D[2027-03-03])} on_change="picked" />|
      )

    {node, config, value} = picker(html, "cal")
    assert config["kind"] == "calendar"
    assert config["inline"] == true
    assert config["onChange"] == "picked"
    assert value == %{"from" => "2027-03-01", "to" => "2027-03-03"}
    assert inputs(node) == []

    assert_raise ArgumentError, ~r/needs an `id`/, fn ->
      rendered_to_string(~H"<Components.date_picker />")
    end
  end

  test "a recurrence picker" do
    assigns = %{}

    html =
      rendered_to_string(
        ~H|<Components.recurrence_picker name="rule" value="FREQ=WEEKLY;BYDAY=MO" start={~D[2027-03-15]} />|
      )

    {node, config, value} = picker(html, "rule_picker")
    assert value == "FREQ=WEEKLY;BYDAY=MO"
    assert config["start"] == "2027-03-15"
    assert [%{"type" => "text", "name" => "rule"}] = inputs(node)

    # After a phx-change, a field's value is the posted string.
    html =
      rendered_to_string(
        ~H|<Components.recurrence_picker name="rule" start="2027-03-15T09:00" />|
      )

    assert {_node, %{"start" => "2027-03-15"}, nil} = picker(html, "rule_picker")
  end
end
