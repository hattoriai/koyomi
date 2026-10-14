defmodule Koyomi.Holidays do
  @moduledoc """
  Public holidays, computed by rule, for the pickers to mark days.

      Koyomi.Holidays.list("PT", 2027)
      #=> [%Koyomi.Holiday{date: ~D[2027-01-01], name: "Ano Novo", english: "New Year's Day", country: "PT"}, ...]

      range = Date.range(~D[2027-12-01], ~D[2028-01-31])
      Koyomi.Holidays.to_client(["PT", "GB"], range, "pt-PT")
      #=> %{"2027-12-25" => "Natal · Christmas Day", ...}

  A source of holidays is a country code (see `countries/0`, in any case)
  or a module that implements `Koyomi.Holidays.Provider`, for the
  holidays of a region or the days a business is closed. Each built-in
  country is such a module too, such as `Koyomi.Holidays.PT`.

  ## What is listed

  The national public holidays: the days off that the law gives in the
  whole country. Regional, local and religious days that only some
  people keep are not listed, nor are days off by custom (such as
  Christmas Eve in many countries). The module of each country says what
  it keeps and leaves out, for example `Koyomi.Holidays.CH` for
  Switzerland, where the cantons set the holidays.

  The rules are those in force in 2026. A holiday that began or ended
  since 2010 is listed only in the years it was kept (Juneteenth in the
  United States from 2021). Older changes are not followed: earlier years
  follow the rules of 2010. One-off holidays (a coronation, a jubilee)
  are not listed.

  Each holiday has a `name` in the main language of its country and an
  `english` name. A few countries have several official languages; their
  module names the language chosen: English for Canada, Dutch for
  Belgium, German for Switzerland, Finnish for Finland, Hindi for India,
  English for Ireland and South Africa.

  ## Weekends

  Where the law gives another day off when a holiday falls on a weekend
  (substitute days in the United Kingdom, 振替休日 in Japan, observed days
  in the United States, Mondayisation in Australia and New Zealand), the
  holiday stays on its date and a second entry marks the day off, such as
  "Christmas Day (substitute day)". Where the law moves the holiday
  itself (Argentina's movable holidays), only the day it moves to is
  listed.
  """

  alias Koyomi.Holiday

  @countries %{
    "AR" => Koyomi.Holidays.AR,
    "AT" => Koyomi.Holidays.AT,
    "AU" => Koyomi.Holidays.AU,
    "BE" => Koyomi.Holidays.BE,
    "BR" => Koyomi.Holidays.BR,
    "CA" => Koyomi.Holidays.CA,
    "CH" => Koyomi.Holidays.CH,
    "DE" => Koyomi.Holidays.DE,
    "DK" => Koyomi.Holidays.DK,
    "ES" => Koyomi.Holidays.ES,
    "FI" => Koyomi.Holidays.FI,
    "FR" => Koyomi.Holidays.FR,
    "GB" => Koyomi.Holidays.GB,
    "IE" => Koyomi.Holidays.IE,
    "IN" => Koyomi.Holidays.IN,
    "IT" => Koyomi.Holidays.IT,
    "JP" => Koyomi.Holidays.JP,
    "MX" => Koyomi.Holidays.MX,
    "NL" => Koyomi.Holidays.NL,
    "NO" => Koyomi.Holidays.NO,
    "NZ" => Koyomi.Holidays.NZ,
    "PL" => Koyomi.Holidays.PL,
    "PT" => Koyomi.Holidays.PT,
    "SE" => Koyomi.Holidays.SE,
    "US" => Koyomi.Holidays.US,
    "ZA" => Koyomi.Holidays.ZA
  }

  @known Enum.join(Enum.sort(Map.keys(@countries)), ", ")

  @typedoc "A country code, such as \"PT\", or a `Koyomi.Holidays.Provider` module."
  @type source :: String.t() | module()

  @doc """
  Returns the codes of the countries with built-in holidays (ISO 3166-1
  alpha-2), sorted.

  ## Examples

      iex> "JP" in Koyomi.Holidays.countries()
      true

  """
  @spec countries() :: [String.t()]
  def countries, do: @countries |> Map.keys() |> Enum.sort()

  @doc """
  Returns the holidays of a source in `year`, sorted by date. Holidays on
  the same day keep the order of the source.

  Raises `ArgumentError` for an unknown country code, a module that is
  not a provider, or a provider that returns entries of another shape.

  ## Examples

      iex> [first | _] = Koyomi.Holidays.list("pt", 2027)
      iex> {first.date, first.name, first.english, first.country}
      {~D[2027-01-01], "Ano Novo", "New Year's Day", "PT"}

  """
  @spec list(source(), integer()) :: [Holiday.t()]
  def list(source, year) when is_integer(year) do
    source |> provider!() |> holidays(year)
  end

  @doc """
  Returns the holidays of one source or a list of sources within `range`,
  across years, sorted by date. Holidays on the same day keep the order
  of the sources.

  ## Examples

      iex> range = Date.range(~D[2027-12-24], ~D[2028-01-01])
      iex> for holiday <- Koyomi.Holidays.between(["PT", "DE"], range),
      ...>     do: {holiday.date, holiday.name}
      [
        {~D[2027-12-25], "Natal"},
        {~D[2027-12-25], "1. Weihnachtstag"},
        {~D[2027-12-26], "2. Weihnachtstag"},
        {~D[2028-01-01], "Ano Novo"},
        {~D[2028-01-01], "Neujahr"}
      ]

  """
  @spec between(source() | [source()], Date.Range.t()) :: [Holiday.t()]
  def between(sources, %Date.Range{} = range) do
    sources |> sourced(range) |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Returns the holidays within `range` as a map from ISO 8601 date to
  name, for the picker in the browser.

  A holiday has its `name` when the language of `locale` (such as "pt" in
  "pt-PT" or "pt_BR") is the language of its country, and its `english`
  name otherwise. "no" and "nn" count as Norwegian Bokmål ("nb"). The
  holidays of a provider without `language/0` always have their `name`.
  Several holidays on one day are joined with " · ", without repeats.

  ## Examples

      iex> range = Date.range(~D[2027-12-25], ~D[2027-12-25])
      iex> Koyomi.Holidays.to_client(["PT", "DE"], range, "pt-PT")
      %{"2027-12-25" => "Natal · Christmas Day"}

  """
  @spec to_client(source() | [source()], Date.Range.t(), String.t()) :: %{
          String.t() => String.t()
        }
  def to_client(sources, %Date.Range{} = range, locale) when is_binary(locale) do
    language = locale_language(locale)

    sources
    |> sourced(range)
    |> Enum.group_by(
      fn {holiday, _provider} -> Date.to_iso8601(holiday.date) end,
      fn {holiday, provider} -> label(holiday, provider, language) end
    )
    |> Map.new(fn {date, names} -> {date, names |> Enum.uniq() |> Enum.join(" · ")} end)
  end

  # The holidays within the range, each with its provider.
  defp sourced(sources, range) do
    providers = sources |> List.wrap() |> Enum.map(&provider!/1)
    {first, last} = Enum.min_max([range.first.year, range.last.year])

    for provider <- providers,
        year <- first..last//1,
        holiday <- holidays(provider, year),
        holiday.date in range do
      {holiday, provider}
    end
    |> Enum.sort_by(fn {holiday, _provider} -> holiday.date end, Date)
  end

  defp holidays(provider, year) do
    country =
      if function_exported?(provider, :country, 0), do: provider.country(), else: provider

    year
    |> provider.holidays()
    |> Enum.map(fn
      {%Date{} = date, name, english} when is_binary(name) and is_binary(english) ->
        %Holiday{date: date, name: name, english: english, country: country}

      entry ->
        raise ArgumentError,
              "#{inspect(provider)}.holidays(#{year}) returned #{inspect(entry)}, " <>
                "expected a {date, name, english} tuple"
    end)
    |> Enum.filter(&(&1.date.year == year))
    |> Enum.sort_by(& &1.date, Date)
  end

  defp provider!(code) when is_binary(code) do
    case Map.fetch(@countries, String.upcase(code)) do
      {:ok, provider} ->
        Code.ensure_loaded!(provider)

      :error ->
        raise ArgumentError,
              "unknown country #{inspect(code)} for Koyomi.Holidays, " <>
                "expected one of #{@known} or a Koyomi.Holidays.Provider module"
    end
  end

  defp provider!(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :holidays, 1) do
      module
    else
      raise ArgumentError,
            "#{inspect(module)} is not a Koyomi.Holidays.Provider (it has no holidays/1), " <>
              "expected a module like that or a country code: #{@known}"
    end
  end

  defp provider!(other) do
    raise ArgumentError,
          "invalid holiday source #{inspect(other)}, " <>
            "expected a country code (#{@known}) or a Koyomi.Holidays.Provider module"
  end

  defp label(holiday, provider, language) do
    cond do
      not function_exported?(provider, :language, 0) -> holiday.name
      normalize_language(provider.language()) == language -> holiday.name
      true -> holiday.english
    end
  end

  defp locale_language(locale) do
    locale |> String.split(["-", "_"]) |> hd() |> normalize_language()
  end

  defp normalize_language(language) do
    case String.downcase(language) do
      code when code in ["no", "nn"] -> "nb"
      code -> code
    end
  end
end
