defmodule Koyomi.Month do
  @moduledoc """
  An Ecto type for a month, stored in a `:date` column as the first day
  of the month.

      field :billing_month, Koyomi.Month

  The month picker posts `YYYY-MM` (`"2027-03"`), as the browser's own
  month input does. The type casts it, a `Date` (any day of the month)
  and a map with `"year"` and `"month"`. The value is the first day of
  the month: `~D[2027-03-01]`.
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: :date

  @impl Ecto.Type
  def cast(nil), do: {:ok, nil}
  def cast(""), do: {:ok, nil}
  def cast(%Date{} = date), do: {:ok, Date.beginning_of_month(date)}

  def cast(text) when is_binary(text) do
    case Regex.run(~r/^(\d{4})-(\d{2})$/, String.trim(text)) do
      [_, year, month] -> new(String.to_integer(year), String.to_integer(month))
      nil -> :error
    end
  end

  def cast(%{} = map) when not is_struct(map) do
    with {:ok, year} <- integer(Map.get(map, "year", Map.get(map, :year))),
         {:ok, month} <- integer(Map.get(map, "month", Map.get(map, :month))) do
      new(year, month)
    end
  end

  def cast(_other), do: :error

  defp integer(value) when is_integer(value), do: {:ok, value}

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _other -> :error
    end
  end

  defp integer(_value), do: :error

  defp new(year, month) do
    case Date.new(year, month, 1) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  @impl Ecto.Type
  def dump(%Date{} = date), do: {:ok, Date.beginning_of_month(date)}
  def dump(nil), do: {:ok, nil}
  def dump(_other), do: :error

  @impl Ecto.Type
  def load(%Date{} = date), do: {:ok, Date.beginning_of_month(date)}
  def load(nil), do: {:ok, nil}
  def load(_other), do: :error

  @doc """
  Writes a month as `YYYY-MM`.

  ## Examples

      iex> Koyomi.Month.to_iso8601(~D[2027-03-15])
      "2027-03"

  """
  @spec to_iso8601(Date.t()) :: String.t()
  def to_iso8601(%Date{} = date), do: date |> Date.to_iso8601() |> binary_part(0, 7)
end
