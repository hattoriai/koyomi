defmodule Koyomi.Holiday do
  @moduledoc """
  A public holiday on one day, as `Koyomi.Holidays` lists it.

    * `:date` - the day, a `Date`.
    * `:name` - the name in the main language of the country, for example
      "Natal" in Portugal or "元日" in Japan.
    * `:english` - the name in English.
    * `:country` - the country code ("PT"), or the provider module of a
      provider that has no `country/0` callback.
  """

  @enforce_keys [:date, :name, :english, :country]
  defstruct [:date, :name, :english, :country]

  @type t :: %__MODULE__{
          date: Date.t(),
          name: String.t(),
          english: String.t(),
          country: String.t() | module()
        }
end
