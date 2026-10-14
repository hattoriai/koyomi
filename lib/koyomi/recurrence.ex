defmodule Koyomi.Recurrence do
  @moduledoc """
  A recurrence rule: a subset of the RFC 5545 `RRULE`, with the same
  parsing, serialization, occurrences and descriptions as the browser
  module `rrule.ts`.

  A `Koyomi.Recurrence` struct has:

    * `:freq` - `:daily`, `:weekly`, `:monthly` or `:yearly`.
    * `:interval` - the number of periods between two periods with
      occurrences, `1` by default.
    * `:count` - the number of occurrences, the start included, or `nil`.
    * `:until` - the last day (a `Date`) or instant (a `DateTime` in UTC)
      that an occurrence may fall on, inclusive, or `nil`.
    * `:by_day` - weekdays, as `{ordinal, weekday}` tuples: the weekday
      from 1 (Monday) to 7 (Sunday), the ordinal `nil` for every such day,
      or a position in the month or year (`1` the first, `-1` the last).
    * `:by_month_day` - days of the month, `1` to `31`, or `-1` (the last)
      to `-31`.
    * `:by_month` - months, `1` to `12`.
    * `:by_set_pos` - positions in the set of days of each period, `1` to
      `366` or `-1` to `-366`.
    * `:week_start` - the first day of the week, `1` (Monday, the default)
      to `7`. It changes which days fall in a week, so it matters for a
      `:weekly` rule with an interval above one, or with `:by_set_pos`.

  The lists are sorted and without duplicates: the weekdays in ISO order,
  then by ordinal; numbers from `1` up, then from `-1` down.

  ## The rule text

  `parse/1` reads the parts `FREQ` (`DAILY`, `WEEKLY`, `MONTHLY` or
  `YEARLY`), `INTERVAL`, `COUNT`, `UNTIL` (`20271231` or
  `20271231T235959Z`), `BYDAY` (`MO`, or with an ordinal for a monthly or
  yearly rule: `1MO`, `-1FR`), `BYMONTHDAY`, `BYMONTH`, `BYSETPOS` and
  `WKST`, in any order and any case, with or without a leading `RRULE:`.
  Any other part is an error that names it, and so are `COUNT` with
  `UNTIL`, `BYMONTHDAY` in a weekly rule, and `BYSETPOS` without another
  `BY` part.

  `to_string/1` writes the parts in one order, `FREQ`, `INTERVAL` (left
  out when 1), `BYMONTH`, `BYMONTHDAY`, `BYDAY`, `BYSETPOS`, `WKST` (left
  out when Monday), then `COUNT` or `UNTIL`, so that one rule has one text.

  ## Occurrences

  `occurrences/3` follows RFC 5545. The start is `DTSTART`: it is the
  first occurrence, and `COUNT` counts it. Each `BY` part expands or limits
  the days of a period as the RFC's table says: `BYMONTH` expands a yearly
  rule and limits the others; `BYMONTHDAY` expands a monthly or yearly
  rule and limits a daily one; `BYDAY` expands a weekly, monthly or yearly
  rule, unless `BYMONTHDAY` is there, and then limits it. An ordinal
  counts in the month for a monthly rule, and for a yearly rule with
  `BYMONTH`; in the year otherwise. `BYSETPOS` then picks from the sorted
  days of each period.

  A part that the rule leaves out comes from the start: the weekday of a
  weekly rule, the day of the month of a monthly rule, and the day and
  month of a yearly one. A monthly rule that starts on the 31st skips the
  months without one, as the RFC asks.

  ## Descriptions

  `describe/3` writes a sentence in English, European Portuguese,
  Spanish, French, German, Italian, Dutch or Japanese, the same as
  `describeRule` in the browser.

  ## Ecto

  `Koyomi.Recurrence` is also an `Ecto.Type`, stored as the rule text in a
  string column. `cast/1` takes a string or a struct; an empty string casts
  to `nil`, and a rule that does not parse gives the changeset its error.

      field :repeat, Koyomi.Recurrence

  ## Examples

      iex> {:ok, rule} = Koyomi.Recurrence.parse("RRULE:FREQ=WEEKLY;BYDAY=WE,MO;COUNT=4")
      iex> to_string(rule)
      "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4"
      iex> rule |> Koyomi.Recurrence.occurrences(~D[2027-03-15]) |> Enum.to_list()
      [~D[2027-03-15], ~D[2027-03-17], ~D[2027-03-22], ~D[2027-03-24]]
      iex> Koyomi.Recurrence.describe(rule)
      "Weekly on Monday and Wednesday, 4 times"

  """

  use Ecto.Type

  import Kernel, except: [to_string: 1]

  alias Koyomi.Recurrence.{Describe, Expand}

  defstruct freq: nil,
            interval: 1,
            count: nil,
            until: nil,
            by_day: [],
            by_month_day: [],
            by_month: [],
            by_set_pos: [],
            week_start: 1

  @type freq :: :daily | :weekly | :monthly | :yearly
  @type weekday :: 1..7

  @type t :: %__MODULE__{
          freq: freq(),
          interval: pos_integer(),
          count: pos_integer() | nil,
          until: Date.t() | DateTime.t() | nil,
          by_day: [{integer() | nil, weekday()}],
          by_month_day: [integer()],
          by_month: [1..12],
          by_set_pos: [integer()],
          week_start: weekday()
        }

  @freqs %{"DAILY" => :daily, "WEEKLY" => :weekly, "MONTHLY" => :monthly, "YEARLY" => :yearly}
  @days ~w(MO TU WE TH FR SA SU)
  @parts ~w(FREQ INTERVAL COUNT UNTIL BYDAY BYMONTHDAY BYMONTH BYSETPOS WKST)
  @max_number 999_999_999

  @doc """
  Parses a rule text.

  ## Examples

      iex> {:ok, rule} = Koyomi.Recurrence.parse("FREQ=MONTHLY;BYDAY=-1FR")
      iex> rule.by_day
      [{-1, 5}]

      iex> Koyomi.Recurrence.parse("FREQ=HOURLY")
      {:error, "FREQ=HOURLY is not supported"}

      iex> Koyomi.Recurrence.parse("FREQ=DAILY;BYHOUR=9")
      {:error, "BYHOUR is not supported"}

  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(text) when is_binary(text) do
    text = text |> String.trim() |> String.upcase()

    text =
      if String.starts_with?(text, "RRULE:"),
        do: binary_part(text, 6, byte_size(text) - 6),
        else: text

    case text |> String.split(";") |> Enum.reject(&(&1 == "")) do
      [] -> {:error, "The rule is empty"}
      parts -> parse_parts(parts, %__MODULE__{}, MapSet.new())
    end
  end

  @doc """
  Parses a rule text, or raises `ArgumentError`.

  ## Examples

      iex> Koyomi.Recurrence.parse!("FREQ=DAILY;INTERVAL=2").interval
      2

  """
  @spec parse!(String.t()) :: t()
  def parse!(text) do
    case parse(text) do
      {:ok, rule} -> rule
      {:error, message} -> raise ArgumentError, "invalid recurrence rule: " <> message
    end
  end

  defp parse_parts([], rule, _seen), do: finish(rule)

  defp parse_parts([part | rest], rule, seen) do
    with {:ok, name, value} <- split_part(part),
         :ok <- check_name(name, seen),
         {:ok, rule} <- parse_value(name, value, rule) do
      parse_parts(rest, rule, MapSet.put(seen, name))
    end
  end

  defp split_part(part) do
    case String.split(part, "=", parts: 2) do
      [name, ""] -> {:error, name <> " is empty"}
      [name, value] -> {:ok, name, value}
      [_name] -> {:error, part <> " is not a NAME=VALUE pair"}
    end
  end

  defp check_name(name, seen) do
    cond do
      name not in @parts -> {:error, name <> " is not supported"}
      MapSet.member?(seen, name) -> {:error, name <> " appears twice"}
      true -> :ok
    end
  end

  defp parse_value("FREQ", value, rule) do
    case Map.fetch(@freqs, value) do
      {:ok, freq} -> {:ok, %{rule | freq: freq}}
      :error -> {:error, "FREQ=" <> value <> " is not supported"}
    end
  end

  defp parse_value(name, value, rule) when name in ["INTERVAL", "COUNT"] do
    if value =~ ~r/^\d{1,9}$/ and String.to_integer(value) > 0 do
      key = if name == "INTERVAL", do: :interval, else: :count
      {:ok, Map.put(rule, key, String.to_integer(value))}
    else
      {:error, name <> " must be a positive whole number"}
    end
  end

  defp parse_value("UNTIL", value, rule) do
    case parse_until(value) do
      {:ok, until} -> {:ok, %{rule | until: until}}
      :error -> {:error, until_error()}
    end
  end

  defp parse_value("BYDAY", value, rule) do
    parse_list(value, "BYDAY has an invalid day: ", &parse_day/1, &%{rule | by_day: &1})
  end

  defp parse_value("BYMONTHDAY", value, rule) do
    parse_list(
      value,
      "BYMONTHDAY has an invalid day: ",
      &parse_int/1,
      &%{rule | by_month_day: &1}
    )
  end

  defp parse_value("BYMONTH", value, rule) do
    parse_list(value, "BYMONTH has an invalid month: ", &parse_int/1, &%{rule | by_month: &1})
  end

  defp parse_value("BYSETPOS", value, rule) do
    parse_list(
      value,
      "BYSETPOS has an invalid position: ",
      &parse_int/1,
      &%{rule | by_set_pos: &1}
    )
  end

  defp parse_value("WKST", value, rule) do
    case weekday_of(value) do
      nil -> {:error, "WKST has an invalid day: " <> value}
      day -> {:ok, %{rule | week_start: day}}
    end
  end

  defp parse_list(value, message, parse_item, put) do
    value
    |> String.split(",")
    |> Enum.reduce_while({:ok, []}, fn token, {:ok, acc} ->
      case parse_item.(token) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        :error -> {:halt, {:error, message <> token}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, put.(Enum.reverse(items))}
      error -> error
    end
  end

  defp parse_int(token) do
    if token =~ ~r/^[+-]?\d{1,3}$/, do: {:ok, String.to_integer(token)}, else: :error
  end

  defp parse_day(token) do
    case Regex.run(~r/^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$/, token) do
      [_, "", day] -> {:ok, {nil, weekday_of(day)}}
      [_, ordinal, day] -> {:ok, {String.to_integer(ordinal), weekday_of(day)}}
      nil -> :error
    end
  end

  defp weekday_of(code) do
    case Enum.find_index(@days, &(&1 == code)) do
      nil -> nil
      index -> index + 1
    end
  end

  defp parse_until(value) do
    case Regex.run(~r/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z)?$/, value) do
      [_, y, m, d] ->
        Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d))
        |> ok_or_error()

      [_, y, m, d, hh, mm, ss] ->
        with {:ok, date} <-
               Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)),
             {:ok, time} <-
               Time.new(String.to_integer(hh), String.to_integer(mm), String.to_integer(ss)) do
          DateTime.new(date, time, "Etc/UTC")
        end
        |> ok_or_error()

      nil ->
        :error
    end
  end

  defp ok_or_error({:ok, value}), do: {:ok, value}
  defp ok_or_error(_error), do: :error

  defp until_error,
    do: "UNTIL must be a date (20271231) or a UTC date and time (20271231T235959Z)"

  @doc """
  Builds a rule from options, with the same checks as `parse/1`.

  The options are the fields of the struct. `:by_day` also takes bare
  weekdays (`[1, 3]` for Monday and Wednesday), and `:until` a `DateTime`
  in any time zone, which is shifted to UTC.

  ## Examples

      iex> {:ok, rule} = Koyomi.Recurrence.new(freq: :weekly, interval: 2, by_day: [3, 1])
      iex> to_string(rule)
      "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE"

      iex> Koyomi.Recurrence.new(freq: :weekly, by_month_day: [1])
      {:error, "BYMONTHDAY cannot be used with FREQ=WEEKLY"}

  """
  @spec new(keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(opts) when is_list(opts) do
    known = Map.keys(%__MODULE__{}) -- [:__struct__]

    case Keyword.keys(opts) -- known do
      [] -> build(opts)
      [key | _] -> {:error, "#{inspect(key)} is not a rule option"}
    end
  end

  defp build(opts) do
    rule = struct(__MODULE__, opts)

    with {:ok, freq} <- new_freq(rule.freq),
         {:ok, until} <- new_until(rule.until),
         {:ok, by_day} <- new_by_day(rule.by_day),
         :ok <- new_lists(rule) do
      finish(%{rule | freq: freq, until: until, by_day: by_day})
    end
  end

  defp new_freq(freq) when freq in [:daily, :weekly, :monthly, :yearly, nil], do: {:ok, freq}

  defp new_freq(freq),
    do: {:error, "FREQ=#{freq |> Kernel.to_string() |> String.upcase()} is not supported"}

  defp new_until(nil), do: {:ok, nil}
  defp new_until(%Date{} = date), do: {:ok, date}

  defp new_until(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_unix()
    |> DateTime.from_unix()
  end

  defp new_until(_other), do: {:error, until_error()}

  defp new_by_day(days) when is_list(days) do
    Enum.reduce_while(days, {:ok, []}, fn
      {ordinal, day}, {:ok, acc}
      when (is_integer(ordinal) or is_nil(ordinal)) and is_integer(day) ->
        {:cont, {:ok, [{ordinal, day} | acc]}}

      day, {:ok, acc} when is_integer(day) ->
        {:cont, {:ok, [{nil, day} | acc]}}

      other, _acc ->
        {:halt, {:error, "BYDAY has an invalid day: #{inspect(other)}"}}
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      error -> error
    end
  end

  defp new_by_day(other), do: {:error, "BYDAY has an invalid day: #{inspect(other)}"}

  defp new_lists(rule) do
    checks = [
      {rule.interval, "INTERVAL must be a positive whole number", &positive_number?/1},
      {rule.count, "COUNT must be a positive whole number",
       &(is_nil(&1) or positive_number?(&1))},
      {rule.by_month_day, "BYMONTHDAY has an invalid day: ", :list},
      {rule.by_month, "BYMONTH has an invalid month: ", :list},
      {rule.by_set_pos, "BYSETPOS has an invalid position: ", :list},
      {rule.week_start, "WKST has an invalid day: ", &(&1 in 1..7)}
    ]

    Enum.find_value(checks, :ok, fn
      {value, message, :list} ->
        if not (is_list(value) and Enum.all?(value, &is_integer/1)),
          do: {:error, message <> inspect(value)}

      {value, message, check} ->
        cond do
          check.(value) -> nil
          String.ends_with?(message, ": ") -> {:error, message <> inspect(value)}
          true -> {:error, message}
        end
    end)
  end

  defp positive_number?(value), do: is_integer(value) and value in 1..@max_number

  # The checks of values and of parts together, in the order that
  # `rrule.ts` makes them, then the sorted lists.
  defp finish(rule) do
    with :ok <- validate(rule) do
      {:ok,
       %{
         rule
         | by_day: rule.by_day |> Enum.uniq() |> Enum.sort_by(&day_key/1),
           by_month_day: rule.by_month_day |> Enum.uniq() |> Enum.sort_by(&number_key/1),
           by_month: rule.by_month |> Enum.uniq() |> Enum.sort(),
           by_set_pos: rule.by_set_pos |> Enum.uniq() |> Enum.sort_by(&number_key/1)
       }}
    end
  end

  defp validate(%{freq: nil}), do: {:error, "FREQ is missing"}

  defp validate(rule) do
    [
      &check_count_and_until/1,
      &check_months/1,
      &check_weekly_month_days/1,
      &check_month_days/1,
      &check_days/1,
      &check_day_ordinals/1,
      &check_positions/1,
      &check_lone_positions/1
    ]
    |> Enum.find_value(:ok, & &1.(rule))
  end

  # Each check gives an error, or nil when the rule passes it.

  defp check_count_and_until(%{count: count, until: until})
       when not is_nil(count) and not is_nil(until),
       do: {:error, "COUNT and UNTIL cannot both be set"}

  defp check_count_and_until(_rule), do: nil

  defp check_months(rule) do
    if month = Enum.find(rule.by_month, &(&1 not in 1..12)),
      do: {:error, "BYMONTH has an invalid month: #{month}"}
  end

  defp check_weekly_month_days(%{freq: :weekly, by_month_day: [_ | _]}),
    do: {:error, "BYMONTHDAY cannot be used with FREQ=WEEKLY"}

  defp check_weekly_month_days(_rule), do: nil

  defp check_month_days(rule) do
    if day = Enum.find(rule.by_month_day, &(&1 == 0 or abs(&1) > 31)),
      do: {:error, "BYMONTHDAY has an invalid day: #{day}"}
  end

  defp check_days(rule) do
    if entry = Enum.find(rule.by_day, &(not valid_day?(&1, rule.freq))),
      do: {:error, "BYDAY has an invalid day: " <> format_day(entry)}
  end

  defp check_day_ordinals(%{freq: freq, by_day: by_day}) when freq in [:daily, :weekly] do
    if Enum.any?(by_day, &(elem(&1, 0) != nil)),
      do: {:error, "BYDAY ordinals such as 1MO need FREQ=MONTHLY or FREQ=YEARLY"}
  end

  defp check_day_ordinals(_rule), do: nil

  defp check_positions(rule) do
    if position = Enum.find(rule.by_set_pos, &(&1 == 0 or abs(&1) > 366)),
      do: {:error, "BYSETPOS has an invalid position: #{position}"}
  end

  defp check_lone_positions(%{by_set_pos: [_ | _], by_day: [], by_month_day: [], by_month: []}),
    do: {:error, "BYSETPOS needs BYDAY, BYMONTHDAY or BYMONTH"}

  defp check_lone_positions(_rule), do: nil

  defp valid_day?({ordinal, day}, freq) do
    day in 1..7 and
      (ordinal == nil or (ordinal != 0 and abs(ordinal) <= if(freq == :monthly, do: 5, else: 53)))
  end

  defp day_key({ordinal, day}), do: {day, number_key(ordinal || 0)}
  defp number_key(n) when n >= 0, do: n
  defp number_key(n), do: 1000 - n

  @doc """
  Writes the rule text, in the canonical order of the parts.

  ## Examples

      iex> Koyomi.Recurrence.parse!("byday=fr;freq=monthly;bysetpos=-1;interval=1") |> Koyomi.Recurrence.to_string()
      "FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1"

  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = rule) do
    [
      "FREQ=" <> (rule.freq |> Atom.to_string() |> String.upcase()),
      rule.interval != 1 && "INTERVAL=#{rule.interval}",
      rule.by_month != [] && "BYMONTH=" <> Enum.join(rule.by_month, ","),
      rule.by_month_day != [] && "BYMONTHDAY=" <> Enum.join(rule.by_month_day, ","),
      rule.by_day != [] && "BYDAY=" <> Enum.map_join(rule.by_day, ",", &format_day/1),
      rule.by_set_pos != [] && "BYSETPOS=" <> Enum.join(rule.by_set_pos, ","),
      rule.week_start != 1 && "WKST=" <> Enum.at(@days, rule.week_start - 1),
      rule.count && "COUNT=#{rule.count}",
      rule.until && "UNTIL=" <> format_until(rule.until)
    ]
    |> Enum.filter(& &1)
    |> Enum.join(";")
  end

  defp format_day({nil, day}), do: Enum.at(@days, day - 1, "#{day}")
  defp format_day({ordinal, day}), do: "#{ordinal}" <> Enum.at(@days, day - 1, "#{day}")

  defp format_until(%Date{} = date), do: Calendar.strftime(date, "%Y%m%d")
  defp format_until(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y%m%dT%H%M%SZ")

  @doc """
  The occurrences of a rule from a start, as a lazy stream of the start's
  type: `Date`, `NaiveDateTime` or `DateTime`.

  The start is the first occurrence. Each other one has the start's time
  of day. For a `DateTime`, that is the wall clock time in the start's
  time zone: a time that the clocks skip moves forward by the length of
  the gap, and a time that happens twice takes the earlier instant. The
  option `:time_zone_database` names the database for this
  (`Calendar.get_time_zone_database/0` by default).

  `UNTIL` is inclusive. A date `UNTIL` ends on that day, whatever the
  time; a UTC `UNTIL` compares with the instant of a `DateTime`, with the
  wall clock of a `NaiveDateTime` (taken as UTC), and with the day of a
  `Date`. A rule that stops producing (`BYMONTH=2;BYMONTHDAY=30`) ends
  after 400 years without an occurrence, or at the year 9999.

  ## Examples

      iex> Koyomi.Recurrence.parse!("FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3")
      ...> |> Koyomi.Recurrence.occurrences(~N[2027-01-29 09:30:00])
      ...> |> Enum.to_list()
      [~N[2027-01-29 09:30:00], ~N[2027-02-26 09:30:00], ~N[2027-03-31 09:30:00]]

  """
  @spec occurrences(t(), Date.t() | NaiveDateTime.t() | DateTime.t(), keyword()) :: Enumerable.t()
  def occurrences(%__MODULE__{} = rule, start, opts \\ []) do
    database = Keyword.get_lazy(opts, :time_zone_database, &Calendar.get_time_zone_database/0)
    Expand.occurrences(rule, start, database)
  end

  @doc """
  The occurrences of a rule from a start whose day falls between two
  dates, both included, as a list. The options are those of
  `occurrences/3`.

  ## Examples

      iex> Koyomi.Recurrence.parse!("FREQ=YEARLY")
      ...> |> Koyomi.Recurrence.between(~D[2024-02-29], ~D[2025-01-01], ~D[2032-12-31])
      [~D[2028-02-29], ~D[2032-02-29]]

  """
  @spec between(t(), Date.t() | NaiveDateTime.t() | DateTime.t(), Date.t(), Date.t(), keyword()) ::
          [Date.t() | NaiveDateTime.t() | DateTime.t()]
  def between(%__MODULE__{} = rule, start, %Date{} = from, %Date{} = to, opts \\ []) do
    rule
    |> occurrences(start, opts)
    |> Stream.drop_while(&(Date.compare(Expand.day_of(&1), from) == :lt))
    |> Enum.take_while(&(Date.compare(Expand.day_of(&1), to) != :gt))
  end

  @doc """
  A sentence that describes the rule.

  The locale is a language tag: `"en"`, `"pt"` (European Portuguese),
  `"es"`, `"fr"`, `"de"`, `"it"`, `"nl"` or `"ja"`. A region variant
  (`"pt-BR"`, `"en_GB"`) takes its language, and any other language takes
  English.

  The options:

    * `:start` - the start of the occurrences (a `Date`, `NaiveDateTime`
      or `DateTime`), to name the days that the rule takes from it: the
      weekday of a weekly rule, the day of a monthly one, the date of a
      yearly one.

  ## Examples

      iex> rule = Koyomi.Recurrence.parse!("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10")
      iex> Koyomi.Recurrence.describe(rule)
      "Every 2 weeks on Monday and Wednesday, 10 times"
      iex> Koyomi.Recurrence.describe(rule, "pt-PT")
      "A cada 2 semanas à segunda-feira e à quarta-feira, 10 vezes"

      iex> Koyomi.Recurrence.parse!("FREQ=YEARLY;UNTIL=20271231")
      ...> |> Koyomi.Recurrence.describe("en", start: ~D[2026-03-15])
      "Every year on 15 March until 31 December 2027"

  """
  @spec describe(t(), String.t(), keyword()) :: String.t()
  def describe(%__MODULE__{} = rule, locale \\ "en", opts \\ []) do
    start = opts |> Keyword.get(:start) |> then(&(&1 && Expand.day_of(&1)))
    Describe.sentence(rule, Describe.language(locale), start)
  end

  # Ecto.Type

  @impl Ecto.Type
  def type, do: :string

  @impl Ecto.Type
  def cast(%__MODULE__{} = rule), do: {:ok, rule}
  def cast(nil), do: {:ok, nil}

  def cast(text) when is_binary(text) do
    if String.trim(text) == "" do
      {:ok, nil}
    else
      case parse(text) do
        {:ok, rule} -> {:ok, rule}
        {:error, message} -> {:error, message: message}
      end
    end
  end

  def cast(_other), do: :error

  @impl Ecto.Type
  def dump(%__MODULE__{} = rule), do: {:ok, __MODULE__.to_string(rule)}
  def dump(nil), do: {:ok, nil}
  def dump(_other), do: :error

  @impl Ecto.Type
  def load(nil), do: {:ok, nil}

  def load(text) when is_binary(text) do
    case parse(text) do
      {:ok, rule} -> {:ok, rule}
      {:error, _message} -> :error
    end
  end

  def load(_other), do: :error

  defimpl String.Chars do
    def to_string(rule), do: Koyomi.Recurrence.to_string(rule)
  end
end
