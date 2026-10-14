defmodule KoyomiTest.SQLiteRepo do
  @moduledoc "A SQLite repository for the tests of the storage of the Koyomi types."
  use Ecto.Repo, otp_app: :koyomi, adapter: Ecto.Adapters.SQLite3
end

defmodule KoyomiTest.Stored do
  @moduledoc "A schema with a field of each Koyomi type, stored in SQLite."
  use Ecto.Schema

  schema "stored" do
    field :due, :date
    field :stay, Koyomi.DateRange, storage: :string
    field :stay_map, Koyomi.DateRange, storage: :map
    field :booking, Koyomi.DateTimeRange, storage: :string
    field :booking_map, Koyomi.DateTimeRange, storage: :map
    field :days, Koyomi.Dates, default: []
    field :month, Koyomi.Month
    field :week, Koyomi.Week
    field :at, :time
    field :starts_at, :utc_datetime
    field :repeat, Koyomi.Recurrence

    embeds_one :window, Window, primary_key: false do
      field :stay, Koyomi.DateRange, storage: :string
      field :booking, Koyomi.DateTimeRange, storage: :map
    end
  end
end
