defmodule Koyomi.Dates do
  @moduledoc """
  An Ecto type for a set of days, stored in a `date[]` column (an array
  of dates), for the multiple-date picker.

      # The migration
      add :days, {:array, :date}, default: []

      # The schema
      field :days, Koyomi.Dates, default: []

  The picker posts the days as a list (`days[]`), with an empty first
  entry so that a form with no day selected still posts the field. The
  type drops the empty entries, removes repeated days and sorts the rest,
  so `["", "2027-03-05", "2027-03-01", "2027-03-05"]` casts to
  `[~D[2027-03-01], ~D[2027-03-05]]`. It also casts a list of `Date` and
  a comma-separated string.
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: {:array, :date}

  @impl Ecto.Type
  def cast(nil), do: {:ok, []}

  def cast(text) when is_binary(text), do: text |> String.split(",") |> cast()

  def cast(list) when is_list(list) do
    list
    |> Enum.reject(&(&1 in [nil, ""] or (is_binary(&1) and String.trim(&1) == "")))
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case date(value) do
        {:ok, date} -> {:cont, {:ok, [date | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, dates} -> {:ok, dates |> Enum.uniq_by(&Date.to_gregorian_days/1) |> Enum.sort(Date)}
      :error -> :error
    end
  end

  def cast(_other), do: :error

  defp date(%Date{} = date), do: {:ok, date}

  defp date(text) when is_binary(text) do
    case Date.from_iso8601(String.trim(text)) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  defp date(_other), do: :error

  @impl Ecto.Type
  def dump(list) when is_list(list) do
    if Enum.all?(list, &is_struct(&1, Date)), do: {:ok, list}, else: :error
  end

  def dump(nil), do: {:ok, nil}
  def dump(_other), do: :error

  @impl Ecto.Type
  def load(nil), do: {:ok, []}
  def load(list) when is_list(list), do: {:ok, Enum.sort(list, Date)}
  def load(_other), do: :error
end
