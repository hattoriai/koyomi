defmodule Koyomi.Recurrence.Describe do
  @moduledoc false

  # The sentences of `Koyomi.Recurrence.describe/3`, word for word the
  # same as `describeRule` in `rrule.ts`: a change here is a change there,
  # and test/fixtures/recurrence.json holds both to it.
  #
  # A sentence is the frequency, the days, the months, a condition, the
  # positions and the end, each written by the language's own clauses.
  # The day phrases carry their own article and preposition where the
  # language needs one per day (pt "à segunda-feira", de "am Montag");
  # English and Dutch put one "on"/"op" before the list.

  @languages ~w(en pt es fr de it nl ja)

  @weekdays %{
    "en" => ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday),
    "pt" => ~w(segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado domingo),
    "es" => ~w(lunes martes miércoles jueves viernes sábado domingo),
    "fr" => ~w(lundi mardi mercredi jeudi vendredi samedi dimanche),
    "de" => ~w(Montag Dienstag Mittwoch Donnerstag Freitag Samstag Sonntag),
    "it" => ~w(lunedì martedì mercoledì giovedì venerdì sabato domenica),
    "nl" => ~w(maandag dinsdag woensdag donderdag vrijdag zaterdag zondag),
    "ja" => ~w(月曜日 火曜日 水曜日 木曜日 金曜日 土曜日 日曜日)
  }

  @months %{
    "en" =>
      ~w(January February March April May June July August September October November December),
    "pt" =>
      ~w(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro),
    "es" =>
      ~w(enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre),
    "fr" =>
      ~w(janvier février mars avril mai juin juillet août septembre octobre novembre décembre),
    "de" =>
      ~w(Januar Februar März April Mai Juni Juli August September Oktober November Dezember),
    "it" =>
      ~w(gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre dicembre),
    "nl" =>
      ~w(januari februari maart april mei juni juli augustus september oktober november december),
    "ja" => ~w(1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月)
  }

  @conjunctions %{
    "en" => {"and", "or"},
    "pt" => {"e", "ou"},
    "es" => {"y", "o"},
    "fr" => {"et", "ou"},
    "de" => {"und", "oder"},
    "it" => {"e", "o"},
    "nl" => {"en", "of"},
    "ja" => {"と", "か"}
  }

  @spec language(String.t()) :: String.t()
  def language(locale) when is_binary(locale) do
    language = locale |> String.downcase() |> String.split(["-", "_"]) |> hd()
    if language in @languages, do: language, else: "en"
  end

  def language(_locale), do: "en"

  @spec sentence(Koyomi.Recurrence.t(), String.t(), Date.t() | nil) :: String.t()
  def sentence(rule, lang, start) do
    rule = with_start(rule, start)
    shape = shape(rule)
    {days, months} = days_and_months(lang, rule, shape)

    parts = %{
      freq: freq(lang, rule.freq, rule.interval),
      interval: rule.interval,
      daily?: rule.freq == :daily,
      days: days_text(lang, days),
      months: month_names(lang, months),
      of_year: of_year?(rule, shape.ordinals?),
      of_month: of_month?(rule),
      limit: limit_text(lang, rule),
      positions: positions_text(lang, rule, shape.noun_positions?),
      ending: ending(lang, rule)
    }

    assemble(lang, parts)
  end

  # What the rule's days are: with ordinals, Monday to Friday, positions
  # among those (or among every day) named by a noun, or one date a year.
  defp shape(rule) do
    plain = for {nil, day} <- rule.by_day, do: day
    ordinals? = Enum.any?(rule.by_day, &(elem(&1, 0) != nil))
    weekdays? = not ordinals? and plain == [1, 2, 3, 4, 5]
    every_day? = not ordinals? and plain == [1, 2, 3, 4, 5, 6, 7]

    %{
      ordinals?: ordinals?,
      weekdays?: weekdays?,
      noun_positions?: noun_positions?(rule, weekdays? or every_day?),
      date?: date?(rule)
    }
  end

  defp noun_positions?(%{by_set_pos: [_ | _], by_month_day: []}, all_days?), do: all_days?
  defp noun_positions?(_rule, _all_days?), do: false

  defp date?(%{freq: :yearly, by_month: [_], by_day: [], by_month_day: [day]}), do: day > 0
  defp date?(_rule), do: false

  # The days, as a date, a phrase or a list, and the months to name.
  defp days_and_months(lang, rule, shape) do
    cond do
      shape.date? ->
        {{:date, date(lang, hd(rule.by_month), hd(rule.by_month_day))}, nil}

      rule.by_month_day != [] ->
        {{:list, Enum.map(rule.by_month_day, &month_day(lang, &1))}, rule.by_month}

      shape.noun_positions? ->
        noun = if shape.weekdays?, do: :weekday, else: :day
        {{:list, Enum.map(rule.by_set_pos, &nth(lang, &1, noun, :on))}, rule.by_month}

      shape.weekdays? ->
        {{:phrase, weekdays(lang)}, rule.by_month}

      rule.by_day != [] ->
        {{:list, Enum.map(rule.by_day, &day(lang, &1, :on))}, rule.by_month}

      true ->
        {nil, rule.by_month}
    end
  end

  defp month_names(_lang, months) when months in [nil, []], do: nil
  defp month_names(lang, months), do: Enum.map(months, &Enum.at(@months[lang], &1 - 1))

  defp of_year?(%{freq: :yearly, by_month: [], by_month_day: []}, ordinals?), do: ordinals?
  defp of_year?(_rule, _ordinals?), do: false

  defp of_month?(%{freq: :yearly, by_month: [], by_month_day: [_ | _]}), do: true
  defp of_month?(_rule), do: false

  # BYDAY with BYMONTHDAY: a condition on the days.
  defp limit_text(lang, %{by_month_day: [_ | _], by_day: [_ | _] = by_day}),
    do: limit(lang, join(lang, Enum.map(by_day, &day(lang, &1, :subject)), :or))

  defp limit_text(_lang, _rule), do: nil

  defp positions_text(_lang, %{by_set_pos: []}, _noun_positions?), do: nil
  defp positions_text(_lang, _rule, true), do: nil
  defp positions_text(lang, rule, false), do: positions(lang, rule.by_set_pos, rule.freq)

  defp with_start(rule, nil), do: rule

  defp with_start(rule, start) do
    case rule do
      %{freq: :weekly, by_day: []} ->
        %{rule | by_day: [{nil, Date.day_of_week(start)}]}

      %{freq: :monthly, by_day: [], by_month_day: []} ->
        %{rule | by_month_day: [start.day]}

      %{freq: :yearly, by_day: [], by_month_day: [], by_month: []} ->
        %{rule | by_month_day: [start.day], by_month: [start.month]}

      %{freq: :yearly, by_day: [], by_month_day: []} ->
        %{rule | by_month_day: [start.day]}

      _rule ->
        rule
    end
  end

  defp days_text(_lang, nil), do: nil
  defp days_text(_lang, {:date, text}), do: text
  defp days_text(_lang, {:phrase, text}), do: text
  defp days_text(lang, {:list, items}), do: on(lang) <> join(lang, items, :and)

  defp assemble("ja", parts) do
    months = parts.months && join("ja", parts.months, :and)
    details = details_ja(parts, months)

    head_ja(parts, details, months) <>
      (parts.limit || "") <> (parts.positions || "") <> parts.ending
  end

  defp assemble(lang, parts) do
    parts.freq <>
      if(parts.days, do: " " <> parts.days, else: "") <>
      if(parts.of_year, do: of_year(lang), else: "") <>
      if(parts.of_month, do: of_month(lang), else: "") <>
      if(parts.months, do: " " <> months(lang, parts.months), else: "") <>
      (parts.limit || "") <> (parts.positions || "") <> parts.ending
  end

  defp details_ja(%{days: nil}, _months), do: nil
  defp details_ja(%{days: days}, months) when is_binary(months), do: months <> "の" <> days
  defp details_ja(%{days: days, of_month: true}, _months), do: "各月の" <> days
  defp details_ja(%{days: days}, _months), do: days

  defp head_ja(%{freq: freq}, nil, nil), do: freq
  defp head_ja(%{freq: freq}, nil, months), do: freq <> "（" <> months <> "）"
  defp head_ja(%{freq: freq, daily?: true}, details, _months), do: freq <> "（" <> details <> "）"

  defp head_ja(%{freq: freq, interval: n}, details, _months) when n > 1,
    do: freq <> "の" <> details

  defp head_ja(%{freq: freq}, details, _months), do: freq <> details

  defp join(lang, items, kind) do
    {conj_and, conj_or} = @conjunctions[lang]
    conj = if kind == :and, do: conj_and, else: conj_or

    case {lang, items} do
      {_lang, [one]} -> one
      {"ja", _items} -> Enum.join(Enum.drop(items, -1), "、") <> conj <> List.last(items)
      _ -> Enum.join(Enum.drop(items, -1), ", ") <> " " <> conj <> " " <> List.last(items)
    end
  end

  defp on("en"), do: "on "
  defp on("nl"), do: "op "
  defp on(_lang), do: ""

  # Frequencies.

  defp freq(lang, freq, 1) do
    index = Enum.find_index([:daily, :weekly, :monthly, :yearly], &(&1 == freq))

    Enum.at(
      %{
        "en" => ["Daily", "Weekly", "Monthly", "Every year"],
        "pt" => ["Todos os dias", "Todas as semanas", "Todos os meses", "Todos os anos"],
        "es" => ["Todos los días", "Todas las semanas", "Todos los meses", "Todos los años"],
        "fr" => ["Tous les jours", "Toutes les semaines", "Tous les mois", "Tous les ans"],
        "de" => ["Täglich", "Wöchentlich", "Monatlich", "Jährlich"],
        "it" => ["Ogni giorno", "Ogni settimana", "Ogni mese", "Ogni anno"],
        "nl" => ["Dagelijks", "Wekelijks", "Maandelijks", "Jaarlijks"],
        "ja" => ["毎日", "毎週", "毎月", "毎年"]
      }[lang],
      index
    )
  end

  defp freq(lang, freq, n) do
    index = Enum.find_index([:daily, :weekly, :monthly, :yearly], &(&1 == freq))

    case lang do
      "en" ->
        "Every #{n} " <> Enum.at(~w(days weeks months years), index)

      "pt" ->
        "A cada #{n} " <> Enum.at(~w(dias semanas meses anos), index)

      "es" ->
        "Cada #{n} " <> Enum.at(~w(días semanas meses años), index)

      "fr" ->
        Enum.at(
          [
            "Tous les #{n} jours",
            "Toutes les #{n} semaines",
            "Tous les #{n} mois",
            "Tous les #{n} ans"
          ],
          index
        )

      "de" ->
        "Alle #{n} " <> Enum.at(~w(Tage Wochen Monate Jahre), index)

      "it" ->
        "Ogni #{n} " <> Enum.at(~w(giorni settimane mesi anni), index)

      "nl" ->
        "Om de #{n} " <> Enum.at(~w(dagen weken maanden jaar), index)

      "ja" ->
        "#{n}" <> Enum.at(~w(日ごと 週間ごと か月ごと 年ごと), index)
    end
  end

  # Ordinals: the word before the noun and what follows the noun, for a
  # gender (:m or :f) and a grammatical context (:on after "on", :subject
  # as the subject of "it is", which only German tells apart).

  defp ordinal("en", n, _gender, _context) do
    words = ~w(first second third fourth fifth)

    cond do
      n in 1..5 -> {Enum.at(words, n - 1), ""}
      n > 0 -> {numeral_en(n), ""}
      n == -1 -> {"last", ""}
      -n in 2..5 -> {Enum.at(words, -n - 1) <> " to last", ""}
      true -> {numeral_en(-n) <> " to last", ""}
    end
  end

  defp ordinal("pt", n, gender, _context) do
    words = ~w(primeir segund terceir quart quint)
    o = if gender == :f, do: "a", else: "o"

    cond do
      n in 1..5 -> {Enum.at(words, n - 1) <> o, ""}
      n > 0 -> {"#{n}.#{if gender == :f, do: "ª", else: "º"}", ""}
      n == -1 -> {"últim" <> o, ""}
      n == -2 -> {"penúltim" <> o, ""}
      true -> {elem(ordinal("pt", -n, gender, :on), 0), " a contar do fim"}
    end
  end

  defp ordinal("es", n, gender, _context) do
    words =
      if gender == :f,
        do: ~w(primera segunda tercera cuarta quinta),
        else: ~w(primer segundo tercer cuarto quinto)

    o = if gender == :f, do: "a", else: "o"

    cond do
      n in 1..5 -> {Enum.at(words, n - 1), ""}
      n > 0 -> {"#{n}.#{if gender == :f, do: "ª", else: "º"}", ""}
      n == -1 -> {"últim" <> o, ""}
      n == -2 -> {"penúltim" <> o, ""}
      true -> {elem(ordinal("es", -n, gender, :on), 0), " desde el final"}
    end
  end

  defp ordinal("fr", n, gender, _context) do
    first = if gender == :f, do: "première", else: "premier"
    last = if gender == :f, do: "dernière", else: "dernier"

    cond do
      n == 1 -> {first, ""}
      n in 2..5 -> {Enum.at(~w(deuxième troisième quatrième cinquième), n - 2), ""}
      n > 0 -> {"#{n}e", ""}
      n == -1 -> {last, ""}
      n == -2 -> {"avant-" <> last, ""}
      true -> {elem(ordinal("fr", -n, gender, :on), 0), " en partant de la fin"}
    end
  end

  defp ordinal("de", n, _gender, context) do
    e = if context == :on, do: "en", else: "e"

    cond do
      n in 1..5 -> {Enum.at(~w(erst zweit dritt viert fünft), n - 1) <> e, ""}
      n > 0 -> {"#{n}.", ""}
      n == -1 -> {"letzt" <> e, ""}
      n == -2 -> {"vorletzt" <> e, ""}
      -n in 3..5 -> {Enum.at(~w(dritt viert fünft), -n - 3) <> "letzt" <> e, ""}
      true -> {"#{-n}.-letzt" <> e, ""}
    end
  end

  defp ordinal("it", n, gender, _context) do
    o = if gender == :f, do: "a", else: "o"

    cond do
      n in 1..5 -> {Enum.at(~w(prim second terz quart quint), n - 1) <> o, ""}
      n > 0 -> {"#{n}#{if gender == :f, do: "ª", else: "º"}", ""}
      n == -1 -> {"ultim" <> o, ""}
      n == -2 -> {"penultim" <> o, ""}
      true -> {elem(ordinal("it", -n, gender, :on), 0), " dalla fine"}
    end
  end

  defp ordinal("nl", n, _gender, _context) do
    cond do
      n in 1..5 -> {Enum.at(~w(eerste tweede derde vierde vijfde), n - 1), ""}
      n > 0 -> {"#{n}e", ""}
      n == -1 -> {"laatste", ""}
      n == -2 -> {"voorlaatste", ""}
      true -> {elem(ordinal("nl", -n, :m, :on), 0), " van achteren"}
    end
  end

  defp numeral_en(n) do
    suffix =
      cond do
        rem(n, 100) in 11..13 -> "th"
        rem(n, 10) == 1 -> "st"
        rem(n, 10) == 2 -> "nd"
        rem(n, 10) == 3 -> "rd"
        true -> "th"
      end

    "#{n}#{suffix}"
  end

  # An article (and preposition) before an ordinal.
  defp article("en", _gender, _context, _word), do: "the "
  defp article("pt", :f, :on, _word), do: "na "
  defp article("pt", :m, :on, _word), do: "no "
  defp article("pt", :f, _context, _word), do: "a "
  defp article("pt", :m, _context, _word), do: "o "
  defp article("es", :f, _context, _word), do: "la "
  defp article("es", :m, _context, _word), do: "el "

  defp article("fr", gender, _context, word),
    do: if(word =~ ~r/^[aeiouéè]/u, do: "l'", else: if(gender == :f, do: "la ", else: "le "))

  defp article("de", _gender, :on, _word), do: "am "
  defp article("de", _gender, _context, _word), do: "der "

  defp article("it", gender, _context, word),
    do:
      if(word =~ ~r/^([aeiou]|8|11\D)/u, do: "l'", else: if(gender == :f, do: "la ", else: "il "))

  defp article("nl", _gender, _context, _word), do: "de "

  # "The first Monday", or a noun: the day, a weekday (Monday to Friday).
  defp nth("ja", n, noun, _context) do
    case noun do
      day when is_integer(day) ->
        name = Enum.at(@weekdays["ja"], day - 1)

        cond do
          n > 0 -> "第#{n}" <> name
          n == -1 -> "最終" <> name
          true -> "最後から#{-n}番目の" <> name
        end

      noun ->
        position_ja(n) <> "の" <> if(noun == :weekday, do: "平日", else: "日")
    end
  end

  defp nth(lang, n, noun, context) do
    {name, gender} = noun(lang, noun)
    {word, tail} = ordinal(lang, n, gender, context)
    article(lang, gender, context, word) <> word <> " " <> name <> tail
  end

  defp noun(lang, day) when is_integer(day),
    do: {Enum.at(@weekdays[lang], day - 1), gender(lang, day)}

  defp noun(lang, :weekday) do
    {%{
       "en" => "weekday",
       "pt" => "dia útil",
       "es" => "día laborable",
       "fr" => "jour ouvré",
       "de" => "Arbeitstag",
       "it" => "giorno lavorativo",
       "nl" => "werkdag"
     }[lang], :m}
  end

  defp noun(lang, :day) do
    {%{
       "en" => "day",
       "pt" => "dia",
       "es" => "día",
       "fr" => "jour",
       "de" => "Tag",
       "it" => "giorno",
       "nl" => "dag"
     }[
       lang
     ], :m}
  end

  defp gender("pt", day) when day <= 5, do: :f
  defp gender("it", 7), do: :f
  defp gender(_lang, _day), do: :m

  defp position_ja(1), do: "最初"
  defp position_ja(-1), do: "最後"
  defp position_ja(n) when n > 0, do: "#{n}番目"
  defp position_ja(n), do: "最後から#{-n}番目"

  # A weekday of BYDAY, after "on" or as the subject of "it is".
  defp day(lang, {nil, day}, context) do
    day_article(lang, context, gender(lang, day)) <> Enum.at(@weekdays[lang], day - 1)
  end

  defp day(lang, {n, day}, context), do: nth(lang, n, day, context)

  # The article (and preposition) before a weekday of BYDAY.
  defp day_article("en", :on, _gender), do: ""
  defp day_article("en", _context, _gender), do: "a "
  defp day_article("pt", :on, :f), do: "à "
  defp day_article("pt", :on, _gender), do: "ao "
  defp day_article("pt", _context, :f), do: "uma "
  defp day_article("pt", _context, _gender), do: "um "
  defp day_article("es", :on, _gender), do: "el "
  defp day_article("es", _context, _gender), do: ""
  defp day_article("fr", :on, _gender), do: "le "
  defp day_article("fr", _context, _gender), do: "un "
  defp day_article("de", :on, _gender), do: "am "
  defp day_article("de", _context, _gender), do: "ein "
  defp day_article("it", :on, :f), do: "la "
  defp day_article("it", :on, _gender), do: "il "
  defp day_article("it", _context, :f), do: "una "
  defp day_article("it", _context, _gender), do: "un "
  defp day_article("nl", :on, _gender), do: ""
  defp day_article("nl", _context, _gender), do: "een "
  defp day_article("ja", _context, _gender), do: ""

  defp month_day("ja", -1), do: "末日"
  defp month_day("ja", n) when n > 0, do: "#{n}日"
  defp month_day("en", n) when n > 0, do: "the " <> numeral_en(n)
  defp month_day("pt", n) when n > 0, do: "no dia #{n}"
  defp month_day("es", n) when n > 0, do: "el día #{n}"
  defp month_day("fr", 1), do: "le 1er"
  defp month_day("fr", n) when n > 0, do: "le #{n}"
  defp month_day("de", n) when n > 0, do: "am #{n}."
  defp month_day("it", n) when n > 0, do: "il giorno #{n}"
  defp month_day("nl", n) when n > 0, do: "de #{n}e"
  defp month_day(lang, n), do: nth(lang, n, :day, :on)

  defp weekdays(lang) do
    %{
      "en" => "on weekdays",
      "pt" => "de segunda a sexta-feira",
      "es" => "de lunes a viernes",
      "fr" => "du lundi au vendredi",
      "de" => "von Montag bis Freitag",
      "it" => "dal lunedì al venerdì",
      "nl" => "op werkdagen",
      "ja" => "平日"
    }[lang]
  end

  # A day and month, without the year, after the frequency.
  defp date(lang, month, day) do
    name = Enum.at(@months[lang], month - 1)

    case lang do
      "en" -> "on #{day} #{name}"
      "pt" -> "a #{day} de #{name}"
      "es" -> "el #{day} de #{name}"
      "fr" -> "le #{day_fr(day)} #{name}"
      "de" -> "am #{day}. #{name}"
      "it" -> day_it(day, "il ", "l'") <> " " <> name
      "nl" -> "op #{day} #{name}"
      "ja" -> "#{name}#{day}日"
    end
  end

  defp day_fr(1), do: "1er"
  defp day_fr(day), do: "#{day}"

  defp day_it(1, article, _elided), do: article <> "1º"
  defp day_it(day, _article, elided) when day in [8, 11], do: "#{elided}#{day}"
  defp day_it(day, article, _elided), do: "#{article}#{day}"

  defp months(lang, names) do
    list = join(lang, names, :and)

    case lang do
      "en" -> "in " <> list
      "pt" -> "em " <> list
      "es" -> "en " <> list
      "fr" -> "en " <> list
      "de" -> "im " <> list
      "it" -> if(String.starts_with?(list, "a"), do: "ad ", else: "a ") <> list
      "nl" -> "in " <> list
    end
  end

  defp of_year(lang) do
    %{
      "en" => " of the year",
      "pt" => " do ano",
      "es" => " del año",
      "fr" => " de l'année",
      "de" => " des Jahres",
      "it" => " dell'anno",
      "nl" => " van het jaar"
    }[lang]
  end

  defp of_month(lang) do
    %{
      "en" => " of every month",
      "pt" => " de cada mês",
      "es" => " de cada mes",
      "fr" => " de chaque mois",
      "de" => " jedes Monats",
      "it" => " di ogni mese",
      "nl" => " van elke maand"
    }[lang]
  end

  defp limit(lang, text) do
    case lang do
      "en" -> ", if it is " <> text
      "pt" -> ", se for " <> text
      "es" -> ", si es " <> text
      "fr" -> ", si c'est " <> text
      "de" -> ", wenn es " <> text <> " ist"
      "it" -> ", se è " <> text
      "nl" -> ", als het " <> text <> " is"
      "ja" -> "（" <> text <> "の場合）"
    end
  end

  # BYSETPOS other than "the last weekday": the positions in each period.
  defp positions("ja", list, freq) do
    period = Enum.at(~w(日 週 月 年), period_index(freq))
    "（各#{period}の" <> join("ja", Enum.map(list, &position_ja/1), :and) <> "）"
  end

  defp positions(lang, list, freq) do
    items =
      Enum.map(list, fn n ->
        {word, tail} = ordinal(lang, n, :f, :subject)
        article(lang, :f, :subject, word) <> word <> tail
      end)

    text = join(lang, items, :and)
    index = period_index(freq)

    case lang do
      "en" ->
        " (#{text} of each #{Enum.at(~w(day week month year), index)})"

      "pt" ->
        " (#{text} de cada #{Enum.at(~w(dia semana mês ano), index)})"

      "es" ->
        " (#{text} de cada #{Enum.at(~w(día semana mes año), index)})"

      "fr" ->
        " (#{text} de chaque #{Enum.at(~w(jour semaine mois année), index)})"

      "de" ->
        " (jeweils #{text} Termin #{Enum.at(["am Tag", "in der Woche", "im Monat", "im Jahr"], index)})"

      "it" ->
        " (#{text} di ogni #{Enum.at(~w(giorno settimana mese anno), index)})"

      "nl" ->
        " (#{text} van #{Enum.at(["elke dag", "elke week", "elke maand", "elk jaar"], index)})"
    end
  end

  defp period_index(freq),
    do: Enum.find_index([:daily, :weekly, :monthly, :yearly], &(&1 == freq))

  defp ending(lang, %{count: count}) when is_integer(count), do: times(lang, count)

  defp ending(lang, %{until: until}) when not is_nil(until) do
    date = until_date(until)
    until_text(lang, date.day, Enum.at(@months[lang], date.month - 1), date.year)
  end

  defp ending(_lang, _rule), do: ""

  defp times("en", 1), do: ", once"
  defp times("en", n), do: ", #{n} times"
  defp times("pt", 1), do: ", uma vez"
  defp times("pt", n), do: ", #{n} vezes"
  defp times("es", 1), do: ", una vez"
  defp times("es", n), do: ", #{n} veces"
  defp times("fr", 1), do: ", une fois"
  defp times("fr", n), do: ", #{n} fois"
  defp times("de", 1), do: ", einmal"
  defp times("de", n), do: ", #{n}-mal"
  defp times("it", 1), do: ", una volta"
  defp times("it", n), do: ", #{n} volte"
  defp times("nl", 1), do: ", één keer"
  defp times("nl", n), do: ", #{n} keer"
  defp times("ja", n), do: "、#{n}回"

  defp until_date(%DateTime{} = until), do: DateTime.to_date(until)
  defp until_date(until), do: until

  defp until_text("en", d, name, y), do: " until #{d} #{name} #{y}"
  defp until_text("pt", d, name, y), do: " até #{d} de #{name} de #{y}"
  defp until_text("es", d, name, y), do: " hasta el #{d} de #{name} de #{y}"
  defp until_text("fr", d, name, y), do: " jusqu'au #{day_fr(d)} #{name} #{y}"
  defp until_text("de", d, name, y), do: " bis zum #{d}. #{name} #{y}"
  defp until_text("it", d, name, y), do: " fino " <> day_it(d, "al ", "all'") <> " #{name} #{y}"
  defp until_text("nl", d, name, y), do: " tot en met #{d} #{name} #{y}"
  defp until_text("ja", d, name, y), do: "、#{y}年#{name}#{d}日まで"
end
