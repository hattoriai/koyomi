defmodule Koyomi.Holidays.Country do
  @moduledoc false
  # The common part of the built-in countries: the behaviour, `country/0`,
  # `language/0` and the date rules.

  defmacro __using__(opts) do
    code = Keyword.fetch!(opts, :code)
    language = Keyword.fetch!(opts, :language)

    quote do
      @behaviour Koyomi.Holidays.Provider
      import Koyomi.Holidays.Rules

      @impl true
      @spec country() :: String.t()
      def country, do: unquote(code)

      @impl true
      @spec language() :: String.t()
      def language, do: unquote(language)

      defp date(year, month, day), do: Date.new!(year, month, day)
    end
  end
end
