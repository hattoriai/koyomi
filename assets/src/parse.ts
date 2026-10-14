// Plain-words date entry: "next fri", "in 3 weeks", "15 mar", "tomorrow
// 9am", "15–20 mar". A pure function from text to a preview of what the
// picker would choose, in the ISO calendar of ./iso (no JavaScript Date
// takes part in the arithmetic; Intl is only asked for names and for the
// order of numeric dates).
//
// How a text is read
//
// 1. It is normalized: lower case, accents stripped ("março" is "marco"),
//    full-width forms folded, and cut into tokens. Digits and letters part
//    ("15th" is "15 th", "9am" is "9 am", "21h30" is "21 h 30"), each
//    Chinese or Japanese character is a token of its own ("来週" is
//    "来 週"), a dot after a word or before a non-digit is dropped
//    ("mar.", "15. März"), an ordinal suffix glued to a number is dropped
//    ("15th", "1er"), and a hyphen with spaces around it or a dash (– —)
//    becomes the range dash "–". Every word table below goes through the
//    same normalization, so tables are written in their natural spelling.
//
// 2. The locale's language tables are tried first, then English, which is
//    always accepted. Month and weekday names come from Intl for the
//    locale and for English in both passes; numeric dates follow the
//    locale's order (en-US M/D/Y, en-GB D/M/Y, ja Y/M/D) unless the first
//    number has four digits, which makes it Y/M/D.
//
// 3. Within a pass, the first reading that succeeds wins, in this order:
//    a. the whole text as one date phrase (see `phrase` for its order);
//    b. a date phrase and a time, either way round ("tomorrow 9am",
//       "fri at 14:30", "9am tomorrow"), or a time alone (datetime mode);
//    c. in range mode only, an explicit range ("15–20 mar", "from X to Y").
//    So "3-4" in en-US is the date 4 March, not the 3rd to the 4th.
//
// Resolution
//
// - A date without a year ("15 mar"), a month ("march"), a quarter
//   ("Q2"), a day of the month ("the 15th") or a weekday ("friday") is
//   resolved by `direction`: "future" takes the first one ending on or
//   after today (today and the current month count), "past" the last one
//   starting on or before today, "nearest" the closest (ties go to the
//   future).
// - "this/next/last friday" is the Friday of this, next or last week, the
//   week starting on `firstDay`. "this/next/last week/month/quarter/year"
//   likewise. "this/next/last march" is March of this, next or last year.
// - "weekend" and "this weekend" are the coming Saturday and Sunday, or
//   the current ones on a Saturday or Sunday.
// - "next 7 days" is today and the six after; "last 30 days" is today and
//   the 29 before.
// - In a range, the end is resolved from the start: "dec 20 – jan 5" ends
//   in the next year, "mon to fri" ends on the Friday after that Monday.
//   When one side lends the other its month ("15–20 mar", "mar 15–20"),
//   both are in the same month and year, so "15–2 mar" is null. A range
//   that ends before it starts is null.
//
// Modes
//
// - range: a period ("next week", "march", "Q2", "2027", "last 30 days",
//   "this weekend") or an explicit range gives `range`; one day gives
//   `date`, which the picker takes as the range's start.
// - date, dates, month, week, year: one day; a period gives its first day
//   ("next week" is its first day, "next month" the 1st), which is inside
//   the period for the month, week and year pickers to snap to. Explicit
//   ranges are not read. A time typed with the date is dropped.
// - datetime: a date and a time give `datetime`; a date alone gives
//   `date` (the picker keeps its time); a time alone is today at that
//   time; "in 2 hours", "30 minutes ago" and "now" count from `now`,
//   crossing midnight.
// - time: only a time ("9am", "21h30", "noon", "in 2 hours", "now").

import {
  addMonths,
  daysInMonth,
  endOfMonth,
  endOfQuarter,
  fromISOWeek,
  fromYMD,
  isoWeek,
  isoWeeksInYear,
  isValidYMD,
  startOfMonth,
  startOfQuarter,
  startOfWeek,
  timeOf,
  toYMD,
  weekday,
  type Day,
  type Seconds,
} from "./iso";

export type ParseMode = "date" | "range" | "dates" | "month" | "year" | "week" | "time" | "datetime";

export interface ParseOptions {
  /** BCP 47, e.g. "en-GB", "pt-PT", "ja". */
  locale: string;
  /** The reference day. */
  today: Day;
  /** The reference time of day, for "in 2 hours" (default 0). */
  now?: Seconds;
  mode: ParseMode;
  /** ISO first day of the week, for "this week" and "next friday" (default 1). */
  firstDay?: number;
  /** How a date without a year, a month or a weekday is resolved (default "future"). */
  direction?: "future" | "past" | "nearest";
}

export type ParseResult =
  | { kind: "date"; day: Day }
  | { kind: "range"; from: Day; to: Day }
  | { kind: "datetime"; day: Day; time: Seconds }
  | { kind: "time"; time: Seconds };

type Direction = "future" | "past" | "nearest";
type Unit = "minute" | "hour" | "day" | "week" | "month" | "quarter" | "year";

/** The words of one language. Templates hold slots: {n} a number, {u} a unit, {x} a weekday, unit, weekend or month, {p} a period, {a} and {b} the ends of a range. */
interface Words {
  today: string[];
  tomorrow: string[];
  yesterday: string[];
  afterTomorrow: string[];
  beforeYesterday: string[];
  now: string[];
  weekend: string[];
  units: { [K in Unit]?: string[] };
  /** Number words, 1 to 12 (and "a", "um", "ein"…). */
  numbers: Record<string, number>;
  /** "in {n} {u}" */
  later: string[];
  /** "{n} {u} ago" */
  ago: string[];
  /** "next {n} {u}": a period starting today. */
  nextN: string[];
  /** "last {n} {u}": a period ending today. */
  lastN: string[];
  next: string[];
  last: string[];
  this: string[];
  startOf: string[];
  endOf: string[];
  weekNumber: string[];
  ranges: string[];
  /** Words between a date and its time ("at", "às"). */
  at: string[];
  /** Words before a date that follows a time ("on"). */
  on: string[];
  noon: string[];
  midnight: string[];
  am: string[];
  pm: string[];
  /** Words ignored in a written date ("of", "de", "le"). Single words. */
  fillers: string[];
  /** Words before a month or a year only ("in March", "em 2027"): never before a lone day, so "in 3" is not the 3rd. */
  during: string[];
  /** Words that may lead a phrase and are skipped ("the", "la"). */
  articles: string[];
  /** Whole phrases read as an English phrase ("monatsende" → "end of month"). */
  aliases: Record<string, string>;
}

const none: string[] = [];

const en: Words = {
  today: ["today"],
  tomorrow: ["tomorrow", "tmrw", "tmr"],
  yesterday: ["yesterday"],
  afterTomorrow: ["day after tomorrow", "overmorrow"],
  beforeYesterday: ["day before yesterday"],
  now: ["now", "right now"],
  weekend: ["weekend", "week-end"],
  units: {
    minute: ["minute", "minutes", "min", "mins"],
    hour: ["hour", "hours", "hr", "hrs", "h"],
    day: ["day", "days", "d"],
    week: ["week", "weeks", "wk", "wks", "w"],
    month: ["month", "months", "mo", "mos", "mth", "mths"],
    quarter: ["quarter", "quarters"],
    year: ["year", "years", "yr", "yrs", "y"],
  },
  numbers: { a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12 },
  later: ["in {n} {u}", "{n} {u} from now", "{n} {u} later", "+{n} {u}"],
  ago: ["{n} {u} ago", "-{n}{u}"],
  nextN: ["next {n} {u}", "coming {n} {u}"],
  lastN: ["last {n} {u}", "past {n} {u}", "previous {n} {u}"],
  next: ["next {x}", "{x} next", "following {x}"],
  last: ["last {x}", "previous {x}", "{x} last"],
  this: ["this {x}", "this coming {x}", "current {x}"],
  startOf: ["start of {p}", "beginning of {p}", "{p} start"],
  endOf: ["end of {p}", "{p} end"],
  weekNumber: ["week {n}", "wk {n}", "w{n}"],
  ranges: [
    "from {a} to {b}",
    "from {a} until {b}",
    "from {a} till {b}",
    "from {a} through {b}",
    "from {a} – {b}",
    "between {a} and {b}",
    "{a} to {b}",
    "{a} until {b}",
    "{a} till {b}",
    "{a} through {b}",
    "{a} thru {b}",
  ],
  at: ["at", "@", "around"],
  on: ["on"],
  noon: ["noon", "midday", "12 noon"],
  midnight: ["midnight"],
  am: ["am", "a.m."],
  pm: ["pm", "p.m."],
  fillers: ["of", "the", "on"],
  during: ["in", "during"],
  articles: ["the"],
  aliases: { eom: "end of month", eow: "end of week", eoy: "end of year", "end of the month": "end of month" },
};

const pt: Words = {
  today: ["hoje"],
  tomorrow: ["amanhã"],
  yesterday: ["ontem"],
  afterTomorrow: ["depois de amanhã"],
  beforeYesterday: ["anteontem", "antes de ontem"],
  now: ["agora"],
  weekend: ["fim de semana", "fim-de-semana", "final de semana"],
  units: {
    minute: ["minuto", "minutos"],
    hour: ["hora", "horas"],
    day: ["dia", "dias"],
    week: ["semana", "semanas"],
    month: ["mês", "meses"],
    quarter: ["trimestre", "trimestres"],
    year: ["ano", "anos"],
  },
  numbers: { um: 1, uma: 1, dois: 2, duas: 2, "três": 3, quatro: 4, cinco: 5, seis: 6, sete: 7, oito: 8, nove: 9, dez: 10, onze: 11, doze: 12 },
  later: ["em {n} {u}", "daqui a {n} {u}", "dentro de {n} {u}", "daqui {n} {u}"],
  ago: ["há {n} {u}", "{n} {u} atrás", "há {n} {u} atrás"],
  nextN: ["próximos {n} {u}", "próximas {n} {u}"],
  lastN: ["últimos {n} {u}", "últimas {n} {u}"],
  next: ["próximo {x}", "próxima {x}", "{x} que vem", "{x} próximo", "{x} próxima", "{x} seguinte"],
  last: ["último {x}", "última {x}", "{x} passado", "{x} passada"],
  this: ["este {x}", "esta {x}", "neste {x}", "nesta {x}"],
  startOf: ["início do {p}", "início da {p}", "início de {p}", "começo do {p}", "começo da {p}", "princípio do {p}"],
  endOf: ["fim do {p}", "fim da {p}", "fim de {p}", "final do {p}", "final da {p}", "final de {p}"],
  weekNumber: ["semana {n}"],
  ranges: ["de {a} a {b}", "de {a} até {b}", "desde {a} até {b}", "do {a} ao {b}", "entre {a} e {b}", "{a} a {b}", "{a} até {b}", "{a} ao {b}"],
  at: ["às", "as", "à", "a", "pelas", "ao"],
  on: none,
  noon: ["meio-dia", "meio dia"],
  midnight: ["meia-noite", "meia noite"],
  am: ["da manhã", "de manhã"],
  pm: ["da tarde", "da noite", "de tarde", "à tarde", "à noite"],
  fillers: ["de", "do", "da", "dia", "no"],
  during: ["em"],
  articles: ["o", "a", "os", "as", "no", "na", "nos", "nas"],
  aliases: {},
};

const es: Words = {
  today: ["hoy"],
  tomorrow: ["mañana"],
  yesterday: ["ayer"],
  afterTomorrow: ["pasado mañana"],
  beforeYesterday: ["anteayer", "antes de ayer", "antier"],
  now: ["ahora"],
  weekend: ["fin de semana", "finde"],
  units: {
    minute: ["minuto", "minutos"],
    hour: ["hora", "horas"],
    day: ["día", "días"],
    week: ["semana", "semanas"],
    month: ["mes", "meses"],
    quarter: ["trimestre", "trimestres"],
    year: ["año", "años"],
  },
  numbers: { un: 1, uno: 1, una: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6, siete: 7, ocho: 8, nueve: 9, diez: 10, once: 11, doce: 12 },
  later: ["en {n} {u}", "dentro de {n} {u}"],
  ago: ["hace {n} {u}"],
  nextN: ["próximos {n} {u}", "próximas {n} {u}"],
  lastN: ["últimos {n} {u}", "últimas {n} {u}"],
  next: ["próximo {x}", "próxima {x}", "{x} que viene", "{x} próximo", "{x} próxima", "{x} siguiente"],
  last: ["{x} pasado", "{x} pasada", "último {x}", "última {x}"],
  this: ["este {x}", "esta {x}"],
  startOf: ["inicio de {p}", "inicio del {p}", "principio de {p}", "principio del {p}", "principios de {p}", "comienzo de {p}", "comienzo del {p}"],
  endOf: ["fin de {p}", "fin del {p}", "final de {p}", "final del {p}", "finales de {p}"],
  weekNumber: ["semana {n}"],
  ranges: ["de {a} a {b}", "del {a} al {b}", "desde {a} hasta {b}", "desde {a} a {b}", "entre {a} y {b}", "{a} a {b}", "{a} al {b}", "{a} hasta {b}"],
  at: ["a las", "a la", "sobre las"],
  on: none,
  noon: ["mediodía"],
  midnight: ["medianoche"],
  am: ["de la mañana"],
  pm: ["de la tarde", "de la noche"],
  fillers: ["de", "del", "el"],
  during: ["en"],
  articles: ["el", "la", "los", "las"],
  aliases: {},
};

const fr: Words = {
  today: ["aujourd'hui"],
  tomorrow: ["demain"],
  yesterday: ["hier"],
  afterTomorrow: ["après-demain", "après demain"],
  beforeYesterday: ["avant-hier", "avant hier"],
  now: ["maintenant"],
  weekend: ["week-end", "weekend", "week end"],
  units: {
    minute: ["minute", "minutes", "min"],
    hour: ["heure", "heures"],
    day: ["jour", "jours"],
    week: ["semaine", "semaines"],
    month: ["mois"],
    quarter: ["trimestre", "trimestres"],
    year: ["an", "ans", "année", "années"],
  },
  numbers: { un: 1, une: 1, deux: 2, trois: 3, quatre: 4, cinq: 5, six: 6, sept: 7, huit: 8, neuf: 9, dix: 10, onze: 11, douze: 12 },
  later: ["dans {n} {u}"],
  ago: ["il y a {n} {u}"],
  nextN: ["{n} prochains {u}", "{n} prochaines {u}"],
  lastN: ["{n} derniers {u}", "{n} dernières {u}"],
  next: ["{x} prochain", "{x} prochaine", "prochain {x}", "prochaine {x}"],
  last: ["{x} dernier", "{x} dernière", "{x} passé", "{x} passée"],
  this: ["ce {x}", "cette {x}", "cet {x}"],
  startOf: ["début de {p}", "début du {p}", "début de la {p}", "début de l'{p}"],
  endOf: ["fin de {p}", "fin du {p}", "fin de la {p}", "fin de l'{p}"],
  weekNumber: ["semaine {n}"],
  ranges: ["du {a} au {b}", "du {a} jusqu'au {b}", "de {a} à {b}", "entre {a} et {b}", "{a} au {b}", "{a} jusqu'au {b}", "{a} jusqu'à {b}", "{a} à {b}"],
  at: ["à", "vers"],
  on: none,
  noon: ["midi"],
  midnight: ["minuit"],
  am: ["du matin"],
  pm: ["de l'après-midi", "du soir"],
  fillers: ["le", "du", "de"],
  during: ["en"],
  articles: ["le", "la", "les", "l'"],
  aliases: {},
};

const de: Words = {
  today: ["heute"],
  tomorrow: ["morgen"],
  yesterday: ["gestern"],
  afterTomorrow: ["übermorgen"],
  beforeYesterday: ["vorgestern"],
  now: ["jetzt"],
  weekend: ["wochenende"],
  units: {
    minute: ["minute", "minuten", "min"],
    hour: ["stunde", "stunden", "std"],
    day: ["tag", "tage", "tagen"],
    week: ["woche", "wochen"],
    month: ["monat", "monate", "monaten", "monats"],
    quarter: ["quartal", "quartale", "quartalen", "quartals"],
    year: ["jahr", "jahre", "jahren", "jahres"],
  },
  numbers: {
    ein: 1, eine: 1, einem: 1, einer: 1, einen: 1, eins: 1, zwei: 2, drei: 3, vier: 4, "fünf": 5, sechs: 6, sieben: 7, acht: 8, neun: 9, zehn: 10, elf: 11, "zwölf": 12,
  },
  later: ["in {n} {u}"],
  ago: ["vor {n} {u}"],
  nextN: ["nächste {n} {u}", "nächsten {n} {u}", "kommende {n} {u}", "kommenden {n} {u}"],
  lastN: ["letzte {n} {u}", "letzten {n} {u}", "vergangene {n} {u}", "vergangenen {n} {u}"],
  next: ["nächste {x}", "nächsten {x}", "nächstes {x}", "nächster {x}", "kommende {x}", "kommenden {x}", "kommendes {x}"],
  last: ["letzte {x}", "letzten {x}", "letztes {x}", "letzter {x}", "vergangene {x}", "vergangenen {x}", "vergangenes {x}", "vorige {x}", "vorigen {x}", "voriges {x}"],
  this: ["diese {x}", "diesen {x}", "dieses {x}", "dieser {x}"],
  startOf: ["anfang {p}", "anfang des {p}", "anfang der {p}", "beginn des {p}", "beginn der {p}"],
  endOf: ["ende {p}", "ende des {p}", "ende der {p}"],
  weekNumber: ["kw {n}", "woche {n}"],
  ranges: ["vom {a} bis zum {b}", "vom {a} bis {b}", "von {a} bis zum {b}", "von {a} bis {b}", "zwischen {a} und {b}", "ab {a} bis {b}", "{a} bis zum {b}", "{a} bis {b}"],
  at: ["um", "gegen"],
  on: ["am"],
  noon: ["mittag", "mittags"],
  midnight: ["mitternacht"],
  am: ["morgens", "vormittags", "früh"],
  pm: ["nachmittags", "abends"],
  fillers: ["am", "den", "der"],
  during: ["im"],
  articles: ["der", "die", "das", "den", "dem", "am", "im"],
  aliases: {
    monatsende: "end of month",
    monatsanfang: "start of month",
    monatsbeginn: "start of month",
    jahresende: "end of year",
    jahresanfang: "start of year",
    jahresbeginn: "start of year",
    wochenanfang: "start of week",
    wochenbeginn: "start of week",
  },
};

const it: Words = {
  today: ["oggi"],
  tomorrow: ["domani"],
  yesterday: ["ieri"],
  afterTomorrow: ["dopodomani", "dopo domani"],
  beforeYesterday: ["l'altro ieri", "altroieri", "ieri l'altro"],
  now: ["adesso", "ora"],
  weekend: ["fine settimana", "weekend", "finesettimana"],
  units: {
    minute: ["minuto", "minuti"],
    hour: ["ora", "ore"],
    day: ["giorno", "giorni"],
    week: ["settimana", "settimane"],
    month: ["mese", "mesi"],
    quarter: ["trimestre", "trimestri"],
    year: ["anno", "anni"],
  },
  numbers: { un: 1, uno: 1, una: 1, due: 2, tre: 3, quattro: 4, cinque: 5, sei: 6, sette: 7, otto: 8, nove: 9, dieci: 10, undici: 11, dodici: 12 },
  later: ["tra {n} {u}", "fra {n} {u}", "entro {n} {u}"],
  ago: ["{n} {u} fa"],
  nextN: ["prossimi {n} {u}", "prossime {n} {u}"],
  lastN: ["ultimi {n} {u}", "ultime {n} {u}"],
  next: ["{x} prossimo", "{x} prossima", "prossimo {x}", "prossima {x}"],
  last: ["{x} scorso", "{x} scorsa", "scorso {x}", "scorsa {x}"],
  this: ["questo {x}", "questa {x}", "quest'{x}"],
  startOf: ["inizio {p}", "inizio del {p}", "inizio della {p}", "inizio dell'{p}"],
  endOf: ["fine {p}", "fine del {p}", "fine della {p}", "fine dell'{p}"],
  weekNumber: ["settimana {n}"],
  ranges: ["dal {a} al {b}", "dal {a} fino al {b}", "da {a} a {b}", "tra {a} e {b}", "fra {a} e {b}", "{a} fino al {b}", "{a} al {b}", "{a} a {b}"],
  at: ["alle", "all'", "a", "verso le"],
  on: none,
  noon: ["mezzogiorno"],
  midnight: ["mezzanotte"],
  am: ["di mattina", "del mattino"],
  pm: ["del pomeriggio", "di pomeriggio", "di sera"],
  fillers: ["il", "del", "di", "lo"],
  during: ["in", "a"],
  articles: ["il", "la", "lo", "l'", "i", "le", "gli"],
  aliases: {},
};

const nl: Words = {
  today: ["vandaag"],
  tomorrow: ["morgen"],
  yesterday: ["gisteren"],
  afterTomorrow: ["overmorgen"],
  beforeYesterday: ["eergisteren"],
  now: ["nu"],
  weekend: ["weekend"],
  units: {
    minute: ["minuut", "minuten", "min"],
    hour: ["uur", "uren"],
    day: ["dag", "dagen"],
    week: ["week", "weken"],
    month: ["maand", "maanden"],
    quarter: ["kwartaal", "kwartalen"],
    year: ["jaar", "jaren"],
  },
  numbers: { een: 1, twee: 2, drie: 3, vier: 4, vijf: 5, zes: 6, zeven: 7, acht: 8, negen: 9, tien: 10, elf: 11, twaalf: 12 },
  later: ["over {n} {u}", "binnen {n} {u}"],
  ago: ["{n} {u} geleden"],
  nextN: ["volgende {n} {u}", "komende {n} {u}"],
  lastN: ["afgelopen {n} {u}", "laatste {n} {u}", "vorige {n} {u}"],
  next: ["volgende {x}", "volgend {x}", "komende {x}", "komend {x}"],
  last: ["vorige {x}", "vorig {x}", "afgelopen {x}"],
  this: ["deze {x}", "dit {x}"],
  startOf: ["begin {p}", "begin van {p}", "begin van de {p}", "begin van het {p}"],
  endOf: ["eind {p}", "einde {p}", "eind van de {p}", "einde van de {p}", "eind van het {p}", "einde van het {p}"],
  weekNumber: ["week {n}"],
  ranges: ["van {a} tot en met {b}", "van {a} t/m {b}", "van {a} tot {b}", "tussen {a} en {b}", "{a} tot en met {b}", "{a} t/m {b}", "{a} tot {b}"],
  at: ["om", "rond"],
  on: ["op"],
  noon: ["middag", "12 uur 's middags"],
  midnight: ["middernacht"],
  am: ["'s ochtends", "'s morgens"],
  pm: ["'s middags", "'s avonds"],
  fillers: ["op", "van", "de"],
  during: ["in"],
  articles: ["de", "het"],
  aliases: {},
};

const ja: Words = {
  today: ["今日", "きょう", "本日"],
  tomorrow: ["明日", "あした", "あす"],
  yesterday: ["昨日", "きのう"],
  afterTomorrow: ["明後日", "あさって"],
  beforeYesterday: ["一昨日", "おととい"],
  now: ["今", "いま"],
  weekend: ["週末"],
  units: {
    minute: ["分", "分間"],
    hour: ["時間"],
    day: ["日", "日間"],
    week: ["週", "週間"],
    month: ["月", "ヶ月", "か月", "カ月", "ヵ月", "ケ月", "ヶ月間", "か月間", "カ月間"],
    quarter: ["四半期"],
    year: ["年", "年間"],
  },
  numbers: { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9, 十: 10, 十一: 11, 十二: 12 },
  later: ["{n}{u}後", "{n}{u}先"],
  ago: ["{n}{u}前"],
  nextN: ["次の{n}{u}", "今後{n}{u}"],
  lastN: ["過去{n}{u}", "直近{n}{u}"],
  next: ["来{x}", "来週の{x}", "次の{x}"],
  last: ["先{x}", "先週の{x}", "去{x}", "昨{x}", "前の{x}"],
  this: ["今{x}", "今週の{x}", "この{x}"],
  startOf: ["{p}初め", "{p}の初め", "{p}始め", "{p}初"],
  endOf: ["{p}末", "{p}の終わり"],
  weekNumber: ["第{n}週"],
  ranges: ["{a}から{b}まで", "{a}から{b}"],
  at: ["の", "に"],
  on: none,
  noon: ["正午", "昼12時"],
  midnight: ["真夜中", "深夜0時"],
  am: none,
  pm: none,
  fillers: ["の"],
  during: none,
  articles: none,
  aliases: { 今週末: "this weekend", 来週末: "next weekend", 先週末: "last weekend", 年始: "start of year" },
};

const tables: Record<string, Words> = { en, pt, es, fr, de, it, nl, ja };

/** The languages with word tables; English is always accepted. */
export const parseLanguages: string[] = Object.keys(tables);

// Ranges every language reads.
// "{a}-{b}" is the tight hyphen: a spaced one is normalized to the dash.
const commonRanges = ["{a} – {b}", "{a} ~ {b}", "{a}-{b}"];

// Normalizing and cutting into tokens.

const CJK = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}ー々]/u;
const TOKEN = /\{\w+\}|\d+|[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}ー々]|(?:(?![\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}])[\p{L}\p{M}])+|\S/gu;
const DROP = new Set([",", ";", "(", ")", "!", "?", '"', "«", "»", "、", "。", "・", "「", "」"]);
const ORDINALS = new Set(["st", "nd", "rd", "th", "er", "re", "ere", "e", "eme", "ieme", "o", "a"]);
const DIGITS = /^\d+$/;

function normalize(text: string): string {
  return text
    .replace(/[’‘`´]/g, "'")
    .replace(/[ºª°]/g, "")
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .normalize("NFC")
    .toLowerCase()
    .replace(/\s+[-‐‑]\s+/g, " – ")
    .replace(/[–—−]/g, " – ")
    .replace(/[〜~]/g, " ~ ");
}

function tokenize(text: string): string[] {
  const raw: { text: string; glued: boolean }[] = [];
  let end = -1;
  for (const match of text.matchAll(TOKEN)) {
    const value = match[0];
    const glued = match.index === end;
    end = match.index + value.length;
    if (!DROP.has(value)) raw.push({ text: value, glued });
  }
  const out: string[] = [];
  for (let i = 0; i < raw.length; i++) {
    const { text: value, glued } = raw[i]!;
    const prev = out[out.length - 1];
    if (value === ".") {
      // A dot stays only between digits glued to it (15.03.2027, 21.30).
      const next = raw[i + 1];
      if (prev !== undefined && DIGITS.test(prev) && glued && next && next.glued && DIGITS.test(next.text)) out.push(value);
      continue;
    }
    // An ordinal suffix glued to a number: 15th, 1er, 2e. "o" and "a"
    // only when nothing follows them glued (pt 1o, 1a).
    if (glued && prev !== undefined && DIGITS.test(prev) && ORDINALS.has(value)) {
      if ((value !== "o" && value !== "a") || !raw[i + 1]?.glued) continue;
    }
    out.push(value);
  }
  return out;
}

const tokenCache = new Map<string, string[]>();

/** The tokens of a table entry, cached. */
function tok(text: string): string[] {
  let tokens = tokenCache.get(text);
  if (!tokens) {
    tokens = tokenize(normalize(text));
    tokenCache.set(text, tokens);
  }
  return tokens;
}

const key = (tokens: string[]): string => tokens.join(" ");

const setCache = new WeakMap<string[], Set<string>>();

function inList(list: string[], tokens: string[]): boolean {
  let set = setCache.get(list);
  if (!set) {
    set = new Set(list.map((word) => key(tok(word))));
    setCache.set(list, set);
  }
  return set.has(key(tokens));
}

const mapCache = new WeakMap<object, Map<string, string | number>>();

function lookup<T extends string | number>(record: Record<string, T>, tokens: string[]): T | undefined {
  let map = mapCache.get(record);
  if (!map) {
    map = new Map(Object.entries(record).map(([word, value]) => [key(tok(word)), value]));
    mapCache.set(record, map);
  }
  return map.get(key(tokens)) as T | undefined;
}

const sortedCache = new WeakMap<string[], string[]>();

/** Templates with more words first, so "eind van de {p}" is tried before "eind {p}". */
function byWords(list: string[]): string[] {
  let sorted = sortedCache.get(list);
  if (!sorted) {
    const words = (template: string) => tok(template).filter((part) => !part.startsWith("{")).length;
    sorted = [...list].sort((a, b) => words(b) - words(a));
    sortedCache.set(list, sorted);
  }
  return sorted;
}

/** Every way the tokens fill the template's slots (each slot takes one token or more). */
function fit(template: string, tokens: string[]): Record<string, string[]>[] {
  const pattern = tok(template);
  const out: Record<string, string[]>[] = [];
  const slots: Record<string, string[]> = {};
  const go = (pi: number, ti: number): void => {
    if (pi === pattern.length) {
      if (ti === tokens.length) out.push({ ...slots });
      return;
    }
    const part = pattern[pi]!;
    if (part.length > 2 && part.startsWith("{") && part.endsWith("}")) {
      const name = part.slice(1, -1);
      for (let end = ti + 1; end <= tokens.length; end++) {
        slots[name] = tokens.slice(ti, end);
        go(pi + 1, end);
      }
      delete slots[name];
    } else if (tokens[ti] === part) {
      go(pi + 1, ti + 1);
    }
  };
  go(0, 0);
  return out;
}

function startsWith(tokens: string[], prefix: string[]): boolean {
  return prefix.length > 0 && prefix.length <= tokens.length && prefix.every((part, i) => tokens[i] === part);
}

function endsWith(tokens: string[], suffix: string[]): boolean {
  const offset = tokens.length - suffix.length;
  return suffix.length > 0 && offset >= 0 && suffix.every((part, i) => tokens[offset + i] === part);
}

// What Intl knows of a locale: month and weekday names, numeric order.

interface Names {
  months: Map<string, number>;
  weekdays: Map<string, number>;
}

interface LocaleData {
  names: Names;
  order: ("day" | "month" | "year")[];
}

const localeCache = new Map<string, LocaleData>();

function format(locale: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat | null {
  try {
    return new Intl.DateTimeFormat(locale, { ...options, timeZone: "UTC" });
  } catch {
    return null;
  }
}

/** A JavaScript Date only to ask Intl for a name. */
const dateOf = (value: Day): Date => new Date(value * 86_400_000);

function addNames(map: Map<string, number>, longs: [string[], number][], raw: string | undefined, value: number, long: boolean): void {
  if (!raw) return;
  const tokens = tokenize(normalize(raw));
  const variants = [tokens, tokens.filter((part) => part !== "-")];
  for (const variant of variants) {
    if (variant.length === 0) continue;
    if (!map.has(key(variant))) map.set(key(variant), value);
    if (long) longs.push([variant, value]);
  }
}

// Unambiguous beginnings of long names, from three letters ("sept",
// "thurs", "sexta"), or a token prefix of a Japanese name ("金曜").
function addPrefixes(map: Map<string, number>, longs: [string[], number][]): void {
  const candidates = new Map<string, Set<number>>();
  const add = (text: string, value: number) => {
    const values = candidates.get(text) ?? new Set<number>();
    values.add(value);
    candidates.set(text, values);
  };
  for (const [tokens, value] of longs) {
    const first = tokens[0]!;
    if (!CJK.test(first)) for (let length = 3; length < first.length; length++) add(first.slice(0, length), value);
    for (let count = 1; count < tokens.length; count++) {
      if (CJK.test(first) || first.length >= 3) add(key(tokens.slice(0, count)), value);
    }
  }
  for (const [text, values] of candidates) {
    if (values.size === 1 && !map.has(text)) map.set(text, [...values][0]!);
  }
}

function localeData(locale: string): LocaleData {
  const cached = localeCache.get(locale);
  if (cached) return cached;

  const base = locale.split("-")[0]!.toLowerCase();
  const sources = [...new Set([locale, base, ...(base === "pt" ? ["pt-PT", "pt-BR"] : []), "en"])];
  const months = new Map<string, number>();
  const weekdays = new Map<string, number>();
  const longMonths: [string[], number][] = [];
  const longWeekdays: [string[], number][] = [];
  const part = (f: Intl.DateTimeFormat | null, date: Date, type: string) => f?.formatToParts(date).find((p) => p.type === type)?.value;

  for (const source of sources) {
    const monthLong = format(source, { month: "long" });
    const monthShort = format(source, { month: "short" });
    const dayMonthLong = format(source, { day: "numeric", month: "long" });
    const dayMonthShort = format(source, { day: "numeric", month: "short" });
    for (let month = 1; month <= 12; month++) {
      const date = dateOf(fromYMD(2021, month, 15));
      addNames(months, longMonths, monthLong?.format(date), month, true);
      addNames(months, longMonths, part(dayMonthLong, date, "month"), month, true);
      addNames(months, longMonths, monthShort?.format(date), month, false);
      addNames(months, longMonths, part(dayMonthShort, date, "month"), month, false);
    }
    const weekdayLong = format(source, { weekday: "long" });
    const weekdayShort = format(source, { weekday: "short" });
    const fullDate = format(source, { weekday: "long", day: "numeric", month: "long" });
    const base2021 = fromYMD(2021, 3, 15);
    for (let i = 0; i < 7; i++) {
      const value = base2021 + i;
      const date = dateOf(value);
      addNames(weekdays, longWeekdays, weekdayLong?.format(date), weekday(value), true);
      addNames(weekdays, longWeekdays, part(fullDate, date, "weekday"), weekday(value), true);
      addNames(weekdays, longWeekdays, weekdayShort?.format(date), weekday(value), false);
    }
  }
  addPrefixes(months, longMonths);
  addPrefixes(weekdays, longWeekdays);

  const numeric = format(locale, { year: "numeric", month: "numeric", day: "numeric" }) ?? format("en", { year: "numeric", month: "numeric", day: "numeric" })!;
  const order = numeric
    .formatToParts(dateOf(fromYMD(2027, 3, 15)))
    .map((p) => p.type)
    .filter((type): type is "day" | "month" | "year" => type === "day" || type === "month" || type === "year");

  const data: LocaleData = { names: { months, weekdays }, order: order.length === 3 ? order : ["month", "day", "year"] };
  localeCache.set(locale, data);
  return data;
}

// Parsing.

interface Span {
  from: Day;
  to: Day;
  /** A period (a week, a month, "next 7 days") rather than one day. */
  period: boolean;
  /** A time of day, for "now" and "in 2 hours". */
  time?: Seconds;
}

interface Ctx {
  lang: Words;
  today: Day;
  now: Seconds;
  /** The day a date without a year is resolved from: today, or a range's start. */
  anchor: Day;
  direction: Direction;
  firstDay: number;
  data: LocaleData;
}

/** A written date before it is resolved: what was given of it. */
interface Written {
  year?: number;
  month?: number;
  day?: number;
  weekday?: number;
  quarter?: number;
}

const one = (day: Day): Span => ({ from: day, to: day, period: false });
const span = (from: Day, to: Day): Span => ({ from, to, period: true });

function number(tokens: string[], lang: Words): number | null {
  if (tokens.length === 1 && DIGITS.test(tokens[0]!)) return Number(tokens[0]);
  return lookup(lang.numbers, tokens) ?? null;
}

const UNITS: Unit[] = ["minute", "hour", "day", "week", "month", "quarter", "year"];

function unit(tokens: string[], lang: Words): Unit | null {
  for (const name of UNITS) {
    const words = lang.units[name];
    if (words && inList(words, tokens)) return name;
  }
  return null;
}

/** Today moved by n units: a day, or a day and a time for hours and minutes. */
function shift(n: number, u: Unit, ctx: Ctx): Span | null {
  if (!Number.isInteger(n) || Math.abs(n) > 100_000) return null;
  switch (u) {
    case "minute":
    case "hour": {
      const total = ctx.today * 86_400 + ctx.now + n * (u === "hour" ? 3600 : 60);
      const day = Math.floor(total / 86_400);
      return { ...one(day), time: total - day * 86_400 };
    }
    case "day":
      return one(ctx.today + n);
    case "week":
      return one(ctx.today + 7 * n);
    case "month":
      return one(addMonths(ctx.today, n));
    case "quarter":
      return one(addMonths(ctx.today, 3 * n));
    case "year":
      return one(addMonths(ctx.today, 12 * n));
  }
}

/** n units counted from today, forward (today first) or back (today last). */
function lastingSpan(n: number, u: Unit, forward: boolean, ctx: Ctx): Span | null {
  if (!Number.isInteger(n) || n < 1 || n > 100_000 || u === "hour" || u === "minute") return null;
  const t = ctx.today;
  const months = u === "month" ? n : u === "quarter" ? 3 * n : u === "year" ? 12 * n : 0;
  const days = u === "day" ? n : u === "week" ? 7 * n : 0;
  if (forward) return span(t, months ? addMonths(t, months) - 1 : t + days - 1);
  return span(months ? addMonths(t, -months) + 1 : t - days + 1, t);
}

function weekend(delta: number, ctx: Ctx): Span {
  const wd = weekday(ctx.today);
  const saturday = (wd === 7 ? ctx.today - 1 : ctx.today + (6 - wd)) + 7 * delta;
  return span(saturday, saturday + 1);
}

function monthSpan(year: number, month: number): Span {
  return span(fromYMD(year, month, 1), fromYMD(year, month, daysInMonth(year, month)));
}

function quarterSpan(year: number, quarter: number): Span {
  const from = fromYMD(year, quarter * 3 - 2, 1);
  return span(from, endOfQuarter(from));
}

const yearSpan = (year: number): Span => span(fromYMD(year, 1, 1), fromYMD(year, 12, 31));

function unitPeriod(u: Unit, delta: number, ctx: Ctx): Span | null {
  const t = ctx.today;
  switch (u) {
    case "day":
      return one(t + delta);
    case "week": {
      const from = startOfWeek(t, ctx.firstDay) + 7 * delta;
      return span(from, from + 6);
    }
    case "month": {
      const from = addMonths(startOfMonth(t), delta);
      return span(from, endOfMonth(from));
    }
    case "quarter": {
      const from = addMonths(startOfQuarter(t), 3 * delta);
      return span(from, endOfQuarter(from));
    }
    case "year":
      return yearSpan(toYMD(t).year + delta);
    default:
      return null;
  }
}

function nameOf(map: Map<string, number>, tokens: string[]): number | undefined {
  return map.get(key(tokens));
}

/** this (0), next (1) or last (-1) of a weekday, a unit, the weekend or a month. */
function modified(x: string[], delta: number, ctx: Ctx): Span | null {
  // Units first: Japanese 来月 is next month, though 月 is also Monday.
  const u = unit(x, ctx.lang);
  if (u) return unitPeriod(u, delta, ctx);
  const w = nameOf(ctx.data.names.weekdays, x);
  if (w !== undefined) return one(startOfWeek(ctx.today, ctx.firstDay) + ((w - ctx.firstDay + 7) % 7) + 7 * delta);
  if (inList(ctx.lang.weekend, x)) return weekend(delta, ctx);
  const m = nameOf(ctx.data.names.months, x);
  if (m !== undefined) return monthSpan(toYMD(ctx.today).year + delta, m);
  return null;
}

/** The period after "start of" and "end of": a unit alone is the current one. */
function period(p: string[], ctx: Ctx): Span | null {
  const u = unit(p, ctx.lang);
  if (u) return unitPeriod(u, 0, ctx);
  for (const article of ctx.lang.articles) {
    const a = tok(article);
    if (startsWith(p, a) && p.length > a.length) {
      const rest = period(p.slice(a.length), ctx);
      if (rest) return rest;
    }
  }
  return phrase(p, ctx);
}

/**
 * One date phrase, without a time. In order: aliases, today and its
 * neighbours, now, the weekend; "in N units" and "N units ago"; "next N
 * units" and "last N units"; next, last and this; start and end of a
 * period; week numbers; then a written date (ISO, numeric, names); and
 * finally the same without a leading article.
 */
function phrase(tokens: string[], ctx: Ctx): Span | null {
  if (tokens.length === 0) return null;
  const L = ctx.lang;
  const t = ctx.today;

  const alias = lookup(L.aliases, tokens);
  if (alias !== undefined) return phrase(tok(alias), { ...ctx, lang: en });

  if (inList(L.today, tokens)) return one(t);
  if (inList(L.tomorrow, tokens)) return one(t + 1);
  if (inList(L.yesterday, tokens)) return one(t - 1);
  if (inList(L.afterTomorrow, tokens)) return one(t + 2);
  if (inList(L.beforeYesterday, tokens)) return one(t - 2);
  if (inList(L.now, tokens)) return { ...one(t), time: ctx.now };
  if (inList(L.weekend, tokens)) return weekend(0, ctx);

  for (const [templates, sign] of [[L.later, 1], [L.ago, -1]] as const) {
    for (const template of byWords(templates)) {
      for (const slots of fit(template, tokens)) {
        const n = number(slots.n!, L);
        const u = unit(slots.u!, L);
        if (n !== null && u) return shift(sign * n, u, ctx);
      }
    }
  }

  for (const [templates, forward] of [[L.nextN, true], [L.lastN, false]] as const) {
    for (const template of byWords(templates)) {
      for (const slots of fit(template, tokens)) {
        const n = number(slots.n!, L);
        const u = unit(slots.u!, L);
        if (n !== null && u) return lastingSpan(n, u, forward, ctx);
      }
    }
  }

  for (const [templates, delta] of [[L.next, 1], [L.last, -1], [L.this, 0]] as const) {
    for (const template of byWords(templates)) {
      for (const slots of fit(template, tokens)) {
        const result = modified(slots.x!, delta, ctx);
        if (result) return result;
      }
    }
  }

  for (const [templates, end] of [[L.startOf, false], [L.endOf, true]] as const) {
    for (const template of byWords(templates)) {
      for (const slots of fit(template, tokens)) {
        const p = period(slots.p!, ctx);
        if (p) return one(end ? p.to : p.from);
      }
    }
  }

  const iso = weekNumber(tokens, ctx);
  if (iso) return iso;

  const partial = written(tokens, ctx);
  if (partial) return resolve(partial, ctx);

  for (const article of L.articles) {
    const a = tok(article);
    if (startsWith(tokens, a) && tokens.length > a.length) {
      const rest = phrase(tokens.slice(a.length), ctx);
      if (rest) return rest;
    }
  }
  return null;
}

/** 2027-W11, "week 11" (of today's ISO year), "KW 11". */
function weekNumber(tokens: string[], ctx: Ctx): Span | null {
  let year: number | null = null;
  let week: number | null = null;
  const iso = /^(\d{4})-?w(\d{1,2})$/.exec(tokens.join(""));
  if (iso) {
    year = Number(iso[1]);
    week = Number(iso[2]);
  } else {
    for (const template of ctx.lang.weekNumber) {
      for (const slots of fit(template, tokens)) {
        const n = slots.n!;
        if (n.length === 1 && DIGITS.test(n[0]!) && n[0]!.length <= 2) {
          year = isoWeek(ctx.today).year;
          week = Number(n[0]);
        }
      }
    }
  }
  if (year === null || week === null || week < 1 || week > isoWeeksInYear(year)) return null;
  const from = fromISOWeek(year, week);
  return span(from, from + 6);
}

/** A two-digit year within fifty years of today's; four digits as they are. */
function fullYear(text: string, ctx: Ctx): number | null {
  if (text.length === 4) return Number(text);
  if (text.length !== 2) return null;
  const current = toYMD(ctx.today).year;
  let year = Math.floor(current / 100) * 100 + Number(text);
  if (year > current + 50) year -= 100;
  else if (year <= current - 50) year += 100;
  return year;
}

/** A date written out: numeric, a quarter, or with names (see `classify`). */
function written(tokens: string[], ctx: Ctx): Written | null {
  const { fillers, during } = ctx.lang;
  if (tokens.length > 1 && inList(during, tokens.slice(0, 1))) {
    const p = written(tokens.slice(1), ctx);
    return p && (p.month !== undefined || p.year !== undefined || p.quarter !== undefined) ? p : null;
  }
  const t = tokens.filter((part) => !inList(fillers, [part]));
  if (t.length === 0) return null;
  const joined = t.join("");
  const q1 = /^q([1-4])(\d{4})?$/.exec(joined);
  if (q1) return { quarter: Number(q1[1]), ...(q1[2] ? { year: Number(q1[2]) } : {}) };
  const q2 = /^(\d{4})-?q([1-4])$/.exec(joined);
  if (q2) return { quarter: Number(q2[2]), year: Number(q2[1]) };
  if (t.length > 1 && t.every((part) => DIGITS.test(part) || part === "/" || part === "." || part === "-")) return numeric(t, ctx);
  return classify(t, ctx);
}

/** Numbers with one kind of separator (/ . - or space), in the locale's order. */
function numeric(t: string[], ctx: Ctx): Written | null {
  const nums: string[] = [];
  let separator: string | null = null;
  for (let i = 0; i < t.length; i++) {
    const part = t[i]!;
    if (DIGITS.test(part)) {
      if (i > 0 && DIGITS.test(t[i - 1]!)) {
        if (separator !== null && separator !== " ") return null;
        separator = " ";
      }
      nums.push(part);
    } else {
      if (i === 0 || i === t.length - 1 || !DIGITS.test(t[i - 1]!) || !DIGITS.test(t[i + 1]!)) return null;
      if (separator !== null && separator !== part) return null;
      separator = part;
    }
  }
  const small = (text: string, max: number) => (text.length <= 2 && Number(text) >= 1 && Number(text) <= max ? Number(text) : null);
  if (nums.length === 3) {
    const order = nums[0]!.length === 4 ? (["year", "month", "day"] as const) : ctx.data.order;
    const parts: Record<string, string> = {};
    order.forEach((type, i) => (parts[type] = nums[i]!));
    const year = fullYear(parts.year!, ctx);
    const month = small(parts.month!, 12);
    const day = small(parts.day!, 31);
    return year === null || month === null || day === null ? null : { year, month, day };
  }
  if (nums.length === 2) {
    const [a, b] = nums as [string, string];
    if (a.length === 4 || b.length === 4) {
      const month = small(a.length === 4 ? b : a, 12);
      return month === null || (a.length === 4 && b.length === 4) ? null : { year: Number(a.length === 4 ? a : b), month };
    }
    const order = ctx.data.order.filter((type) => type !== "year");
    const month = small(order[0] === "month" ? a : b, 12);
    const day = small(order[0] === "month" ? b : a, 31);
    return month === null || day === null ? null : { month, day };
  }
  return null;
}

/**
 * A date with month or weekday names, or CJK markers (2027年3月15日), or a
 * lone number (a day of the month, or a four-digit year). A word that is
 * both a month and a weekday ("mar" in Spanish or French) is the month
 * when a day is given, else the weekday. With a month, a number of four
 * digits is the year, else the first number is the day and the second a
 * two-digit year.
 */
function classify(t: string[], ctx: Ctx): Written | null {
  const { months, weekdays } = ctx.data.names;
  const p: Written = {};
  const nums: string[] = [];
  let both: { month: number; weekday: number } | null = null;
  const set = (field: keyof Written, value: number): boolean => {
    if (p[field] !== undefined) return false;
    p[field] = value;
    return true;
  };

  for (let i = 0; i < t.length; ) {
    const part = t[i]!;
    if (DIGITS.test(part)) {
      const marker = t[i + 1];
      const value = Number(part);
      if (marker === "年") {
        if (part.length !== 4 || !set("year", value)) return null;
        i += 2;
      } else if (marker === "月") {
        if (value < 1 || value > 12 || !set("month", value)) return null;
        i += 2;
      } else if (marker === "日") {
        if (value < 1 || value > 31 || !set("day", value)) return null;
        i += 2;
      } else {
        nums.push(part);
        i += 1;
      }
      continue;
    }
    let found = false;
    for (let length = Math.min(4, t.length - i); length >= 1; length--) {
      const k = key(t.slice(i, i + length));
      const m = months.get(k);
      const w = weekdays.get(k);
      if (m === undefined && w === undefined) continue;
      if (m !== undefined && w !== undefined) {
        if (both) return null;
        both = { month: m, weekday: w };
      } else if (m !== undefined) {
        if (!set("month", m)) return null;
      } else if (!set("weekday", w!)) return null;
      i += length;
      found = true;
      break;
    }
    if (!found) return null;
  }

  if (both) {
    if (nums.length > 0 || p.day !== undefined) {
      if (!set("month", both.month)) return null;
    } else if (!set("weekday", both.weekday)) return null;
  }

  if (p.month !== undefined) {
    // A two-digit year only as the last word: "15 mar 28", not "15 28 mar".
    const lastNumber = DIGITS.test(t[t.length - 1]!) ? t[t.length - 1] : undefined;
    for (const n of nums) {
      if (n.length === 4) {
        if (!set("year", Number(n))) return null;
      } else if (p.day === undefined && n.length <= 2 && Number(n) >= 1 && Number(n) <= 31) {
        p.day = Number(n);
      } else if (p.year === undefined && p.day !== undefined && n.length === 2 && n === lastNumber) {
        p.year = fullYear(n, ctx)!;
      } else return null;
    }
  } else if (nums.length === 1) {
    const n = nums[0]!;
    if (n.length === 4 && p.weekday === undefined && p.day === undefined) {
      if (!set("year", Number(n))) return null;
    } else if (n.length <= 2 && Number(n) >= 1 && Number(n) <= 31) {
      if (!set("day", Number(n))) return null;
    } else return null;
  } else if (nums.length > 1) return null;

  return Object.keys(p).length > 0 ? p : null;
}

/** The candidate chosen by direction: see the notes at the top. */
function pick(candidates: Span[], anchor: Day, direction: Direction): Span | null {
  const sorted = candidates.sort((a, b) => a.from - b.from);
  if (direction === "future") return sorted.find((c) => c.to >= anchor) ?? null;
  if (direction === "past") return sorted.filter((c) => c.from <= anchor).pop() ?? null;
  let best: Span | null = null;
  let bestDistance = Infinity;
  for (const c of sorted) {
    const distance = c.from > anchor ? c.from - anchor : c.to < anchor ? anchor - c.to : 0;
    // Ties go to the later one, the future.
    if (distance <= bestDistance) {
      best = c;
      bestDistance = distance;
    }
  }
  return best;
}

function resolve(p: Written, ctx: Ctx): Span | null {
  const anchor = ctx.anchor;
  const { year: y, month: m, day: d, weekday: w, quarter: q } = p;
  const current = toYMD(anchor).year;
  const years = (radius: number) => Array.from({ length: 2 * radius + 1 }, (_, i) => current - radius + i);
  let result: Span | null;

  if (q !== undefined) {
    if (m !== undefined || d !== undefined || w !== undefined) return null;
    result = y !== undefined ? quarterSpan(y, q) : pick(years(1).map((year) => quarterSpan(year, q)), anchor, ctx.direction);
  } else if (m !== undefined && d !== undefined) {
    if (y !== undefined) result = isValidYMD(y, m, d) ? one(fromYMD(y, m, d)) : null;
    else {
      // Eight years each way find a 29 February.
      const candidates = years(8).filter((year) => isValidYMD(year, m, d)).map((year) => one(fromYMD(year, m, d)));
      result = pick(candidates, anchor, ctx.direction);
    }
  } else if (d !== undefined) {
    if (y !== undefined) return null;
    const start = startOfMonth(anchor);
    const candidates: Span[] = [];
    for (let offset = -14; offset <= 14; offset++) {
      const { year, month } = toYMD(addMonths(start, offset));
      if (d <= daysInMonth(year, month)) candidates.push(one(fromYMD(year, month, d)));
    }
    result = pick(candidates, anchor, ctx.direction);
  } else if (m !== undefined) {
    result = y !== undefined ? monthSpan(y, m) : pick(years(1).map((year) => monthSpan(year, m)), anchor, ctx.direction);
    if (w !== undefined) return null;
  } else if (y !== undefined) {
    if (w !== undefined) return null;
    result = yearSpan(y);
  } else if (w !== undefined) {
    const candidates: Span[] = [];
    for (let offset = -7; offset <= 7; offset++) if (weekday(anchor + offset) === w) candidates.push(one(anchor + offset));
    return pick(candidates, anchor, ctx.direction);
  } else return null;

  if (result && w !== undefined && weekday(result.from) !== w) return null;
  return result;
}

// Times of day.

/**
 * A time of day: 9am, 9 am, 9:30pm, 21:30, 21.30, 21h30, 21h, 9 Uhr, noon,
 * 午前9時, 午後3時半, 15時30分. A bare hour ("9") only when `bare`, that is
 * after a word like "at" or in time mode.
 */
function clock(tokens: string[], bare: boolean, ctx: Ctx): Seconds | null {
  const L = ctx.lang;
  if (tokens.length === 0) return null;
  if (inList(L.noon, tokens) || inList(en.noon, tokens)) return timeOf(12, 0);
  if (inList(L.midnight, tokens) || inList(en.midnight, tokens)) return 0;

  let t = tokens;
  let meridiem: "am" | "pm" | null = null;
  if (t[0] === "午" && (t[1] === "前" || t[1] === "後")) {
    meridiem = t[1] === "前" ? "am" : "pm";
    t = t.slice(2);
  }
  if (!meridiem) {
    outer: for (const [list, value] of [[L.am, "am"], [L.pm, "pm"], [en.am, "am"], [en.pm, "pm"]] as const) {
      for (const word of list) {
        const suffix = tok(word);
        if (endsWith(t, suffix) && t.length > suffix.length) {
          meridiem = value;
          t = t.slice(0, t.length - suffix.length);
          break outer;
        }
      }
    }
  }

  const n = (i: number) => (t[i] !== undefined && DIGITS.test(t[i]!) ? t[i]! : null);
  const h = n(0);
  if (h === null || h.length > 2) return null;
  let minute = "0";
  let second = "0";
  let marked = meridiem !== null;
  const rest = t.slice(1);
  const shape = rest.map((part) => (DIGITS.test(part) ? "n" : part)).join(" ");
  switch (shape) {
    case "":
      break;
    case ": n":
    case ". n":
      minute = rest[1]!;
      if (minute.length !== 2) return null;
      marked = true;
      break;
    case ": n : n":
      minute = rest[1]!;
      second = rest[3]!;
      if (minute.length !== 2 || second.length !== 2) return null;
      marked = true;
      break;
    case "h":
    case "uhr":
    case "時":
      marked = true;
      break;
    case "h n":
    case "uhr n":
    case ": n uhr":
      minute = rest[1]!;
      if (minute.length !== 2) return null;
      marked = true;
      break;
    case "時 半":
      minute = "30";
      marked = true;
      break;
    case "時 n 分":
      minute = rest[1]!;
      marked = true;
      break;
    default:
      return null;
  }
  if (!marked && !bare) return null;
  let hour = Number(h);
  const min = Number(minute);
  const sec = Number(second);
  if (min > 59 || sec > 59) return null;
  if (meridiem) {
    if (hour > 12) return null;
    hour = (hour % 12) + (meridiem === "pm" ? 12 : 0);
  } else if (hour > 23) return null;
  return timeOf(hour, min, sec);
}

/** A time, after an optional "at": a bare hour is read after "at". */
function timeAt(tokens: string[], ctx: Ctx): Seconds | null {
  for (const list of [ctx.lang.at, en.at]) {
    for (const word of list) {
      const lead = tok(word);
      if (startsWith(tokens, lead) && tokens.length > lead.length) {
        const time = clock(tokens.slice(lead.length), true, ctx);
        if (time !== null) return time;
      }
    }
  }
  return clock(tokens, false, ctx);
}

/** A date phrase after an optional "on". */
function dateOn(tokens: string[], ctx: Ctx): Span | null {
  for (const word of ctx.lang.on) {
    const lead = tok(word);
    if (startsWith(tokens, lead) && tokens.length > lead.length) {
      const result = phrase(tokens.slice(lead.length), ctx);
      if (result) return result;
    }
  }
  return phrase(tokens, ctx);
}

/** A date and a time, either way round, or a time alone (today). */
function dateAndTime(tokens: string[], ctx: Ctx): { span: Span; time: Seconds; alone: boolean } | null {
  for (let k = 1; k < tokens.length; k++) {
    const left = tokens.slice(0, k);
    const right = tokens.slice(k);
    const date = phrase(left, ctx);
    if (date && date.time === undefined) {
      const time = timeAt(right, ctx);
      if (time !== null) return { span: date, time, alone: false };
    }
    const time = timeAt(left, ctx);
    if (time !== null) {
      const later = dateOn(right, ctx);
      if (later && later.time === undefined) return { span: later, time, alone: false };
    }
  }
  const time = timeAt(tokens, ctx);
  return time !== null ? { span: one(ctx.today), time, alone: true } : null;
}

// Ranges.

function dayOnly(p: Written): boolean {
  return p.day !== undefined && p.month === undefined && p.year === undefined && p.weekday === undefined && p.quarter === undefined;
}

/** A range from two phrases: see the notes at the top for how the end is resolved. */
function between(a: string[], b: string[], ctx: Ctx): Span | null {
  const pa = written(a, ctx);
  const pb = written(b, ctx);
  if (pa && pb) {
    // One side lends the other its month (and year): both in that month.
    let shared = false;
    if (dayOnly(pa) && pb.month !== undefined && pb.day !== undefined && pb.weekday === undefined) {
      pa.month = pb.month;
      if (pb.year !== undefined) pa.year = pb.year;
      shared = true;
    } else if (dayOnly(pb) && pa.day !== undefined && pa.weekday === undefined) {
      if (pa.month !== undefined) pb.month = pa.month;
      if (pa.year !== undefined) pb.year = pa.year;
      shared = true;
    }
    const start = resolve(pa, ctx);
    if (!start) return null;
    let end: Span | null;
    if (shared) {
      const { year, month } = toYMD(start.from);
      end = resolve({ ...pb, year, month }, ctx);
    } else {
      end = resolve(pb, { ...ctx, anchor: start.from, direction: "future" });
    }
    if (!end || end.to < start.from) return null;
    return span(start.from, end.to);
  }
  const start = phrase(a, ctx);
  if (!start || start.time !== undefined) return null;
  const end = phrase(b, { ...ctx, anchor: start.from, direction: "future" });
  if (!end || end.time !== undefined || end.to < start.from) return null;
  return span(start.from, end.to);
}

function range(tokens: string[], ctx: Ctx): Span | null {
  for (const template of [...byWords(ctx.lang.ranges), ...commonRanges]) {
    for (const slots of fit(template, tokens)) {
      const result = between(slots.a!, slots.b!, ctx);
      if (result) return result;
    }
  }
  return null;
}

// The whole.

function finish(s: Span, mode: ParseMode): ParseResult {
  if (mode === "range") return s.period ? { kind: "range", from: s.from, to: s.to } : { kind: "date", day: s.from };
  if (mode === "datetime" && s.time !== undefined) return { kind: "datetime", day: s.from, time: s.time };
  return { kind: "date", day: s.from };
}

function parseWith(tokens: string[], ctx: Ctx, mode: ParseMode): ParseResult | null {
  if (mode === "time") {
    const time = clock(tokens, true, ctx) ?? timeAt(tokens, ctx);
    if (time !== null) return { kind: "time", time };
    const s = phrase(tokens, ctx);
    return s?.time !== undefined ? { kind: "time", time: s.time } : null;
  }

  const s = phrase(tokens, ctx);
  if (s) return finish(s, mode);

  const dt = dateAndTime(tokens, ctx);
  if (dt) {
    if (mode === "datetime") return { kind: "datetime", day: dt.span.from, time: dt.time };
    if (!dt.alone) return finish(dt.span, mode);
  }

  if (mode === "range") {
    const r = range(tokens, ctx);
    if (r) return { kind: "range", from: r.from, to: r.to };
  }
  return null;
}

/**
 * Reads a date, a range, a date and time or a time typed in plain words,
 * or returns null. Never throws.
 */
export function parseDate(text: string, options: ParseOptions): ParseResult | null {
  try {
    if (typeof text !== "string" || text.length > 200 || !Number.isInteger(options.today)) return null;
    const tokens = tokenize(normalize(text));
    if (tokens.length === 0) return null;

    let locale = options.locale || "en";
    try {
      locale = Intl.getCanonicalLocales(locale)[0] ?? "en";
    } catch {
      locale = "en";
    }
    const data = localeData(locale);
    const firstDay = Number.isInteger(options.firstDay) && options.firstDay! >= 1 && options.firstDay! <= 7 ? options.firstDay! : 1;
    const now = Number.isFinite(options.now) ? Math.max(0, Math.min(86_399, Math.floor(options.now!))) : 0;
    const direction = options.direction ?? "future";
    const base = locale.split("-")[0]!.toLowerCase();
    const langs = [...new Set([tables[base], en].filter((words): words is Words => words !== undefined))];

    for (const lang of langs) {
      const ctx: Ctx = { lang, today: options.today, now, anchor: options.today, direction, firstDay, data };
      const result = parseWith(tokens, ctx, options.mode);
      if (result) return result;
    }
    return null;
  } catch {
    return null;
  }
}
