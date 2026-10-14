defmodule Koyomi.RecurrenceTest do
  use ExUnit.Case, async: true

  alias Koyomi.Recurrence

  doctest Koyomi.Recurrence

  @fixture "test/fixtures/recurrence.json" |> File.read!() |> JSON.decode!()
  @languages ~w(en pt es fr de it nl ja)

  # The fixture's rule (as rrule.ts has it) as a struct.
  defp rule_from_json(json) do
    %Recurrence{
      freq: String.to_existing_atom(json["freq"]),
      interval: json["interval"],
      count: json["count"],
      until: until_from_json(json["until"]),
      by_day: Enum.map(json["byDay"], &{&1["ordinal"], &1["weekday"]}),
      by_month_day: json["byMonthDay"],
      by_month: json["byMonth"],
      by_set_pos: json["bySetPos"],
      week_start: json["weekStart"]
    }
  end

  defp until_from_json(nil), do: nil

  defp until_from_json(text) do
    case DateTime.from_iso8601(text) do
      {:ok, datetime, 0} -> datetime
      {:error, _reason} -> Date.from_iso8601!(text)
    end
  end

  describe "the shared fixture" do
    for {test_case, index} <- Enum.with_index(@fixture["valid"]) do
      @test_case test_case
      test "#{index}: #{test_case["input"]}" do
        c = @test_case
        rule = Recurrence.parse!(c["input"])

        assert rule == rule_from_json(c["rule"])
        assert to_string(rule) == c["canonical"]
        assert Recurrence.parse!(c["canonical"]) == rule

        start = Date.from_iso8601!(c["start"])
        occurrences = rule |> Recurrence.occurrences(start) |> Enum.take(c["limit"])
        assert Enum.map(occurrences, &Date.to_iso8601/1) == c["occurrences"]

        for lang <- @languages do
          assert Recurrence.describe(rule, lang) == c["describe"][lang]
        end

        if from_start = c["describeFromStart"] do
          for lang <- @languages do
            assert Recurrence.describe(rule, lang, start: start) == from_start[lang]
          end
        end
      end
    end

    for {test_case, index} <- Enum.with_index(@fixture["invalid"]) do
      @test_case test_case
      test "invalid #{index}: #{inspect(test_case["input"])}" do
        assert Recurrence.parse(@test_case["input"]) == {:error, @test_case["error"]}
      end
    end
  end

  describe "parse/1" do
    test "raises with parse!/1" do
      assert_raise ArgumentError, "invalid recurrence rule: FREQ is missing", fn ->
        Recurrence.parse!("COUNT=2")
      end
    end

    test "reads both kinds of UNTIL" do
      assert Recurrence.parse!("FREQ=DAILY;UNTIL=20271231").until == ~D[2027-12-31]

      assert Recurrence.parse!("FREQ=DAILY;UNTIL=20271231T235959Z").until ==
               ~U[2027-12-31 23:59:59Z]
    end
  end

  describe "new/1" do
    test "builds the same rule as parse/1" do
      assert Recurrence.new(
               freq: :monthly,
               by_day: [{-1, 5}, {1, 1}],
               by_month: [12, 6],
               until: ~D[2027-12-31]
             ) == Recurrence.parse("FREQ=MONTHLY;BYMONTH=6,12;BYDAY=1MO,-1FR;UNTIL=20271231")
    end

    test "shifts UNTIL to UTC" do
      until = DateTime.from_naive!(~N[2027-12-31 23:59:59], "Etc/UTC")

      {:ok, rule} =
        Recurrence.new(
          freq: :daily,
          until: %{until | utc_offset: 3600, zone_abbr: "X", time_zone: "X"}
        )

      assert rule.until == ~U[2027-12-31 22:59:59Z]
    end

    test "refuses what parse/1 refuses" do
      assert Recurrence.new(interval: 2) == {:error, "FREQ is missing"}
      assert Recurrence.new(freq: :hourly) == {:error, "FREQ=HOURLY is not supported"}

      assert Recurrence.new(freq: :daily, interval: 0) ==
               {:error, "INTERVAL must be a positive whole number"}

      assert Recurrence.new(freq: :daily, count: 2, until: ~D[2027-01-01]) ==
               {:error, "COUNT and UNTIL cannot both be set"}

      assert Recurrence.new(freq: :weekly, by_day: [{1, 1}]) ==
               {:error, "BYDAY ordinals such as 1MO need FREQ=MONTHLY or FREQ=YEARLY"}

      assert Recurrence.new(freq: :monthly, by_day: [8]) ==
               {:error, "BYDAY has an invalid day: 8"}

      assert Recurrence.new(freq: :daily, week_start: 0) == {:error, "WKST has an invalid day: 0"}
      assert Recurrence.new(freq: :daily, until: "2027") |> elem(0) == :error
      assert Recurrence.new(freq: :daily, hour: 9) == {:error, ":hour is not a rule option"}
    end
  end

  describe "occurrences/3" do
    test "keeps the time of a NaiveDateTime start" do
      rule = Recurrence.parse!("FREQ=WEEKLY;BYDAY=MO,TH;COUNT=3")

      assert rule |> Recurrence.occurrences(~N[2027-03-15 09:30:00]) |> Enum.to_list() == [
               ~N[2027-03-15 09:30:00],
               ~N[2027-03-18 09:30:00],
               ~N[2027-03-22 09:30:00]
             ]
    end

    test "compares a UTC UNTIL with the time" do
      rule = Recurrence.parse!("FREQ=DAILY;UNTIL=20270317T090000Z")
      assert rule |> Recurrence.occurrences(~N[2027-03-15 09:00:00]) |> Enum.count() == 3
      assert rule |> Recurrence.occurrences(~N[2027-03-15 09:00:01]) |> Enum.count() == 2
      assert rule |> Recurrence.occurrences(~U[2027-03-15 09:00:00Z]) |> Enum.count() == 3
    end

    test "a date UNTIL takes the whole day" do
      rule = Recurrence.parse!("FREQ=DAILY;UNTIL=20270317")
      assert rule |> Recurrence.occurrences(~N[2027-03-15 23:00:00]) |> Enum.count() == 3
    end

    test "keeps the wall clock time across a change of offset" do
      rule = Recurrence.parse!("FREQ=WEEKLY;COUNT=3")
      start = DateTime.new!(~D[2027-03-21], ~T[09:00:00], "Europe/Lisbon", Tz.TimeZoneDatabase)

      [first, second, third] =
        rule
        |> Recurrence.occurrences(start, time_zone_database: Tz.TimeZoneDatabase)
        |> Enum.to_list()

      assert first.utc_offset + first.std_offset == 0
      assert DateTime.to_time(second) == ~T[09:00:00]
      assert second.utc_offset + second.std_offset == 3600
      assert DateTime.to_date(third) == ~D[2027-04-04]
    end

    test "moves a time that the clocks skip forward by the gap" do
      rule = Recurrence.parse!("FREQ=DAILY;COUNT=3")
      start = DateTime.new!(~D[2027-03-27], ~T[01:30:00], "Europe/Lisbon", Tz.TimeZoneDatabase)

      [_, gap, after_gap] =
        rule
        |> Recurrence.occurrences(start, time_zone_database: Tz.TimeZoneDatabase)
        |> Enum.to_list()

      assert DateTime.to_naive(gap) == ~N[2027-03-28 02:30:00]
      assert DateTime.to_naive(after_gap) == ~N[2027-03-29 01:30:00]
    end

    test "a time that happens twice takes the earlier instant" do
      rule = Recurrence.parse!("FREQ=DAILY;COUNT=2")
      start = DateTime.new!(~D[2027-10-30], ~T[01:30:00], "Europe/Lisbon", Tz.TimeZoneDatabase)

      [_, twice] =
        rule
        |> Recurrence.occurrences(start, time_zone_database: Tz.TimeZoneDatabase)
        |> Enum.to_list()

      assert twice.utc_offset + twice.std_offset == 3600
    end

    test "is lazy for a rule without an end" do
      rule = Recurrence.parse!("FREQ=DAILY")
      assert rule |> Recurrence.occurrences(~D[2027-01-01]) |> Enum.at(365) == ~D[2028-01-01]
    end

    test "ends a rule that never produces" do
      rule = Recurrence.parse!("FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30")
      assert rule |> Recurrence.occurrences(~D[2027-01-01]) |> Enum.to_list() == [~D[2027-01-01]]
    end

    test "ends at the year 9999" do
      rule = Recurrence.parse!("FREQ=YEARLY;INTERVAL=1000")

      assert rule |> Recurrence.occurrences(~D[2027-01-01]) |> Enum.to_list() |> List.last() ==
               ~D[9027-01-01]
    end
  end

  describe "between/5" do
    test "lists the occurrences of a span" do
      rule = Recurrence.parse!("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1")

      assert Recurrence.between(rule, ~D[2027-01-29], ~D[2027-03-01], ~D[2027-05-31]) ==
               [~D[2027-03-31], ~D[2027-04-30], ~D[2027-05-31]]
    end

    test "compares the day of a NaiveDateTime" do
      rule = Recurrence.parse!("FREQ=DAILY")

      assert Recurrence.between(rule, ~N[2027-01-01 18:00:00], ~D[2027-01-03], ~D[2027-01-04]) ==
               [~N[2027-01-03 18:00:00], ~N[2027-01-04 18:00:00]]
    end
  end

  describe "describe/3" do
    test "a region variant takes its language, an unknown one English" do
      rule = Recurrence.parse!("FREQ=MONTHLY;BYDAY=-1FR")
      assert Recurrence.describe(rule, "pt-BR") == Recurrence.describe(rule, "pt")
      assert Recurrence.describe(rule, "en_GB") == "Monthly on the last Friday"
      assert Recurrence.describe(rule, "ko") == "Monthly on the last Friday"
    end
  end

  describe "Ecto.Type" do
    test "casts a string, a struct, nil and the empty string" do
      rule = Recurrence.parse!("FREQ=DAILY")
      assert Recurrence.cast("freq=daily") == {:ok, rule}
      assert Recurrence.cast(rule) == {:ok, rule}
      assert Recurrence.cast("") == {:ok, nil}
      assert Recurrence.cast(nil) == {:ok, nil}
      assert Recurrence.cast("FREQ=HOURLY") == {:error, message: "FREQ=HOURLY is not supported"}
      assert Recurrence.cast(42) == :error
    end

    test "dumps and loads the rule text" do
      rule = Recurrence.parse!("RRULE:BYDAY=FR;FREQ=WEEKLY")
      assert Recurrence.dump(rule) == {:ok, "FREQ=WEEKLY;BYDAY=FR"}
      assert Recurrence.load("FREQ=WEEKLY;BYDAY=FR") == {:ok, rule}
      assert Recurrence.load("FREQ=NEVER") == :error
    end

    test "gives a changeset the parse error" do
      types = %{repeat: Recurrence}

      changeset =
        Ecto.Changeset.cast({%{}, types}, %{"repeat" => "FREQ=DAILY;BYHOUR=9"}, [:repeat])

      assert changeset.errors[:repeat] ==
               {"BYHOUR is not supported", [type: Recurrence, validation: :cast]}
    end
  end
end
