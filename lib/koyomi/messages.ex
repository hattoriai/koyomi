defmodule Koyomi.Messages do
  @moduledoc """
  The words of the pickers: button labels, hints, announcements for screen
  readers and the messages of a refused choice.

  Month names, weekday names, numbers and dates come from the browser
  (`Intl`), in any locale. The other words are here, in English,
  Portuguese, Spanish, French, German, Italian, Dutch and Japanese; a
  locale with a region (`pt-BR`, `en-GB`) takes the words of its language,
  and another language gets English.

  Give a picker other words with `messages`, a map from the keys of
  `keys/0` to the new words, for example to use your own Gettext
  translations:

      <.date_picker field={@form[:due]} messages={%{"today" => gettext("Today")}} />

  Or set them for every picker in the config:

      config :koyomi, messages: %{"fr" => %{"today" => "Aujourd'hui"}}

  A word may have placeholders in braces (`{n}`, `{date}`), which the
  picker fills. The keys that end in `One` and `Other` are the plural
  forms of a count, picked with the plural rules of the locale.
  """

  alias Koyomi.Messages.Translations

  @doc """
  Returns the keys of the messages.

  ## Examples

      iex> "today" in Koyomi.Messages.keys()
      true

  """
  @spec keys() :: [String.t()]
  def keys, do: Map.keys(Translations.english())

  @doc """
  Returns the languages with built-in words.

  ## Examples

      iex> Koyomi.Messages.languages()
      ["de", "en", "es", "fr", "it", "ja", "nl", "pt"]

  """
  @spec languages() :: [String.t()]
  def languages, do: Translations.all() |> Map.keys() |> Enum.sort()

  @doc """
  The words for a locale: the built-in words of its language, then the
  words of the config for the locale and for its language, then
  `overrides`. Every key has a value (English when a language lacks one).

  Raises `ArgumentError` for an override with an unknown key, so that a
  typo shows.

  ## Examples

      iex> Koyomi.Messages.for_locale("pt-PT")["today"]
      "Hoje"
      iex> Koyomi.Messages.for_locale("sv")["today"]
      "Today"
      iex> Koyomi.Messages.for_locale("en", %{"today" => "Now"})["today"]
      "Now"

  """
  @spec for_locale(String.t(), map()) :: %{String.t() => String.t()}
  def for_locale(locale, overrides \\ %{}) when is_binary(locale) do
    language = language(locale)
    config = Application.get_env(:koyomi, :messages, %{})

    Translations.english()
    |> Map.merge(Map.get(Translations.all(), language, %{}))
    |> Map.merge(stringify(Map.get(config, language, %{})))
    |> Map.merge(stringify(Map.get(config, locale, %{})))
    |> Map.merge(check!(stringify(overrides || %{})))
  end

  @doc """
  The language of a locale: `"pt"` for `"pt-BR"`, `"zh"` for `"zh_Hant"`.

  ## Examples

      iex> Koyomi.Messages.language("pt-BR")
      "pt"

  """
  @spec language(String.t()) :: String.t()
  def language(locale) do
    locale |> String.split(["-", "_"], parts: 2) |> hd() |> String.downcase()
  end

  defp stringify(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp check!(overrides) do
    english = Translations.english()

    case Enum.reject(Map.keys(overrides), &Map.has_key?(english, &1)) do
      [] ->
        overrides

      unknown ->
        raise ArgumentError,
              "Koyomi.Messages: unknown message keys #{inspect(unknown)}; see Koyomi.Messages.keys/0"
    end
  end
end
