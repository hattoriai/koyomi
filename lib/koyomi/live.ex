defmodule Koyomi.Live do
  @moduledoc ~S"""
  Helpers for a LiveView (or a LiveComponent) with Koyomi pickers.

  Every push carries the picker's `id` (the `id` of the component), so
  that only that picker acts on it when a page has more than one.

  ## Day content

  A picker with `days` (or a date and time picker with `slots`) asks the
  LiveView for the days it shows, a month or a few at a time, with the
  `koyomi:days` event. Answer it with `handle_days/4`:

      def handle_event("koyomi:days", params, socket) do
        Koyomi.Live.handle_days(socket, params, &days/2)
      end

      # Called with the range of days and the id of the picker.
      defp days(range, _id) do
        for room <- MyApp.Rooms.availability(range), into: %{} do
          {room.date, [label: "€#{room.price}", disabled: room.full?, marks: room.bookings]}
        end
      end

  `handle_days/4` returns the reply of the event (`{:reply, map, socket}`),
  so it is the whole `handle_event/3` clause. The callback returns a map,
  or a list of `{date, day}` tuples, where each day is:

    * `:disabled` (or `false`) - the day may not be chosen;
    * a string - a short label under the day's number (a price, "Full");
    * a keyword list or a map with:
      * `:disabled` - `true` when the day may not be chosen;
      * `:label` - a short label under the day's number;
      * `:title` - a longer description, read by screen readers and shown
        on hover ("3 rooms left");
      * `:tone` - `:accent`, `:success`, `:warning`, `:danger` or `:muted`,
        for the label and the day;
      * `:marks` - dots under the number: a count, or a list of tones;
      * `:slots` - the times that may be chosen on the day, for a date and
        time picker with `slots`: a list of `Time` (wall clock times in the
        picker's zone), of `DateTime` (shifted to the zone), or of maps with
        `:time`, `:label` and `:disabled`.

  Days that the callback leaves out have no content. A disabled day is
  only refused in the browser: check it on the server too (a rule of
  `Koyomi.Rules`, or your own validation).

  With `async: true`, the callback runs in a task of the LiveView
  (`Phoenix.LiveView.start_async/3`) and the reply says that the days will
  come; give the result to `handle_days_async/3`:

      def handle_event("koyomi:days", params, socket) do
        Koyomi.Live.handle_days(socket, params, &days/2, async: true)
      end

      def handle_async({:koyomi_days, _id, _ref} = name, result, socket) do
        {:noreply, Koyomi.Live.handle_days_async(socket, name, result)}
      end

  When the days change on the server (a booking is made), call
  `refresh_days/2`, and the picker asks again for the days it shows.
  """

  require Logger

  import Phoenix.LiveView, only: [push_event: 3, start_async: 3]

  alias Koyomi.Wire
  alias Phoenix.LiveView.Socket

  @v 1

  # The longest span of days that one koyomi:days event may ask for.
  @max_days 800

  @tones ~w(accent success warning danger muted)a

  @doc """
  Answers a `koyomi:days` event: calls `fun` with the range of days that
  the picker asks for and the picker's id, and replies with the days (see
  the module docs).

  `fun` takes the range (`Date.Range`) and the id, or only the range.
  `params` is the payload of the event (`%{"id", "from", "to", "ref"}`);
  a payload without valid days, or a span longer than #{@max_days} days,
  replies with no days. A callback that raises replies with
  `%{"error" => true}` and logs the error, so the picker shows that the
  days could not be loaded.

  Options:

    * `:async` - when `true`, run `fun` in a task (see the module docs).
  """
  @spec handle_days(Socket.t(), map(), function(), keyword()) :: {:reply, map(), Socket.t()}
  def handle_days(%Socket{} = socket, params, fun, opts \\ []) when is_function(fun) do
    id = to_string(params["id"] || "")
    ref = params["ref"]
    time_zone = params["timeZone"]

    case range(params) do
      {:ok, range} ->
        reply_days(socket, {id, ref, time_zone}, range, fun, Keyword.get(opts, :async, false))

      :error ->
        {:reply, %{"v" => @v, "id" => id, "ref" => ref, "days" => %{}}, socket}
    end
  end

  defp reply_days(socket, {id, ref, time_zone}, range, fun, true) do
    socket =
      start_async(socket, {:koyomi_days, id, ref}, fn -> {call(fun, range, id), time_zone} end)

    {:reply, %{"v" => @v, "id" => id, "ref" => ref, "pending" => true}, socket}
  end

  defp reply_days(socket, {id, ref, time_zone}, range, fun, false) do
    {:reply, days_payload(id, ref, run(fun, range, id), time_zone), socket}
  end

  @doc """
  Pushes the days of an `async: true` `handle_days/4` to the picker.
  `name` and `result` are the arguments of `handle_async/3`.
  """
  @spec handle_days_async(Socket.t(), {:koyomi_days, String.t(), term()}, term()) :: Socket.t()
  def handle_days_async(%Socket{} = socket, {:koyomi_days, id, ref}, result) do
    result =
      case result do
        {:ok, {days, time_zone}} ->
          {:ok, days, time_zone}

        {:exit, reason} ->
          Logger.error("Koyomi: the days of #{id} failed: #{inspect(reason)}")
          :error
      end

    payload =
      case result do
        {:ok, days, time_zone} -> days_payload(id, ref, {:ok, days}, time_zone)
        :error -> days_payload(id, ref, :error, nil)
      end

    push_event(socket, "koyomi:days", payload)
  end

  defp range(%{"from" => from, "to" => to}) when is_binary(from) and is_binary(to) do
    with {:ok, first} <- Date.from_iso8601(from),
         {:ok, last} <- Date.from_iso8601(to),
         days when days >= 0 and days < @max_days <- Date.diff(last, first) do
      {:ok, Date.range(first, last)}
    else
      _other -> :error
    end
  end

  defp range(_params), do: :error

  defp call(fun, range, _id) when is_function(fun, 1), do: fun.(range)
  defp call(fun, range, id) when is_function(fun, 2), do: fun.(range, id)

  defp run(fun, range, id) do
    {:ok, call(fun, range, id)}
  rescue
    exception ->
      Logger.error(
        "Koyomi: the days of #{id} failed: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )

      :error
  end

  defp days_payload(id, ref, {:ok, days}, time_zone) do
    %{"v" => @v, "id" => id, "ref" => ref, "days" => normalize_days(days, time_zone)}
  end

  defp days_payload(id, ref, :error, _time_zone) do
    %{"v" => @v, "id" => id, "ref" => ref, "error" => true}
  end

  @doc """
  Turns the days that a callback returns into the map that the picker
  reads, keyed by ISO date. `time_zone` is the picker's zone, for slots
  given as `DateTime`.

  ## Examples

      iex> Koyomi.Live.normalize_days(%{~D[2027-03-15] => [label: "€90", marks: 2]})
      %{"2027-03-15" => %{"label" => "€90", "marks" => ["accent", "accent"]}}

      iex> Koyomi.Live.normalize_days([{~D[2027-03-16], :disabled}])
      %{"2027-03-16" => %{"disabled" => true}}

  """
  @spec normalize_days(map() | list(), String.t() | nil) :: %{String.t() => map()}
  def normalize_days(days, time_zone \\ nil) when is_map(days) or is_list(days) do
    for {date, day} <- days, into: %{} do
      {date_key(date), day(day, time_zone)}
    end
  end

  defp date_key(%Date{} = date), do: Date.to_iso8601(date)

  defp date_key(text) when is_binary(text) do
    case Date.from_iso8601(text) do
      {:ok, _date} -> text
      {:error, _reason} -> raise ArgumentError, "Koyomi.Live: not a date: #{inspect(text)}"
    end
  end

  defp date_key(other), do: raise(ArgumentError, "Koyomi.Live: not a date: #{inspect(other)}")

  defp day(:disabled, _time_zone), do: %{"disabled" => true}
  defp day(false, _time_zone), do: %{"disabled" => true}
  defp day(true, _time_zone), do: %{}
  defp day(nil, _time_zone), do: %{}
  defp day(label, _time_zone) when is_binary(label), do: %{"label" => label}
  defp day(opts, time_zone) when is_list(opts), do: day(Map.new(opts), time_zone)

  defp day(%{} = opts, time_zone) do
    %{
      "disabled" => opts[:disabled] == true || nil,
      "label" => opts[:label] && to_string(opts[:label]),
      "title" => opts[:title] && to_string(opts[:title]),
      "tone" => opts[:tone] && tone(opts[:tone]),
      "marks" => marks(opts[:marks]),
      "slots" => opts[:slots] && Enum.map(opts[:slots], &slot(&1, time_zone))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp tone(tone) when tone in @tones, do: Atom.to_string(tone)
  defp tone(tone) when is_binary(tone), do: tone |> String.to_existing_atom() |> tone()

  defp tone(other) do
    raise ArgumentError,
          "Koyomi.Live: the tone #{inspect(other)} is not one of #{inspect(@tones)}"
  end

  defp marks(nil), do: nil
  defp marks(0), do: nil
  defp marks(n) when is_integer(n) and n > 0, do: List.duplicate("accent", min(n, 3))
  defp marks(list) when is_list(list), do: list |> Enum.take(3) |> Enum.map(&tone/1)

  defp slot(%Time{} = time, _time_zone), do: %{"time" => Wire.encode(time)}

  defp slot(%DateTime{} = value, time_zone) do
    local = if time_zone, do: DateTime.shift_zone!(value, time_zone), else: value
    %{"time" => local |> DateTime.to_time() |> Wire.encode()}
  end

  defp slot(%NaiveDateTime{} = value, _time_zone),
    do: %{"time" => value |> NaiveDateTime.to_time() |> Wire.encode()}

  defp slot(%{} = opts, time_zone) when not is_struct(opts) do
    time = opts[:time] || opts[:at] || raise ArgumentError, "Koyomi.Live: a slot needs :time"

    time
    |> slot(time_zone)
    |> Map.merge(
      %{
        "label" => opts[:label] && to_string(opts[:label]),
        "disabled" => opts[:disabled] == true || nil
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
    )
  end

  defp slot(list, time_zone) when is_list(list), do: slot(Map.new(list), time_zone)

  @doc """
  Sets the value of a picker from the server, as if the person had picked
  it: the picker shows it and posts it with the form (a `phx-change`
  follows). `value` is a `Date`, a `Date.Range`, a list of `Date`, a
  `Time`, a `DateTime`, a `NaiveDateTime`, a `Koyomi.Recurrence`, an ISO
  string, or `nil` to clear it.

  A picker also takes a new `value` (or field value) of a later render;
  `push_value/3` is for a value that the form does not have yet.
  """
  @spec push_value(Socket.t(), String.t(), term()) :: Socket.t()
  def push_value(%Socket{} = socket, id, value) when is_binary(id) do
    push_event(socket, "koyomi:set", payload(id, %{"value" => Wire.encode(value)}))
  end

  @doc "Asks a picker with `days` to load the days it shows again."
  @spec refresh_days(Socket.t(), String.t()) :: Socket.t()
  def refresh_days(%Socket{} = socket, id) when is_binary(id) do
    push_event(socket, "koyomi:refresh", payload(id, %{}))
  end

  @doc "Opens the popover of a picker."
  @spec open(Socket.t(), String.t()) :: Socket.t()
  def open(%Socket{} = socket, id) when is_binary(id),
    do: push_event(socket, "koyomi:open", payload(id, %{}))

  @doc "Closes the popover of a picker."
  @spec close(Socket.t(), String.t()) :: Socket.t()
  def close(%Socket{} = socket, id) when is_binary(id),
    do: push_event(socket, "koyomi:close", payload(id, %{}))

  @doc "Moves the focus to a picker's field."
  @spec focus(Socket.t(), String.t()) :: Socket.t()
  def focus(%Socket{} = socket, id) when is_binary(id),
    do: push_event(socket, "koyomi:focus", payload(id, %{}))

  defp payload(id, map), do: Map.merge(%{"v" => @v, "id" => id}, map)
end
