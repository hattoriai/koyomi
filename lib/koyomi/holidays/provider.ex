defmodule Koyomi.Holidays.Provider do
  @moduledoc """
  A source of holidays that `Koyomi.Holidays` can read, for example the
  holidays of a region or the days a company is closed.

      defmodule MyApp.Closures do
        @behaviour Koyomi.Holidays.Provider

        @impl true
        def holidays(year) do
          [{Date.new!(year, 12, 24), "Fermeture", "Office closed"}]
        end

        @impl true
        def language, do: "fr"
      end

      Koyomi.Holidays.between(["FR", MyApp.Closures], range)

  `holidays/1` returns the holidays of one year as `{date, name, english}`
  tuples: `name` in the language of `language/0`, `english` in English.
  Entries with a date in another year are dropped. The order does not
  matter.

  The optional callbacks:

    * `language/0` - the language of `name`, a code such as "fr" or "ja".
      `Koyomi.Holidays.to_client/3` shows `name` to a locale in that
      language and `english` to the others. A provider without it always
      shows `name`.
    * `country/0` - the value of `Koyomi.Holiday.country` for its holidays.
      The provider module otherwise.

  `Koyomi.Holidays.Rules` has the date rules that the built-in countries
  use, such as `Koyomi.Holidays.Rules.easter/1`.
  """

  @typedoc "A holiday: `{date, name, english}`."
  @type entry :: {Date.t(), String.t(), String.t()}

  @doc "Returns the holidays of `year`."
  @callback holidays(year :: integer()) :: [entry()]

  @doc "Returns the language of the names, such as \"fr\"."
  @callback language() :: String.t()

  @doc "Returns the country of the holidays, such as \"FR\"."
  @callback country() :: String.t()

  @optional_callbacks language: 0, country: 0
end
