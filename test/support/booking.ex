defmodule KoyomiTest.Booking do
  @moduledoc "An embedded schema with a field of each Koyomi type, for the tests."
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
    field :repeat, Koyomi.Recurrence
  end

  def due_rules, do: Koyomi.Rules.new(min: ~D[2027-03-01], disabled_weekdays: [7])
  def stay_rules, do: Koyomi.Rules.new(min_days: 2, max_days: 7)
  def time_rules, do: Koyomi.Rules.new(step: 15, min_time: ~T[09:00:00], max_time: ~T[17:00:00])

  def changeset(booking \\ %__MODULE__{}, params) do
    booking
    |> cast(params, [:due, :stay, :days, :month, :week, :year, :at, :repeat])
    |> Koyomi.Changeset.cast_datetime(params, :starts_at, "Europe/Lisbon")
    |> Koyomi.Changeset.validate_date(:due, due_rules())
    |> Koyomi.Changeset.validate_range(:stay, stay_rules())
    |> Koyomi.Changeset.validate_dates(:days, max_count: 3)
    |> Koyomi.Changeset.validate_time(:at, time_rules())
  end
end
