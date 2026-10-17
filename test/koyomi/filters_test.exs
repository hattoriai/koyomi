defmodule Koyomi.FiltersTest do
  @moduledoc "Pickers outside Ecto forms: range keys, and relative values."
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Koyomi.Test

  alias Koyomi.{Components, DateRange, Presets}

  @endpoint KoyomiTest.Endpoint

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
      Map.new(~w(name value data-part disabled), fn attr ->
        {attr, input |> LazyHTML.attribute(attr) |> List.first()}
      end)
    end)
  end

  describe "the keys of a range" do
    test "name the posted days, and read the value as the params have it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Components.date_range_picker
          name="filter[period]"
          value={%{"start" => "2027-03-01", "end" => "2027-03-07"}}
          keys={{"start", "end"}}
        />
        """)

      {node, _config, value} = picker(html, "filter_period__picker")
      assert value == %{"from" => "2027-03-01", "to" => "2027-03-07"}

      assert [
               %{"name" => "filter[period][start]", "value" => "2027-03-01"},
               %{"name" => "filter[period][end]", "value" => "2027-03-07"}
             ] = inputs(node)
    end

    test "take atoms, and refuse anything but two keys" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Components.date_range_picker name="period" value={%{lower: ~D[2027-03-01], upper: ~D[2027-03-02]}} keys={{:lower, :upper}} />
        """)

      {node, _config, value} = picker(html, "period_picker")
      assert value == %{"from" => "2027-03-01", "to" => "2027-03-02"}
      assert ["period[lower]", "period[upper]"] = node |> inputs() |> Enum.map(& &1["name"])

      assert_raise ArgumentError, ~r/keys/, fn ->
        rendered_to_string(~H"""
        <Components.date_range_picker name="period" keys={["start", "end"]} />
        """)
      end
    end
  end

  describe "a relative picker" do
    test "shows a preset's key as that preset, and posts the key alone" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Components.date_range_picker
          name="filter[period]"
          value="last_7_days"
          keys={{"start", "end"}}
          relative
          presets={[:today, {:last, 7, :days}]}
        />
        """)

      {node, config, value} = picker(html, "filter_period__picker")
      assert value == "last_7_days"
      assert config["relative"] == true
      assert ["today", "last_7_days"] = Enum.map(config["presets"], & &1["key"])

      assert [
               %{"name" => "filter[period][start]", "disabled" => ""},
               %{"name" => "filter[period][end]", "disabled" => ""},
               %{
                 "name" => "filter[period]",
                 "value" => "last_7_days",
                 "data-part" => "preset",
                 "disabled" => nil
               }
             ] = inputs(node)
    end

    test "posts days, with the preset input disabled, for a value that is no preset's key" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Components.date_picker name="due" value="2027-03-15" relative presets={[:today, :tomorrow]} />
        """)

      {node, _config, value} = picker(html, "due_picker")
      assert value == "2027-03-15"

      assert [
               %{
                 "name" => "due",
                 "value" => "2027-03-15",
                 "data-part" => "value",
                 "disabled" => nil
               },
               %{"name" => "due", "data-part" => "preset", "disabled" => ""}
             ] = inputs(node)
    end

    test "names its own presets with a keyword list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <Components.date_range_picker
          name="period"
          value={:recent}
          relative
          presets={[recent: {:last, 7, :days}, quarter: :this_quarter]}
        />
        """)

      {_node, config, value} = picker(html, "period_picker")
      assert value == "recent"
      assert ["recent", "quarter"] = Enum.map(config["presets"], & &1["key"])
    end

    test "needs a name to post a key under" do
      assigns = %{}

      assert_raise ArgumentError, ~r/field` or a `name/, fn ->
        rendered_to_string(~H"""
        <Components.date_picker id="due" relative presets={[:today]} />
        """)
      end
    end
  end

  describe "Koyomi.Test.pick/3 in a filter form" do
    setup do
      {:ok, view, _html} = live(build_conn(), "/filters")
      %{view: view}
    end

    defp filter(html),
      do: html |> LazyHTML.from_fragment() |> LazyHTML.query("#filter") |> LazyHTML.text()

    test "picks a preset by its key, and days with the range's keys", %{view: view} do
      html = pick(view, "filter_period__picker", :this_month)
      assert filter(html) =~ ~s("period" => "this_month")
      assert filter(html) =~ ~s("day" => "today")

      html = pick(view, "filter_period__picker", Date.range(~D[2027-03-01], ~D[2027-03-07]))
      assert filter(html) =~ ~s("period" => %{"end" => "2027-03-07", "start" => "2027-03-01"})

      html = pick(view, "filter_day__picker", "yesterday")
      assert filter(html) =~ ~s("day" => "yesterday")

      html = pick(view, "filter_day__picker", ~D[2027-03-15])
      assert filter(html) =~ ~s("day" => "2027-03-15")
    end
  end

  describe "on the server" do
    test "a key gives the days it covers on a day" do
      today = ~D[2027-03-17]

      assert {:ok, ~D[2027-03-16]} = Presets.to_date("yesterday", today: today)
      assert {:ok, ~D[2027-03-24]} = Presets.to_date("in_1_week", today: today)

      assert {:ok, range} = Presets.to_range("this_quarter", today: today)
      assert range == Date.range(~D[2027-01-01], ~D[2027-03-31])

      assert {:ok, range} = Presets.to_range("today", today: today)
      assert range == Date.range(today, today)

      assert :error = Presets.to_range("whenever", today: today)
      assert :error = Presets.to_date("last_0_days", today: today)
    end

    test "every built-in key goes back to its preset" do
      presets =
        [:today, :tomorrow, :yesterday, :month_to_date, :year_to_date] ++
          [:this_week, :next_week, :last_week, :this_month, :next_month, :last_month] ++
          [:this_quarter, :last_quarter, :this_year, :last_year] ++
          [{:in, 3, :day}, {:ago, 2, :week}, {:in, 1, :month}, {:ago, 1, :year}] ++
          [{:last, 30, :days}, {:next, 14, :days}]

      for preset <- presets do
        assert {:ok, ^preset} = Presets.parse(Presets.key(preset))
      end

      assert {:ok, {:in, 2, :weeks}} = Presets.parse("in-2-weeks")
      assert Presets.key({"Payday", ~D[2027-03-25]}) == nil
    end

    test "Koyomi.DateRange casts start and end, and a built-in key" do
      assert {:ok, range} = DateRange.cast(%{"start" => "2027-03-01", "end" => "2027-03-07"})
      assert range == Date.range(~D[2027-03-01], ~D[2027-03-07])

      assert {:ok, range} = DateRange.cast("last_7_days")
      today = Date.utc_today()
      assert range == Date.range(Date.add(today, -6), today)

      assert :error = DateRange.cast("someday")
    end
  end
end
