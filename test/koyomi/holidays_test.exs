defmodule Koyomi.HolidaysTest do
  use ExUnit.Case, async: true

  alias Koyomi.Holiday
  alias Koyomi.Holidays
  alias Koyomi.Holidays.Rules

  doctest Koyomi.Holidays
  doctest Koyomi.Holidays.Rules

  defmodule Closures do
    @behaviour Koyomi.Holidays.Provider

    @impl true
    def holidays(year) do
      [
        {Date.new!(year, 12, 24), "Fermeture", "Office closed"},
        {Date.new!(year + 1, 1, 2), "Ignorée", "Ignored, another year"}
      ]
    end

    @impl true
    def language, do: "fr"
  end

  defmodule NoLanguage do
    @behaviour Koyomi.Holidays.Provider

    @impl true
    def holidays(year), do: [{Date.new!(year, 8, 2), "Sommerfest", "Summer party"}]
  end

  defmodule Broken do
    @behaviour Koyomi.Holidays.Provider

    @impl true
    def holidays(_year), do: [{"2027-01-01", "x", "x"}]
  end

  defp days(source, year), do: for(h <- Holidays.list(source, year), do: {h.date, h.name})
  defp english(source, year), do: for(h <- Holidays.list(source, year), do: {h.date, h.english})

  describe "Rules" do
    test "easter/1" do
      assert Rules.easter(2019) == ~D[2019-04-21]
      assert Rules.easter(2024) == ~D[2024-03-31]
      assert Rules.easter(2025) == ~D[2025-04-20]
      assert Rules.easter(2026) == ~D[2026-04-05]
      assert Rules.easter(2027) == ~D[2027-03-28]
      assert Rules.easter(2038) == ~D[2038-04-25]
      assert Rules.easter(2285) == ~D[2285-03-22]
    end

    test "nth_weekday/4" do
      assert Rules.nth_weekday(2027, 11, 4, 4) == ~D[2027-11-25]
      assert Rules.nth_weekday(2027, 5, 1, 1) == ~D[2027-05-03]
      assert Rules.nth_weekday(2026, 6, 1, 1) == ~D[2026-06-01]
      assert Rules.nth_weekday(2026, 8, 1, :last) == ~D[2026-08-31]
      assert Rules.nth_weekday(2026, 10, 1, :last) == ~D[2026-10-26]
    end
  end

  describe "countries/0" do
    test "lists the codes, sorted" do
      countries = Holidays.countries()
      assert countries == Enum.sort(countries)

      for code <-
            ~w(US CA MX BR AR GB IE PT ES FR DE IT NL BE CH AT PL SE NO DK FI JP AU NZ IN ZA) do
        assert code in countries
      end
    end

    test "every country lists a sorted year of well-formed holidays" do
      for code <- Holidays.countries(), year <- [2000, 2025, 2026, 2027, 2050] do
        holidays = Holidays.list(code, year)
        assert holidays != []
        assert Enum.map(holidays, & &1.date) == Enum.sort(Enum.map(holidays, & &1.date), Date)

        for holiday <- holidays do
          assert %Holiday{country: ^code} = holiday
          assert holiday.date.year == year
          assert holiday.name != "" and holiday.english != ""
        end
      end
    end
  end

  describe "list/2" do
    test "accepts any case and a country module" do
      assert Holidays.list("pt", 2027) == Holidays.list("PT", 2027)
      assert Holidays.list(Koyomi.Holidays.PT, 2027) == Holidays.list("PT", 2027)
    end

    test "Portugal" do
      assert days("PT", 2027) == [
               {~D[2027-01-01], "Ano Novo"},
               {~D[2027-03-26], "Sexta-feira Santa"},
               {~D[2027-03-28], "Páscoa"},
               {~D[2027-04-25], "Dia da Liberdade"},
               {~D[2027-05-01], "Dia do Trabalhador"},
               {~D[2027-05-27], "Corpo de Deus"},
               {~D[2027-06-10], "Dia de Portugal, de Camões e das Comunidades Portuguesas"},
               {~D[2027-08-15], "Assunção de Nossa Senhora"},
               {~D[2027-10-05], "Implantação da República"},
               {~D[2027-11-01], "Dia de Todos os Santos"},
               {~D[2027-12-01], "Restauração da Independência"},
               {~D[2027-12-08], "Imaculada Conceição"},
               {~D[2027-12-25], "Natal"}
             ]

      for year <- 2016..2040 do
        corpo = Enum.find(Holidays.list("PT", year), &(&1.name == "Corpo de Deus"))
        assert corpo.date == Date.add(Rules.easter(year), 60)
        assert Date.day_of_week(corpo.date) == 4
      end

      assert {~D[2025-06-19], "Corpo de Deus"} in days("PT", 2025)
      refute Enum.any?(Holidays.list("PT", 2014), &(&1.name == "Corpo de Deus"))
    end

    test "United States, with observed days" do
      assert english("US", 2027) == [
               {~D[2027-01-01], "New Year's Day"},
               {~D[2027-01-18], "Birthday of Martin Luther King, Jr."},
               {~D[2027-02-15], "Washington's Birthday"},
               {~D[2027-05-31], "Memorial Day"},
               {~D[2027-06-18], "Juneteenth National Independence Day (observed)"},
               {~D[2027-06-19], "Juneteenth National Independence Day"},
               {~D[2027-07-04], "Independence Day"},
               {~D[2027-07-05], "Independence Day (observed)"},
               {~D[2027-09-06], "Labor Day"},
               {~D[2027-10-11], "Columbus Day"},
               {~D[2027-11-11], "Veterans Day"},
               {~D[2027-11-25], "Thanksgiving Day"},
               {~D[2027-12-24], "Christmas Day (observed)"},
               {~D[2027-12-25], "Christmas Day"},
               {~D[2027-12-31], "New Year's Day (observed)"}
             ]

      # 2028 starts on a Saturday: its observed day is in 2027's list.
      refute Enum.any?(Holidays.list("US", 2028), &(&1.date.year != 2028))
      refute Enum.any?(Holidays.list("US", 2020), &String.starts_with?(&1.name, "Juneteenth"))
    end

    test "England and Wales, with substitute days" do
      assert english("GB", 2027) == [
               {~D[2027-01-01], "New Year's Day"},
               {~D[2027-03-26], "Good Friday"},
               {~D[2027-03-29], "Easter Monday"},
               {~D[2027-05-03], "Early May bank holiday"},
               {~D[2027-05-31], "Spring bank holiday"},
               {~D[2027-08-30], "Summer bank holiday"},
               {~D[2027-12-25], "Christmas Day"},
               {~D[2027-12-26], "Boxing Day"},
               {~D[2027-12-27], "Christmas Day (substitute day)"},
               {~D[2027-12-28], "Boxing Day (substitute day)"}
             ]

      assert {~D[2026-05-04], "Early May bank holiday"} in english("GB", 2026)
      assert {~D[2025-05-05], "Early May bank holiday"} in english("GB", 2025)
      # Christmas on a Sunday: Boxing Day on the Monday, the substitute on the Tuesday.
      assert {~D[2022-12-27], "Christmas Day (substitute day)"} in english("GB", 2022)
      # New Year's Day on a Saturday.
      assert {~D[2022-01-03], "New Year's Day (substitute day)"} in english("GB", 2022)
    end

    test "Japan 2027, with a substitute holiday" do
      assert days("JP", 2027) == [
               {~D[2027-01-01], "元日"},
               {~D[2027-01-11], "成人の日"},
               {~D[2027-02-11], "建国記念の日"},
               {~D[2027-02-23], "天皇誕生日"},
               {~D[2027-03-21], "春分の日"},
               {~D[2027-03-22], "振替休日"},
               {~D[2027-04-29], "昭和の日"},
               {~D[2027-05-03], "憲法記念日"},
               {~D[2027-05-04], "みどりの日"},
               {~D[2027-05-05], "こどもの日"},
               {~D[2027-07-19], "海の日"},
               {~D[2027-08-11], "山の日"},
               {~D[2027-09-20], "敬老の日"},
               {~D[2027-09-23], "秋分の日"},
               {~D[2027-10-11], "スポーツの日"},
               {~D[2027-11-03], "文化の日"},
               {~D[2027-11-23], "勤労感謝の日"}
             ]
    end

    test "Japan 2026, with a substitute holiday and a citizens' holiday" do
      holidays = days("JP", 2026)
      assert {~D[2026-03-20], "春分の日"} in holidays
      assert {~D[2026-05-06], "振替休日"} in holidays
      assert {~D[2026-09-21], "敬老の日"} in holidays
      assert {~D[2026-09-22], "国民の休日"} in holidays
      assert {~D[2026-09-23], "秋分の日"} in holidays
      assert length(holidays) == 18
    end

    test "Japan 2025: a substitute holiday after two holidays in a row" do
      holidays = days("JP", 2025)
      assert {~D[2025-02-24], "振替休日"} in holidays
      assert {~D[2025-05-06], "振替休日"} in holidays
      assert {~D[2025-11-24], "振替休日"} in holidays
      assert {~D[2025-09-23], "秋分の日"} in holidays
      refute Enum.any?(holidays, &(elem(&1, 1) == "国民の休日"))
    end

    test "Japan's equinoxes" do
      equinoxes = fn year ->
        for {date, name} <- days("JP", year), name in ["春分の日", "秋分の日"], do: date
      end

      assert equinoxes.(2024) == [~D[2024-03-20], ~D[2024-09-22]]
      assert equinoxes.(2028) == [~D[2028-03-20], ~D[2028-09-22]]
      assert equinoxes.(2100) == []
    end

    test "Argentina's movable holidays" do
      assert {~D[2024-11-18], "Día de la Soberanía Nacional"} in days("AR", 2024)
      assert {~D[2024-10-12], "Día del Respeto a la Diversidad Cultural"} in days("AR", 2024)

      assert {~D[2025-06-16], "Paso a la Inmortalidad del General Martín Miguel de Güemes"} in days(
               "AR",
               2025
             )

      assert {~D[2025-11-24], "Día de la Soberanía Nacional"} in days("AR", 2025)
      assert {~D[2025-03-03], "Carnaval"} in days("AR", 2025)
      assert {~D[2025-03-04], "Carnaval"} in days("AR", 2025)
    end

    test "Mondayisation in New Zealand" do
      holidays = english("NZ", 2027)
      assert {~D[2027-01-04], "Day after New Year's Day (observed)"} in holidays
      assert {~D[2027-02-08], "Waitangi Day (observed)"} in holidays
      assert {~D[2027-04-26], "Anzac Day (observed)"} in holidays
      assert {~D[2027-06-25], "Matariki"} in holidays
      assert {~D[2027-10-25], "Labour Day"} in holidays
      assert {~D[2027-12-27], "Christmas Day (observed)"} in holidays
      assert {~D[2027-12-28], "Boxing Day (observed)"} in holidays

      # New Year's Day on a Sunday: the Monday is the day after it, so the Tuesday.
      assert {~D[2023-01-03], "New Year's Day (observed)"} in english("NZ", 2023)

      for year <- 2022..2052 do
        matariki = Enum.find(Holidays.list("NZ", year), &(&1.name == "Matariki"))
        assert Date.day_of_week(matariki.date) == 5
      end

      refute Enum.any?(Holidays.list("NZ", 2021), &(&1.name == "Matariki"))
    end

    test "Australia" do
      holidays = english("AU", 2027)
      assert {~D[2027-01-26], "Australia Day"} in holidays
      assert {~D[2027-12-28], "Boxing Day (observed)"} in holidays
      assert {~D[2025-01-27], "Australia Day (observed)"} in english("AU", 2025)
    end

    test "South Africa" do
      holidays = english("ZA", 2027)
      assert {~D[2027-03-22], "Human Rights Day (observed)"} in holidays
      assert {~D[2027-12-27], "Day of Goodwill (observed)"} in holidays
      # Christmas on a Sunday: the Monday is already the Day of Goodwill.
      assert english("ZA", 2022) |> Enum.filter(&(elem(&1, 0) == ~D[2022-12-26])) ==
               [{~D[2022-12-26], "Day of Goodwill"}]
    end

    test "other countries" do
      assert {~D[2027-12-25], "1. Weihnachtstag"} in days("DE", 2027)
      assert {~D[2027-05-06], "Christi Himmelfahrt"} in days("DE", 2027)
      assert {~D[2027-05-17], "Lundi de Pentecôte"} in days("FR", 2027)
      assert {~D[2027-11-25], "Thanksgiving Day"} in days("US", 2027)
      assert {~D[2027-05-24], "Victoria Day"} in days("CA", 2027)
      assert {~D[2026-05-18], "Victoria Day"} in days("CA", 2026)
      assert {~D[2018-07-02], "Canada Day (observed)"} in days("CA", 2018)
      assert {~D[2027-02-01], "Día de la Constitución"} in days("MX", 2027)
      assert {~D[2030-10-01], "Transmisión del Poder Ejecutivo Federal"} in days("MX", 2030)
      refute Enum.any?(days("MX", 2027), &(elem(&1, 0) == ~D[2027-10-01]))
      assert {~D[2026-02-02], "Saint Brigid's Day"} in days("IE", 2026)
      assert {~D[2030-02-01], "Saint Brigid's Day"} in days("IE", 2030)
      assert {~D[2025-04-26], "Koningsdag"} in days("NL", 2025)
      assert {~D[2027-04-27], "Koningsdag"} in days("NL", 2027)
      assert {~D[2026-06-20], "Midsommardagen"} in days("SE", 2026)
      assert {~D[2026-10-31], "Alla helgons dag"} in days("SE", 2026)
      assert {~D[2023-05-05], "Store bededag"} in days("DK", 2023)
      refute Enum.any?(days("DK", 2024), &(elem(&1, 1) == "Store bededag"))
      assert {~D[2026-10-04], "San Francesco d’Assisi"} in days("IT", 2026)
      assert {~D[2025-12-24], "Wigilia Bożego Narodzenia"} in days("PL", 2025)
      assert {~D[2024-11-20], "Dia Nacional de Zumbi e da Consciência Negra"} in days("BR", 2024)
      assert length(days("CH", 2027)) == 4
      assert length(days("IN", 2027)) == 3
    end
  end

  describe "between/2" do
    test "crosses a year boundary" do
      range = Date.range(~D[2027-12-20], ~D[2028-01-10])

      assert for(h <- Holidays.between("JP", range), do: {h.date, h.name}) == [
               {~D[2028-01-01], "元日"},
               {~D[2028-01-10], "成人の日"}
             ]

      assert for(h <- Holidays.between("US", range), do: h.date) == [
               ~D[2027-12-24],
               ~D[2027-12-25],
               ~D[2027-12-31],
               ~D[2028-01-01]
             ]
    end

    test "merges sources in date order, keeping their order on one day" do
      range = Date.range(~D[2027-04-20], ~D[2027-05-05])

      assert for(h <- Holidays.between(["PT", "IT"], range), do: {h.date, h.country}) == [
               {~D[2027-04-25], "PT"},
               {~D[2027-04-25], "IT"},
               {~D[2027-05-01], "PT"},
               {~D[2027-05-01], "IT"}
             ]
    end

    test "reads a provider module" do
      range = Date.range(~D[2027-12-20], ~D[2028-01-05])

      assert Holidays.between([Closures, "FR"], range) == [
               %Holiday{
                 date: ~D[2027-12-24],
                 name: "Fermeture",
                 english: "Office closed",
                 country: Closures
               },
               %Holiday{
                 date: ~D[2027-12-25],
                 name: "Noël",
                 english: "Christmas Day",
                 country: "FR"
               },
               %Holiday{
                 date: ~D[2028-01-01],
                 name: "Jour de l’an",
                 english: "New Year's Day",
                 country: "FR"
               }
             ]
    end

    test "a range in reverse, and an empty list of sources" do
      range = Date.range(~D[2027-12-31], ~D[2027-12-20], -1)

      assert [%Holiday{date: ~D[2027-12-25]}, %Holiday{date: ~D[2027-12-26]}] =
               Holidays.between("DE", range)

      assert Holidays.between([], range) == []
    end
  end

  describe "to_client/3" do
    @range Date.range(~D[2027-12-25], ~D[2028-01-01])

    test "uses the name for the country's language, English otherwise" do
      assert Holidays.to_client("PT", @range, "pt-PT") == %{
               "2027-12-25" => "Natal",
               "2028-01-01" => "Ano Novo"
             }

      assert Holidays.to_client("PT", @range, "pt_BR")["2027-12-25"] == "Natal"
      assert Holidays.to_client("PT", @range, "en-GB")["2027-12-25"] == "Christmas Day"
      assert Holidays.to_client("JP", @range, "ja")["2028-01-01"] == "元日"
      assert Holidays.to_client("JP", @range, "fr-FR")["2028-01-01"] == "New Year's Day"
      assert Holidays.to_client("NO", @range, "nn-NO")["2027-12-25"] == "Første juledag"
    end

    test "joins the holidays of one day" do
      client = Holidays.to_client(["PT", "DE", "GB"], @range, "de-AT")
      assert client["2027-12-25"] == "Christmas Day · 1. Weihnachtstag"
      assert client["2027-12-26"] == "2. Weihnachtstag · Boxing Day"
      assert client["2027-12-27"] == "Christmas Day (substitute day)"
      assert client["2028-01-01"] == "New Year's Day · Neujahr"
    end

    test "reads providers, with or without a language" do
      range = Date.range(~D[2027-08-01], ~D[2027-12-31])

      assert Holidays.to_client([Closures, NoLanguage], range, "en") == %{
               "2027-08-02" => "Sommerfest",
               "2027-12-24" => "Office closed"
             }

      assert Holidays.to_client(Closures, range, "fr-CA") == %{"2027-12-24" => "Fermeture"}
    end
  end

  describe "errors" do
    test "an unknown country code" do
      error = assert_raise ArgumentError, fn -> Holidays.list("XX", 2027) end
      assert error.message =~ ~s(unknown country "XX")
      assert error.message =~ "AR, AT, AU"
      assert error.message =~ "Koyomi.Holidays.Provider"
    end

    test "a module that is not a provider, and other values" do
      assert_raise ArgumentError, ~r/String is not a Koyomi.Holidays.Provider/, fn ->
        Holidays.between(String, Date.range(~D[2027-01-01], ~D[2027-01-31]))
      end

      assert_raise ArgumentError, ~r/invalid holiday source 42/, fn ->
        Holidays.list(42, 2027)
      end
    end

    test "a provider that returns entries of another shape" do
      assert_raise ArgumentError, ~r/Broken.holidays\(2027\) returned/, fn ->
        Holidays.list(Broken, 2027)
      end
    end
  end
end
