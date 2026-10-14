defmodule Koyomi.SQLiteTest do
  # One SQLite file for the module; the tests write rows of their own.
  use ExUnit.Case, async: false

  import Ecto.Changeset

  alias KoyomiTest.{SQLiteRepo, Stored}

  setup_all do
    path = Path.join(System.tmp_dir!(), "koyomi-sqlite-#{System.unique_integer([:positive])}.db")
    {:ok, pid} = SQLiteRepo.start_link(database: path, pool_size: 1)

    SQLiteRepo.query!("""
    CREATE TABLE stored (
      id INTEGER PRIMARY KEY,
      due TEXT, stay TEXT, stay_map TEXT, booking TEXT, booking_map TEXT,
      days TEXT, month TEXT, week TEXT, at TEXT, starts_at TEXT, repeat TEXT,
      window TEXT
    )
    """)

    on_exit(fn ->
      Process.exit(pid, :normal)
      File.rm(path)
    end)

    :ok
  end

  # The params as a form with each picker posts them.
  @params %{
    "due" => "2027-03-15",
    "stay" => %{"from" => "2027-03-01", "to" => "2027-03-07"},
    "stay_map" => %{"from" => "2027-04-01", "to" => "2027-04-03"},
    "booking" => %{"from" => "2027-03-15T14:00:00+01:00", "to" => "2027-03-15T16:00:00+01:00"},
    "booking_map" => %{"from" => "2027-03-15T09:00:00Z", "to" => "2027-03-15T09:30:00Z"},
    "days" => ["", "2027-03-05", "2027-03-01"],
    "month" => "2027-03",
    "week" => "2027-W11",
    "at" => "14:30:00",
    "starts_at" => "2027-07-15T14:30:00+01:00",
    "repeat" => "FREQ=WEEKLY;BYDAY=MO,WE",
    "window" => %{
      "stay" => %{"from" => "2027-05-01", "to" => "2027-05-02"},
      "booking" => %{"from" => "2027-05-01T10:00:00Z", "to" => "2027-05-01T11:00:00Z"}
    }
  }

  defp insert!(params) do
    %Stored{}
    |> cast(params, [
      :due,
      :stay,
      :stay_map,
      :booking,
      :booking_map,
      :days,
      :month,
      :week,
      :at,
      :starts_at,
      :repeat
    ])
    |> cast_embed(:window, with: &cast(&1, &2, [:stay, :booking]))
    |> SQLiteRepo.insert!()
  end

  test "every type is written and read back as it was cast" do
    stored = insert!(@params)
    loaded = SQLiteRepo.get!(Stored, stored.id)

    assert loaded.due == ~D[2027-03-15]
    assert loaded.stay == Date.range(~D[2027-03-01], ~D[2027-03-07])
    assert loaded.stay_map == Date.range(~D[2027-04-01], ~D[2027-04-03])

    assert loaded.booking == %Koyomi.DateTimeRange{
             from: ~U[2027-03-15 13:00:00Z],
             to: ~U[2027-03-15 15:00:00Z]
           }

    assert loaded.booking_map == %Koyomi.DateTimeRange{
             from: ~U[2027-03-15 09:00:00Z],
             to: ~U[2027-03-15 09:30:00Z]
           }

    assert loaded.days == [~D[2027-03-01], ~D[2027-03-05]]
    assert loaded.month == ~D[2027-03-01]
    assert loaded.week == ~D[2027-03-15]
    assert loaded.at == ~T[14:30:00]
    assert loaded.starts_at == ~U[2027-07-15 13:30:00Z]
    assert to_string(loaded.repeat) == "FREQ=WEEKLY;BYDAY=MO,WE"

    assert loaded.window.stay == Date.range(~D[2027-05-01], ~D[2027-05-02])
    assert loaded.window.booking.to == ~U[2027-05-01 11:00:00Z]
  end

  test "the stored forms" do
    stored = insert!(@params)

    %{rows: [[stay, stay_map, booking, booking_map, days]]} =
      SQLiteRepo.query!(
        "SELECT stay, stay_map, booking, booking_map, days FROM stored WHERE id = ?",
        [stored.id]
      )

    assert stay == "2027-03-01/2027-03-07"
    assert JSON.decode!(stay_map) == %{"from" => "2027-04-01", "to" => "2027-04-03"}
    assert booking == "2027-03-15T13:00:00Z/2027-03-15T15:00:00Z"

    assert JSON.decode!(booking_map) == %{
             "from" => "2027-03-15T09:00:00Z",
             "to" => "2027-03-15T09:30:00Z"
           }

    assert JSON.decode!(days) == ["2027-03-01", "2027-03-05"]
  end

  test "empty values" do
    stored =
      insert!(%{
        "stay" => %{"from" => "", "to" => ""},
        "days" => [""],
        "booking" => %{"from" => "", "to" => ""}
      })

    loaded = SQLiteRepo.get!(Stored, stored.id)
    assert loaded.stay == nil
    assert loaded.booking == nil
    assert loaded.days == []
  end

  test "a text column queries as text: ranges in the same order as their first day" do
    insert!(Map.put(@params, "stay", %{"from" => "2027-06-01", "to" => "2027-06-02"}))
    insert!(Map.put(@params, "stay", %{"from" => "2027-01-10", "to" => "2027-01-12"}))

    import Ecto.Query

    firsts =
      SQLiteRepo.all(
        from s in Stored, where: fragment("? >= ?", s.stay, "2027-06"), select: s.stay
      )

    assert Date.range(~D[2027-06-01], ~D[2027-06-02]) in firsts
    refute Date.range(~D[2027-01-10], ~D[2027-01-12]) in firsts
  end
end
