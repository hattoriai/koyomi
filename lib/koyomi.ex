defmodule Koyomi do
  @moduledoc """
  Koyomi (暦) adds date pickers to a Phoenix app.

  It ships a prebuilt picker bundle, the components that render it, Ecto
  types for what it posts, and the rules that the browser and the server
  share, so a Phoenix app gets date, range, time and recurrence fields with
  no Node.js build step of its own.

  Start with the [Quickstart](quickstart.md), then the
  [Pickers](pickers.md) and [Rules](rules.md) guides. The main modules are
  `Koyomi.Components` (the pickers), `Koyomi.Rules` and
  `Koyomi.Changeset` (what may be chosen), `Koyomi.Live` (the LiveView
  helpers) and `Koyomi.Test` (the test helpers).
  """

  @external_resource "mix.exs"
  @version Mix.Project.config()[:version]

  @doc """
  Returns the current Koyomi version.

  ## Examples

      iex> Koyomi.version()
      "#{@version}"

  """
  @spec version() :: String.t()
  def version, do: @version
end
