defmodule Koyomi.RulesTest do
  use ExUnit.Case, async: true

  alias Koyomi.Rules

  doctest Rules

  describe "new/1" do
    test "refuses unknown options and values of the wrong kind" do
      assert_raise ArgumentError, ~r/:mni is not a rule/, fn -> Rules.new(mni: ~D[2027-01-01]) end
      assert_raise ArgumentError, ~r/ISO weekdays/, fn -> Rules.new(disabled_weekdays: [0]) end
      assert_raise ArgumentError, ~r/:min must be/, fn -> Rules.new(min: "2027-01-01") end
      assert_raise ArgumentError, ~r/:min_time/, fn -> Rules.new(min_time: "09:00") end
    end

    test "orders the ends of a disabled range" do
      rules = Rules.new(disabled_ranges: [Date.range(~D[2027-03-10], ~D[2027-03-05], -1)])
      assert rules.disabled_ranges == [{~D[2027-03-05], ~D[2027-03-10]}]
    end
  end

  describe "check_date/2" do
    test "bounds, relative to today" do
      today = Date.utc_today()
      rules = Rules.new(min: :today, max: {:today, 7})
      assert Rules.check_date(rules, today) == :ok
      assert {:error, {:before_min, min: ^today}} = Rules.check_date(rules, Date.add(today, -1))
      assert {:error, {:after_max, _}} = Rules.check_date(rules, Date.add(today, 8))
    end

    test "disabled days, ranges and weekdays" do
      rules =
        Rules.new(
          disabled_dates: [~D[2027-03-17]],
          disabled_ranges: [{~D[2027-03-20], ~D[2027-03-22]}],
          disabled_weekdays: [7]
        )

      assert Rules.check_date(rules, ~D[2027-03-16]) == :ok
      assert {:error, {:disabled, date: ~D[2027-03-17]}} = Rules.check_date(rules, ~D[2027-03-17])
      assert {:error, {:disabled, _}} = Rules.check_date(rules, ~D[2027-03-21])
      assert {:error, {:disabled, _}} = Rules.check_date(rules, ~D[2027-03-14])
    end

    test "today in a time zone" do
      rules = Rules.new(time_zone: "Pacific/Kiritimati")
      assert Date.diff(Rules.today(rules), Date.utc_today()) in [0, 1]
    end
  end

  describe "check_range/2" do
    test "the length counts both ends" do
      rules = Rules.new(min_days: 3)

      assert {:error, {:too_short, min_days: 3}} =
               Rules.check_range(rules, {~D[2027-03-01], ~D[2027-03-02]})

      assert :ok = Rules.check_range(rules, {~D[2027-03-01], ~D[2027-03-03]})
    end

    test "a disabled day inside refuses the range unless allowed" do
      rules = Rules.new(disabled_dates: [~D[2027-03-03]])
      range = {~D[2027-03-01], ~D[2027-03-05]}

      assert {:error, {:disabled_in_range, date: ~D[2027-03-03]}} =
               Rules.check_range(rules, range)

      assert :ok = Rules.check_range(Rules.merge(rules, allow_disabled_in_range: true), range)
    end

    test "a reversed range" do
      assert {:error, {:reversed, []}} = Rules.check_range([], {~D[2027-03-05], ~D[2027-03-01]})
    end
  end

  test "check_dates/2 checks the count and each day" do
    assert {:error, {:too_few, min_count: 2}} =
             Rules.check_dates([min_count: 2], [~D[2027-03-01]])

    assert {:error, {:disabled, _}} =
             Rules.check_dates([disabled_weekdays: [1]], [~D[2027-03-15]])

    assert :ok =
             Rules.check_dates([max_count: 2], [~D[2027-03-01], ~D[2027-03-01], ~D[2027-03-02]])
  end

  test "check_time/2" do
    rules = Rules.new(min_time: ~T[09:00:00], max_time: ~T[17:00:00], step: 30)
    assert :ok = Rules.check_time(rules, ~T[09:30:00])
    assert {:error, {:time_before_min, _}} = Rules.check_time(rules, ~T[08:30:00])
    assert {:error, {:time_after_max, _}} = Rules.check_time(rules, ~T[17:30:00])
    assert {:error, {:time_step, step: 30}} = Rules.check_time(rules, ~T[09:10:00])
  end

  describe "check_datetime/2" do
    test "reads a DateTime in the zone of the rules" do
      rules = Rules.new(disabled_weekdays: [2], time_zone: "Asia/Tokyo", min_time: ~T[09:00:00])
      # Monday 23:30 UTC is Tuesday 08:30 in Tokyo.
      assert {:error, {:disabled, _}} = Rules.check_datetime(rules, ~U[2027-03-15 23:30:00Z])

      assert :ok =
               Rules.check_datetime(
                 Rules.merge(rules, disabled_weekdays: []),
                 ~U[2027-03-16 00:30:00Z]
               )
    end

    test "instant bounds" do
      rules = Rules.new(min: ~U[2027-03-15 12:00:00Z])
      assert {:error, {:before_min, _}} = Rules.check_datetime(rules, ~U[2027-03-15 11:59:00Z])
      assert :ok = Rules.check_datetime(rules, ~U[2027-03-15 12:00:00Z])
      assert {:error, {:before_min, _}} = Rules.check_datetime(rules, ~N[2027-03-15 11:00:00])
    end
  end

  test "to_client/1 resolves today and leaves out empty rules" do
    today = Date.utc_today()

    assert Rules.to_client(min: {:today, 1}, max_days: 7, min_time: ~T[09:00:00.123]) == %{
             "min" => Date.to_iso8601(Date.add(today, 1)),
             "maxDays" => 7,
             "minTime" => "09:00:00"
           }

    assert Rules.to_client(nil) == %{}
  end
end
