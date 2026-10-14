defmodule Koyomi.Rules do
  @moduledoc """
  The rules of a picker: which days, ranges and times a person may choose.

  The same rules go to the component, which disables what they refuse in
  the browser, and to `Koyomi.Changeset`, which refuses it on the server.
  So the two never disagree:

      @rules Koyomi.Rules.new(min: :today, disabled_weekdays: [6, 7], max_days: 14)

      <.date_range_picker field={@form[:stay]} rules={@rules} />

      changeset
      |> cast(params, [:stay])
      |> Koyomi.Changeset.validate_range(:stay, @rules)

  ## Options

    * `:min`, `:max` - the first and the last day that may be chosen: a
      `Date`, `:today`, or `{:today, days}` for a day relative to today
      (`{:today, 1}` is tomorrow). For a date and time picker, also a
      `DateTime` or a `NaiveDateTime`.
    * `:disabled_dates` - days that may not be chosen (a list of `Date`).
    * `:disabled_ranges` - spans of days that may not be chosen (a list of
      `Date.Range` with a step of 1, or `{first, last}` tuples).
    * `:disabled_weekdays` - weekdays that may not be chosen, ISO numbers
      from 1 (Monday) to 7 (Sunday).
    * `:min_days`, `:max_days` - the shortest and the longest range, in
      days, both ends counted: a range from Monday to Wednesday has 3 days.
    * `:allow_disabled_in_range` - when `true`, a range may span disabled
      days (a stay that may cross a closed day). `false` by default: a
      range that holds a disabled day is refused.
    * `:min_count`, `:max_count` - the fewest and the most days of a
      multiple-date picker.
    * `:min_time`, `:max_time` - the earliest and the latest time of day
      (`Time`), for the time and date and time pickers.
    * `:step` - the minutes between the times that may be chosen, counted
      from midnight: with `15`, 09:15 may be chosen and 09:20 may not.
    * `:time_zone` - the IANA time zone of `:today` (`"Etc/UTC"` by
      default). A zone other than UTC needs a time zone database (see
      `Calendar`).

  `:today` is read again on each check and each render, so rules built
  once (in a module attribute) stay right the next day.
  """

  @enforce_keys []
  defstruct min: nil,
            max: nil,
            disabled_dates: [],
            disabled_ranges: [],
            disabled_weekdays: [],
            min_days: nil,
            max_days: nil,
            allow_disabled_in_range: false,
            min_count: nil,
            max_count: nil,
            min_time: nil,
            max_time: nil,
            step: nil,
            time_zone: "Etc/UTC"

  @type bound ::
          Date.t() | DateTime.t() | NaiveDateTime.t() | :today | {:today, integer()} | nil

  @type t :: %__MODULE__{
          min: bound(),
          max: bound(),
          disabled_dates: [Date.t()],
          disabled_ranges: [{Date.t(), Date.t()}],
          disabled_weekdays: [1..7],
          min_days: pos_integer() | nil,
          max_days: pos_integer() | nil,
          allow_disabled_in_range: boolean(),
          min_count: non_neg_integer() | nil,
          max_count: pos_integer() | nil,
          min_time: Time.t() | nil,
          max_time: Time.t() | nil,
          step: pos_integer() | nil,
          time_zone: String.t()
        }

  @typedoc """
  Why a value breaks the rules, with the values that a message needs:

    * `{:before_min, min: Date | DateTime}`, `{:after_max, max: ...}`
    * `{:disabled, date: Date}` - a disabled day.
    * `{:disabled_in_range, date: Date}` - a disabled day inside a range.
    * `{:too_short, min_days: n}`, `{:too_long, max_days: n}`
    * `{:too_few, min_count: n}`, `{:too_many, max_count: n}`
    * `{:time_before_min, min_time: Time}`, `{:time_after_max, max_time: Time}`
    * `{:time_step, step: minutes}`
    * `{:reversed, []}` - a range that ends before it starts.
  """
  @type error :: {atom(), keyword()}

  @keys [
    :min,
    :max,
    :disabled_dates,
    :disabled_ranges,
    :disabled_weekdays,
    :min_days,
    :max_days,
    :allow_disabled_in_range,
    :min_count,
    :max_count,
    :min_time,
    :max_time,
    :step,
    :time_zone
  ]

  @doc """
  Builds rules from a keyword list (see the options above), or returns
  rules as they are. `nil` gives rules that allow everything.

  Raises `ArgumentError` for an unknown option or a value of the wrong
  kind, so that a mistake shows when the rules are built.

  ## Examples

      iex> rules = Koyomi.Rules.new(min: ~D[2027-03-01], disabled_weekdays: [7])
      iex> rules.disabled_weekdays
      [7]

      iex> Koyomi.Rules.new(max_days: 0)
      ** (ArgumentError) Koyomi.Rules: :max_days must be a positive integer, got: 0

  """
  @spec new(t() | keyword() | nil) :: t()
  def new(nil), do: %__MODULE__{}
  def new(%__MODULE__{} = rules), do: rules

  def new(opts) when is_list(opts) do
    Enum.reduce(opts, %__MODULE__{}, fn {key, value}, rules ->
      if key in @keys do
        Map.put(rules, key, normalize(key, value))
      else
        invalid!(key, "is not a rule; the rules are #{inspect(@keys)}", value)
      end
    end)
  end

  @doc """
  Merges more rules into rules: each option given replaces the one in
  `rules`.

  ## Examples

      iex> rules = Koyomi.Rules.new(min: ~D[2027-03-01])
      iex> Koyomi.Rules.merge(rules, max: ~D[2027-03-31]).max
      ~D[2027-03-31]

  """
  @spec merge(t() | keyword() | nil, keyword()) :: t()
  def merge(rules, opts) when is_list(opts) do
    rules = new(rules)

    Enum.reduce(new(opts) |> Map.from_struct() |> Map.take(Keyword.keys(opts)), rules, fn
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  defp normalize(key, nil) when key not in [:time_zone, :allow_disabled_in_range], do: nil

  defp normalize(key, value) when key in [:min, :max] do
    case value do
      %Date{} -> value
      %DateTime{} -> value
      %NaiveDateTime{} -> value
      :today -> :today
      {:today, days} when is_integer(days) -> {:today, days}
      _ -> invalid!(key, "must be a Date, a DateTime, :today or {:today, days}", value)
    end
  end

  defp normalize(:disabled_dates, dates) when is_list(dates) do
    Enum.map(dates, fn
      %Date{} = date -> date
      other -> invalid!(:disabled_dates, "must be a list of Date", other)
    end)
  end

  defp normalize(:disabled_ranges, ranges) when is_list(ranges) do
    Enum.map(ranges, fn
      %Date.Range{first: first, last: last, step: 1} when first <= last ->
        {first, last}

      %Date.Range{first: first, last: last, step: -1} ->
        {last, first}

      {%Date{} = first, %Date{} = last} ->
        if Date.compare(first, last) == :gt, do: {last, first}, else: {first, last}

      other ->
        invalid!(:disabled_ranges, "must be a list of Date.Range or {Date, Date}", other)
    end)
  end

  defp normalize(:disabled_weekdays, days) when is_list(days) do
    if Enum.all?(days, &(&1 in 1..7)),
      do: days |> Enum.uniq() |> Enum.sort(),
      else: invalid!(:disabled_weekdays, "must be ISO weekdays from 1 to 7", days)
  end

  defp normalize(key, value) when key in [:min_days, :max_days, :max_count, :step] do
    if is_integer(value) and value > 0,
      do: value,
      else: invalid!(key, "must be a positive integer", value)
  end

  defp normalize(:min_count, value) do
    if is_integer(value) and value >= 0,
      do: value,
      else: invalid!(:min_count, "must be a non-negative integer", value)
  end

  defp normalize(key, %Time{} = value) when key in [:min_time, :max_time], do: value

  defp normalize(:allow_disabled_in_range, value) when is_boolean(value), do: value
  defp normalize(:allow_disabled_in_range, nil), do: false

  defp normalize(:time_zone, value) when is_binary(value), do: value
  defp normalize(:time_zone, nil), do: "Etc/UTC"

  defp normalize(key, value), do: invalid!(key, "has a value of the wrong kind", value)

  defp invalid!(key, message, value) do
    raise ArgumentError, "Koyomi.Rules: #{inspect(key)} #{message}, got: #{inspect(value)}"
  end

  @doc """
  Today in the time zone of the rules.

  ## Examples

      iex> Koyomi.Rules.today(Koyomi.Rules.new([])) == Date.utc_today()
      true

  """
  @spec today(t()) :: Date.t()
  def today(%__MODULE__{time_zone: zone}) when zone in ["Etc/UTC", "UTC"], do: Date.utc_today()

  def today(%__MODULE__{time_zone: zone}) do
    case DateTime.now(zone) do
      {:ok, now} -> DateTime.to_date(now)
      {:error, reason} -> raise ArgumentError, "Koyomi.Rules: time zone #{zone}: #{reason}"
    end
  end

  @doc """
  The first day that may be chosen, with `:today` resolved, or `nil`.

  ## Examples

      iex> Koyomi.Rules.min_date(Koyomi.Rules.new(min: ~D[2027-03-01]))
      ~D[2027-03-01]

  """
  @spec min_date(t()) :: Date.t() | nil
  def min_date(%__MODULE__{min: min} = rules), do: bound_date(min, rules)

  @doc "The last day that may be chosen, with `:today` resolved, or `nil`."
  @spec max_date(t()) :: Date.t() | nil
  def max_date(%__MODULE__{max: max} = rules), do: bound_date(max, rules)

  defp bound_date(nil, _rules), do: nil
  defp bound_date(:today, rules), do: today(rules)
  defp bound_date({:today, days}, rules), do: Date.add(today(rules), days)
  defp bound_date(%Date{} = date, _rules), do: date
  defp bound_date(%NaiveDateTime{} = value, _rules), do: NaiveDateTime.to_date(value)
  defp bound_date(%DateTime{} = value, rules), do: value |> shift(rules) |> DateTime.to_date()

  defp shift(%DateTime{} = value, %__MODULE__{time_zone: zone}) when zone in ["Etc/UTC", "UTC"],
    do: DateTime.shift_zone!(value, "Etc/UTC")

  defp shift(%DateTime{} = value, %__MODULE__{time_zone: zone}),
    do: DateTime.shift_zone!(value, zone)

  @doc """
  Returns `true` when the day itself may be chosen: on or after `:min`,
  on or before `:max`, and not disabled.

  ## Examples

      iex> rules = Koyomi.Rules.new(disabled_weekdays: [6, 7])
      iex> Koyomi.Rules.allowed?(rules, ~D[2027-03-15])
      true
      iex> Koyomi.Rules.allowed?(rules, ~D[2027-03-13])
      false

  """
  @spec allowed?(t() | keyword(), Date.t()) :: boolean()
  def allowed?(rules, %Date{} = date), do: check_date(rules, date) == :ok

  @doc """
  Checks a day. Returns `:ok` or `{:error, error}` (see `t:error/0`).

  ## Examples

      iex> rules = Koyomi.Rules.new(min: ~D[2027-03-01])
      iex> Koyomi.Rules.check_date(rules, ~D[2027-02-28])
      {:error, {:before_min, min: ~D[2027-03-01]}}

  """
  @spec check_date(t() | keyword(), Date.t()) :: :ok | {:error, error()}
  def check_date(rules, %Date{} = date) do
    rules = new(rules)

    with :ok <- check_bounds(rules, date) do
      check_enabled(rules, date, :disabled)
    end
  end

  defp check_bounds(rules, date) do
    min = min_date(rules)
    max = max_date(rules)

    cond do
      min && Date.compare(date, min) == :lt -> {:error, {:before_min, min: min}}
      max && Date.compare(date, max) == :gt -> {:error, {:after_max, max: max}}
      true -> :ok
    end
  end

  defp check_enabled(rules, date, code) do
    if disabled?(rules, date), do: {:error, {code, date: date}}, else: :ok
  end

  @doc """
  Returns `true` when the day is disabled by `:disabled_dates`,
  `:disabled_ranges` or `:disabled_weekdays` (the bounds aside).
  """
  @spec disabled?(t(), Date.t()) :: boolean()
  def disabled?(%__MODULE__{} = rules, %Date{} = date) do
    Date.day_of_week(date) in rules.disabled_weekdays or
      Enum.any?(rules.disabled_dates, &(Date.compare(&1, date) == :eq)) or
      Enum.any?(rules.disabled_ranges, fn {first, last} ->
        Date.compare(date, first) != :lt and Date.compare(date, last) != :gt
      end)
  end

  @doc """
  Checks a range of days, both ends included: each end must be allowed,
  the length must be within `:min_days` and `:max_days`, and no day inside
  may be disabled unless `:allow_disabled_in_range`.

  ## Examples

      iex> rules = Koyomi.Rules.new(max_days: 7)
      iex> Koyomi.Rules.check_range(rules, Date.range(~D[2027-03-01], ~D[2027-03-07]))
      :ok
      iex> Koyomi.Rules.check_range(rules, Date.range(~D[2027-03-01], ~D[2027-03-08]))
      {:error, {:too_long, max_days: 7}}

  """
  @spec check_range(t() | keyword(), Date.Range.t() | {Date.t(), Date.t()}) ::
          :ok | {:error, error()}
  def check_range(rules, %Date.Range{first: first, last: last}),
    do: check_range(rules, {first, last})

  def check_range(rules, {%Date{} = first, %Date{} = last}) do
    rules = new(rules)
    days = Date.diff(last, first) + 1

    with :ok <- if(days < 1, do: {:error, {:reversed, []}}, else: :ok),
         :ok <- check_date(rules, first),
         :ok <- check_date(rules, last),
         :ok <- check_length(rules, days) do
      check_inside(rules, first, last)
    end
  end

  defp check_length(%__MODULE__{min_days: min}, days) when is_integer(min) and days < min,
    do: {:error, {:too_short, min_days: min}}

  defp check_length(%__MODULE__{max_days: max}, days) when is_integer(max) and days > max,
    do: {:error, {:too_long, max_days: max}}

  defp check_length(_rules, _days), do: :ok

  defp check_inside(%__MODULE__{allow_disabled_in_range: true}, _first, _last), do: :ok

  defp check_inside(rules, first, last) do
    first
    |> Date.range(last)
    |> Enum.find(&disabled?(rules, &1))
    |> case do
      nil -> :ok
      date -> {:error, {:disabled_in_range, date: date}}
    end
  end

  @doc """
  Checks the days of a multiple-date picker: each day, and the count.

  ## Examples

      iex> Koyomi.Rules.check_dates([max_count: 2], [~D[2027-03-01], ~D[2027-03-02], ~D[2027-03-03]])
      {:error, {:too_many, max_count: 2}}

  """
  @spec check_dates(t() | keyword(), [Date.t()]) :: :ok | {:error, error()}
  def check_dates(rules, dates) when is_list(dates) do
    rules = new(rules)
    count = dates |> Enum.uniq() |> length()

    cond do
      rules.min_count && count < rules.min_count ->
        {:error, {:too_few, min_count: rules.min_count}}

      rules.max_count && count > rules.max_count ->
        {:error, {:too_many, max_count: rules.max_count}}

      true ->
        Enum.find_value(dates, :ok, &check_failed(rules, &1))
    end
  end

  defp check_failed(rules, date) do
    case check_date(rules, date) do
      :ok -> nil
      error -> error
    end
  end

  @doc """
  Checks a time of day against `:min_time`, `:max_time` and `:step`.

  ## Examples

      iex> Koyomi.Rules.check_time([step: 15], ~T[09:20:00])
      {:error, {:time_step, step: 15}}

  """
  @spec check_time(t() | keyword(), Time.t()) :: :ok | {:error, error()}
  def check_time(rules, %Time{} = time) do
    rules = new(rules)
    {seconds, _micro} = Time.to_seconds_after_midnight(time)

    cond do
      rules.min_time && Time.compare(time, rules.min_time) == :lt ->
        {:error, {:time_before_min, min_time: rules.min_time}}

      rules.max_time && Time.compare(time, rules.max_time) == :gt ->
        {:error, {:time_after_max, max_time: rules.max_time}}

      rules.step && rem(seconds, rules.step * 60) != 0 ->
        {:error, {:time_step, step: rules.step}}

      true ->
        :ok
    end
  end

  @doc """
  Checks a date and time: its day as `check_date/2` does, its time as
  `check_time/2` does, and the bounds as instants when `:min` or `:max`
  is a `DateTime` or a `NaiveDateTime`.

  A `DateTime` is read in the time zone of the rules: its day and its
  time of day are those of the wall clock there.
  """
  @spec check_datetime(t() | keyword(), DateTime.t() | NaiveDateTime.t()) ::
          :ok | {:error, error()}
  def check_datetime(rules, value) do
    rules = new(rules)
    local = local_naive(value, rules)
    date = NaiveDateTime.to_date(local)

    with :ok <- check_instant_bound(rules, :min, value),
         :ok <- check_instant_bound(rules, :max, value),
         :ok <- check_date(%{rules | min: day_bound(rules.min), max: day_bound(rules.max)}, date) do
      check_time(rules, NaiveDateTime.to_time(local))
    end
  end

  # The day-level part of a bound: a DateTime or NaiveDateTime bound is
  # checked as an instant, so only a Date (or :today) stays.
  defp day_bound(%DateTime{}), do: nil
  defp day_bound(%NaiveDateTime{}), do: nil
  defp day_bound(other), do: other

  defp local_naive(%NaiveDateTime{} = value, _rules), do: value
  defp local_naive(%DateTime{} = value, rules), do: value |> shift(rules) |> DateTime.to_naive()

  defp check_instant_bound(%__MODULE__{} = rules, key, value) do
    case {Map.fetch!(rules, key), value} do
      {%DateTime{} = bound, %DateTime{}} ->
        compare_bound(key, DateTime.compare(value, bound), bound)

      {%DateTime{} = bound, %NaiveDateTime{}} ->
        compare_naive(key, value, local_naive(bound, rules), bound)

      {%NaiveDateTime{} = bound, %NaiveDateTime{}} ->
        compare_naive(key, value, bound, bound)

      {%NaiveDateTime{} = bound, %DateTime{}} ->
        compare_naive(key, local_naive(value, rules), bound, bound)

      _other ->
        :ok
    end
  end

  defp compare_naive(key, value, bound, shown),
    do: compare_bound(key, NaiveDateTime.compare(value, bound), shown)

  defp compare_bound(:min, :lt, bound), do: {:error, {:before_min, min: bound}}
  defp compare_bound(:max, :gt, bound), do: {:error, {:after_max, max: bound}}
  defp compare_bound(_key, _order, _bound), do: :ok

  @doc """
  The rules as the browser reads them: a map with JSON values, `:today`
  resolved and the camelCase keys of the picker. Empty rules are left out.

  ## Examples

      iex> Koyomi.Rules.to_client(Koyomi.Rules.new(min: ~D[2027-03-01], disabled_weekdays: [7]))
      %{"min" => "2027-03-01", "disabledWeekdays" => [7]}

  """
  @spec to_client(t() | keyword() | nil) :: map()
  def to_client(rules) do
    rules = new(rules)

    %{
      "min" => client_bound(rules.min, rules),
      "max" => client_bound(rules.max, rules),
      "disabledDates" => Enum.map(rules.disabled_dates, &Date.to_iso8601/1),
      "disabledRanges" =>
        Enum.map(rules.disabled_ranges, fn {a, b} ->
          [Date.to_iso8601(a), Date.to_iso8601(b)]
        end),
      "disabledWeekdays" => rules.disabled_weekdays,
      "minDays" => rules.min_days,
      "maxDays" => rules.max_days,
      "allowDisabledInRange" => rules.allow_disabled_in_range || nil,
      "minCount" => rules.min_count,
      "maxCount" => rules.max_count,
      "minTime" => rules.min_time && Time.to_iso8601(Time.truncate(rules.min_time, :second)),
      "maxTime" => rules.max_time && Time.to_iso8601(Time.truncate(rules.max_time, :second)),
      "step" => rules.step
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, []] end)
    |> Map.new()
  end

  defp client_bound(nil, _rules), do: nil
  defp client_bound(%DateTime{} = value, _rules), do: DateTime.to_iso8601(value)
  defp client_bound(%NaiveDateTime{} = value, _rules), do: NaiveDateTime.to_iso8601(value)
  defp client_bound(other, rules), do: other |> bound_date(rules) |> Date.to_iso8601()
end
