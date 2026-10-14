defmodule Koyomi.ChangesetTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias KoyomiTest.Booking

  doctest Koyomi.Changeset

  defp errors(changeset),
    do:
      Map.new(changeset.errors, fn {field, {message, keys}} -> {field, {message, keys[:kind]}} end)

  test "a date that the rules refuse" do
    changeset = Booking.changeset(%{"due" => "2027-03-14"})
    assert errors(changeset) == %{due: {"is not available", :disabled}}
    assert Booking.changeset(%{"due" => "2027-03-15"}).valid?
  end

  test "a range, as one field" do
    assert errors(Booking.changeset(%{"stay" => %{"from" => "2027-03-01", "to" => "2027-03-01"}})) ==
             %{stay: {"must be at least %{count} days", :too_short}}

    assert errors(Booking.changeset(%{"stay" => %{"from" => "2027-03-01", "to" => "2027-03-09"}})) ==
             %{stay: {"must be at most %{count} days", :too_long}}

    assert Booking.changeset(%{"stay" => %{"from" => "2027-03-01", "to" => "2027-03-03"}}).valid?
  end

  test "a range, as two fields: the error goes on the end that breaks the rule" do
    types = %{from: :date, to: :date}
    cast = fn params -> cast({%{}, types}, params, [:from, :to]) end
    rules = [min: ~D[2027-03-01], max_days: 3]

    changeset =
      cast.(%{"from" => "2027-02-27", "to" => "2027-03-01"})
      |> Koyomi.Changeset.validate_range({:from, :to}, rules)

    assert Keyword.has_key?(changeset.errors, :from)

    changeset =
      cast.(%{"from" => "2027-03-01", "to" => "2027-03-09"})
      |> Koyomi.Changeset.validate_range({:from, :to}, rules)

    assert Keyword.has_key?(changeset.errors, :to)
  end

  test "several days" do
    assert errors(
             Booking.changeset(%{
               "days" => ["", "2027-03-01", "2027-03-02", "2027-03-03", "2027-03-04"]
             })
           ) ==
             %{days: {"must have at most %{count} days", :too_many}}
  end

  test "a time" do
    assert errors(Booking.changeset(%{"at" => "09:10:00"})) == %{
             at: {"must be in steps of %{count} minutes", :time_step}
           }

    assert errors(Booking.changeset(%{"at" => "18:00:00"})) == %{
             at: {"must be at or before %{max_time}", :time_after_max}
           }

    assert Booking.changeset(%{"at" => "09:15"}).valid?
  end

  describe "cast_datetime/5" do
    test "a time with an offset" do
      assert Booking.changeset(%{"starts_at" => "2027-03-15T14:30:00+00:00"}).changes.starts_at ==
               ~U[2027-03-15 14:30:00Z]
    end

    test "a wall clock time, read in the zone" do
      assert Booking.changeset(%{"starts_at" => "2027-07-15T14:30"}).changes.starts_at ==
               ~U[2027-07-15 13:30:00Z]
    end

    test "a time that the clocks skip" do
      changeset = Booking.changeset(%{"starts_at" => "2027-03-28T01:30"})

      assert errors(changeset) == %{
               starts_at: {"does not exist in %{time_zone} (the clocks change)", :gap}
             }
    end

    test "a time that happens twice takes the first, or the second" do
      # Lisbon falls back from 02:00 to 01:00 on 31 October 2027.
      assert Booking.changeset(%{"starts_at" => "2027-10-31T01:30"}).changes.starts_at ==
               ~U[2027-10-31 00:30:00Z]

      changeset =
        {%{}, %{at: :utc_datetime}}
        |> cast(%{}, [])
        |> Koyomi.Changeset.cast_datetime(%{"at" => "2027-10-31T01:30"}, :at, "Europe/Lisbon",
          ambiguous: :later
        )

      assert changeset.changes.at == ~U[2027-10-31 01:30:00Z]

      changeset =
        {%{}, %{at: :utc_datetime}}
        |> cast(%{}, [])
        |> Koyomi.Changeset.cast_datetime(%{"at" => "2027-10-31T01:30"}, :at, "Europe/Lisbon",
          ambiguous: :error
        )

      assert errors(changeset) == %{
               at: {"happens twice in %{time_zone} (the clocks change)", :ambiguous}
             }
    end

    test "a naive field keeps the zone's wall clock" do
      changeset =
        {%{}, %{at: :naive_datetime}}
        |> cast(%{}, [])
        |> Koyomi.Changeset.cast_datetime(%{"at" => "2027-07-15T13:30:00Z"}, :at, "Europe/Lisbon")

      assert changeset.changes.at == ~N[2027-07-15 14:30:00]

      changeset =
        {%{}, %{at: :naive_datetime}}
        |> cast(%{}, [])
        |> Koyomi.Changeset.cast_datetime(
          %{"at" => ~U[2027-07-15 13:30:00Z]},
          :at,
          "Europe/Lisbon"
        )

      assert changeset.changes.at == ~N[2027-07-15 14:30:00]
    end

    test "empty and invalid" do
      assert Booking.changeset(%{"starts_at" => ""}).changes == %{}

      assert errors(Booking.changeset(%{"starts_at" => "soon"})) == %{
               starts_at: {"is invalid", nil}
             }
    end
  end

  test "a message of the app's, by kind" do
    changeset =
      {%{}, %{due: :date}}
      |> cast(%{"due" => "2027-03-14"}, [:due])
      |> Koyomi.Changeset.validate_date(:due, [disabled_weekdays: [7]],
        message: %{disabled: "we rest on Sundays"}
      )

    assert [due: {"we rest on Sundays", _}] = changeset.errors
  end

  test "a field with a cast error is left alone" do
    changeset = Booking.changeset(%{"due" => "nope"})
    assert [due: {"is invalid", _}] = changeset.errors
  end
end
