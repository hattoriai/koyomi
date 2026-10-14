defmodule Koyomi.Week do
  @moduledoc """
  An Ecto type for an ISO 8601 week, stored in a `:date` column as the
  Monday of the week.

      field :sprint, Koyomi.Week

  The week picker posts `YYYY-Www` (`"2027-W11"`), as the browser's own
  week input does. The type casts it and a `Date` (any day of the week).
  The value is the Monday of the week: `~D[2027-03-15]`. See
  `Koyomi.ISOWeek` for the week number of a value.
  """

  use Ecto.Type

  alias Koyomi.ISOWeek

  @impl Ecto.Type
  def type, do: :date

  @impl Ecto.Type
  def cast(nil), do: {:ok, nil}
  def cast(""), do: {:ok, nil}
  def cast(%Date{} = date), do: {:ok, Date.beginning_of_week(date, :monday)}

  def cast(text) when is_binary(text) do
    case ISOWeek.from_iso8601(text) do
      {:ok, monday} -> {:ok, monday}
      :error -> :error
    end
  end

  def cast(_other), do: :error

  @impl Ecto.Type
  def dump(%Date{} = date), do: {:ok, Date.beginning_of_week(date, :monday)}
  def dump(nil), do: {:ok, nil}
  def dump(_other), do: :error

  @impl Ecto.Type
  def load(%Date{} = date), do: {:ok, Date.beginning_of_week(date, :monday)}
  def load(nil), do: {:ok, nil}
  def load(_other), do: :error
end
