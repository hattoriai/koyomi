defmodule Koyomi.Test do
  @moduledoc """
  Helpers for `Phoenix.LiveViewTest`, to pick values in tests with no
  browser.

      import Koyomi.Test

      test "books a stay", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/book")

        html = pick(view, "booking_stay_picker", Date.range(~D[2027-03-01], ~D[2027-03-07]))
        assert html =~ "6 nights"
      end

  `pick/3` sends the form's `phx-change` with the value in the picker's
  inputs, as the picker does in a browser, and with the other inputs of
  the form as they are. The form must have an `id`. The value is checked
  by the LiveView, not here: a test can pick a day that the rules refuse,
  to see the error.

  The inputs of a picker are not updated in LiveViewTest's copy of the
  page (they are under `phx-update="ignore"`, as in a browser, where the
  hook keeps them). To submit, give the form the values:

      view
      |> form("#booking-form", booking: %{stay: %{from: "2027-03-01", to: "2027-03-07"}})
      |> render_submit()

  `request_days/4` sends the `koyomi:days` event of a picker with `days`
  and returns the reply, to test the day content of a LiveView.
  """

  @compile {:no_warn_undefined, [LazyHTML]}

  import ExUnit.Assertions

  alias Koyomi.Wire
  alias Phoenix.LiveViewTest
  alias Plug.Conn.Query

  @doc """
  Picks `value` in the picker with the id `picker_id`, and returns the
  rendered LiveView (as `Phoenix.LiveViewTest.render_change/2` does).

  `value` is what the picker would post: a `Date`, a `Date.Range` (or
  `{first, last}`), a list of `Date`, a `Time`, a `DateTime` (posted with
  its offset), a `NaiveDateTime`, a `Koyomi.Recurrence`, an ISO string,
  or `nil` to clear it.
  """
  @spec pick(struct(), String.t(), term()) :: String.t()
  def pick(view, picker_id, value) when is_binary(picker_id) do
    picker_id = String.trim_leading(picker_id, "#")
    html = view |> LiveViewTest.render() |> LazyHTML.from_fragment()
    picker = LazyHTML.query_by_id(html, picker_id)

    if Enum.empty?(picker) do
      flunk("Koyomi.Test.pick/3: no picker with the id #{inspect(picker_id)}")
    end

    form_id = form_id(html, picker_id)
    names = input_names(picker)

    # The form posts every picker in it, as a browser does: the others with
    # the values the server gave them, this one with the new value.
    others =
      html
      |> LazyHTML.query("##{form_id} [phx-hook=Koyomi]")
      |> Enum.reject(&(LazyHTML.attribute(&1, "id") == [picker_id]))
      |> Enum.flat_map(fn other ->
        case {input_names(other), LazyHTML.attribute(other, "data-value")} do
          {[], _value} -> []
          {other_names, [json]} -> pairs(JSON.decode!(json), other_names)
          _other -> []
        end
      end)

    params =
      (others ++ pairs(Wire.encode(value), names))
      |> URI.encode_query()
      |> Query.decode()

    view
    |> LiveViewTest.form("##{form_id}")
    |> LiveViewTest.render_change(Map.put(params, "_target", target(names)))
  end

  defp form_id(html, picker_id) do
    html
    |> LazyHTML.query("form")
    |> Enum.find(fn form -> not Enum.empty?(LazyHTML.query_by_id(form, picker_id)) end)
    |> case do
      nil ->
        flunk("Koyomi.Test.pick/3: the picker #{inspect(picker_id)} is not in a form")

      form ->
        case LazyHTML.attribute(form, "id") do
          [id | _] when id != "" -> id
          _none -> flunk("Koyomi.Test.pick/3: the form of #{inspect(picker_id)} needs an id")
        end
    end
  end

  # The names of the picker's inputs, by their data-part.
  defp input_names(picker) do
    picker
    |> LazyHTML.query("input[name]")
    |> Enum.map(fn input ->
      {LazyHTML.attribute(input, "data-part") |> List.first(),
       LazyHTML.attribute(input, "name") |> List.first()}
    end)
  end

  defp pairs(%{"from" => from, "to" => to}, names) do
    [{name_of(names, "from"), from || ""}, {name_of(names, "to"), to || ""}]
  end

  defp pairs(list, names) when is_list(list) do
    name = name_of(names, "sentinel")
    [{name, ""} | Enum.map(list, &{name, &1})]
  end

  defp pairs(nil, names) do
    cond do
      List.keymember?(names, "from", 0) -> pairs(%{"from" => nil, "to" => nil}, names)
      List.keymember?(names, "sentinel", 0) -> pairs([], names)
      true -> [{name_of(names, "value"), ""}]
    end
  end

  defp pairs(value, names), do: [{name_of(names, "value"), value}]

  defp name_of(names, part) do
    case List.keyfind(names, part, 0) do
      {_part, name} -> name
      nil -> flunk("Koyomi.Test.pick/3: the picker has no #{part} input")
    end
  end

  defp target({_part, name}),
    do: name |> String.replace("[]", "") |> String.split(["[", "]"], trim: true)

  defp target([first | _rest]), do: target(first)

  @doc """
  Sends the `koyomi:days` event of the picker `picker_id` for the days
  from `first` to `last`, as the picker does when it shows them, and
  returns the reply: `%{"days" => %{"2027-03-15" => %{...}}}`.
  """
  @spec request_days(struct(), String.t(), Date.t(), Date.t()) :: map()
  def request_days(view, picker_id, %Date{} = first, %Date{} = last) do
    picker_id = String.trim_leading(picker_id, "#")
    ref = System.unique_integer([:positive])

    view
    |> LiveViewTest.element("##{picker_id}")
    |> LiveViewTest.render_hook("koyomi:days", %{
      "id" => picker_id,
      "from" => Date.to_iso8601(first),
      "to" => Date.to_iso8601(last),
      "ref" => ref
    })

    %{proxy: {proxy_ref, _topic, _pid}} = view
    assert_receive {^proxy_ref, {:reply, %{"ref" => ^ref} = reply}}
    reply
  end
end
