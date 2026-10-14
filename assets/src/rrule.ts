// Recurrence rules: a subset of the RFC 5545 RRULE, read, written,
// expanded and described exactly as Koyomi.Recurrence does on the server.
// test/fixtures/recurrence.json holds both sides to the same results.
//
// Supported parts: FREQ (DAILY, WEEKLY, MONTHLY, YEARLY), INTERVAL, COUNT,
// UNTIL (20271231 or 20271231T235959Z), BYDAY (with an ordinal such as 1MO
// or -1FR for a monthly or yearly rule), BYMONTHDAY, BYMONTH, BYSETPOS and
// WKST. Days are numbers of days since 1970-01-01, as in iso.ts.

import { addMonths, daysInMonth, fromYMD, parseDateTime, parseISO, toYMD, weekday, type Day } from "./iso";

export type Freq = "daily" | "weekly" | "monthly" | "yearly";

export interface ByDay {
  /** A position in the month or year (1 the first, -1 the last), or null for every such weekday. */
  ordinal: number | null;
  /** ISO weekday, 1 (Monday) to 7 (Sunday). */
  weekday: number;
}

export interface Rule {
  freq: Freq;
  interval: number;
  count: number | null;
  /** `2027-12-31`, or a UTC instant `2027-12-31T23:59:59Z`; inclusive. */
  until: string | null;
  byDay: ByDay[];
  byMonthDay: number[];
  byMonth: number[];
  bySetPos: number[];
  /** The first day of the week, 1 (Monday) to 7. */
  weekStart: number;
}

export type ParseResult = { ok: true; rule: Rule } | { ok: false; error: string };

const FREQS: Record<string, Freq> = { DAILY: "daily", WEEKLY: "weekly", MONTHLY: "monthly", YEARLY: "yearly" };
const DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
const PARTS = ["FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "BYMONTHDAY", "BYMONTH", "BYSETPOS", "WKST"];
const UNTIL_ERROR = "UNTIL must be a date (20271231) or a UTC date and time (20271231T235959Z)";

/** A rule with the defaults: every period, no end, weeks from Monday. */
export function emptyRule(freq: Freq): Rule {
  return { freq, interval: 1, count: null, until: null, byDay: [], byMonthDay: [], byMonth: [], bySetPos: [], weekStart: 1 };
}

class RuleError extends Error {}

/** Reads a rule text, with or without `RRULE:`, in any case and any order of parts. */
export function parseRule(text: string): ParseResult {
  let source = text.trim().toUpperCase();
  if (source.startsWith("RRULE:")) source = source.slice(6);
  const parts = source.split(";").filter((part) => part !== "");
  if (parts.length === 0) return { ok: false, error: "The rule is empty" };

  const rule: Partial<Rule> = { ...emptyRule("daily"), freq: undefined };
  const seen = new Set<string>();
  try {
    for (const part of parts) {
      const eq = part.indexOf("=");
      if (eq < 0) throw new RuleError(`${part} is not a NAME=VALUE pair`);
      const name = part.slice(0, eq);
      const value = part.slice(eq + 1);
      if (value === "") throw new RuleError(`${name} is empty`);
      if (!PARTS.includes(name)) throw new RuleError(`${name} is not supported`);
      if (seen.has(name)) throw new RuleError(`${name} appears twice`);
      seen.add(name);
      parseValue(rule, name, value);
    }
  } catch (error) {
    if (error instanceof RuleError) return { ok: false, error: error.message };
    throw error;
  }
  return finish(rule);
}

function parseValue(rule: Partial<Rule>, name: string, value: string): void {
  switch (name) {
    case "FREQ": {
      const freq = FREQS[value];
      if (!freq) throw new RuleError(`FREQ=${value} is not supported`);
      rule.freq = freq;
      return;
    }
    case "INTERVAL":
    case "COUNT": {
      if (!/^\d{1,9}$/.test(value) || Number(value) <= 0) throw new RuleError(`${name} must be a positive whole number`);
      if (name === "INTERVAL") rule.interval = Number(value);
      else rule.count = Number(value);
      return;
    }
    case "UNTIL": {
      const until = readUntil(value);
      if (until === null) throw new RuleError(UNTIL_ERROR);
      rule.until = until;
      return;
    }
    case "BYDAY":
      rule.byDay = list(value, "BYDAY has an invalid day: ", (token) => {
        const match = /^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$/.exec(token);
        if (!match) return null;
        return { ordinal: match[1] === undefined ? null : Number(match[1]), weekday: DAYS.indexOf(match[2]!) + 1 };
      });
      return;
    case "BYMONTHDAY":
      rule.byMonthDay = list(value, "BYMONTHDAY has an invalid day: ", integer);
      return;
    case "BYMONTH":
      rule.byMonth = list(value, "BYMONTH has an invalid month: ", integer);
      return;
    case "BYSETPOS":
      rule.bySetPos = list(value, "BYSETPOS has an invalid position: ", integer);
      return;
    case "WKST": {
      const day = DAYS.indexOf(value);
      if (day < 0) throw new RuleError(`WKST has an invalid day: ${value}`);
      rule.weekStart = day + 1;
      return;
    }
  }
}

function list<T>(value: string, message: string, read: (token: string) => T | null): T[] {
  return value.split(",").map((token) => {
    const item = read(token);
    if (item === null) throw new RuleError(message + token);
    return item;
  });
}

function integer(token: string): number | null {
  return /^[+-]?\d{1,3}$/.test(token) ? Number(token) : null;
}

function readUntil(value: string): string | null {
  const match = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z)?$/.exec(value);
  if (!match) return null;
  const date = `${match[1]}-${match[2]}-${match[3]}`;
  if (parseISO(date) === null) return null;
  if (match[4] === undefined) return date;
  const datetime = `${date}T${match[4]}:${match[5]}:${match[6]}Z`;
  return parseDateTime(datetime) === null ? null : datetime;
}

// The checks of values and of parts together, in the order that
// Koyomi.Recurrence makes them, then the sorted lists.
function finish(rule: Partial<Rule>): ParseResult {
  const error = validate(rule);
  if (error !== null) return { ok: false, error };
  const full = rule as Rule;
  return {
    ok: true,
    rule: {
      ...full,
      byDay: uniqueBy(full.byDay, (d) => `${d.ordinal}:${d.weekday}`).sort((a, b) => dayKey(a) - dayKey(b)),
      byMonthDay: uniqueBy(full.byMonthDay, String).sort((a, b) => numberKey(a) - numberKey(b)),
      byMonth: uniqueBy(full.byMonth, String).sort((a, b) => a - b),
      bySetPos: uniqueBy(full.bySetPos, String).sort((a, b) => numberKey(a) - numberKey(b)),
    },
  };
}

function uniqueBy<T>(items: T[], key: (item: T) => string): T[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const k = key(item);
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

const numberKey = (n: number): number => (n >= 0 ? n : 1000 - n);
const dayKey = (d: ByDay): number => d.weekday * 10_000 + numberKey(d.ordinal ?? 0);

function validate(rule: Partial<Rule>): string | null {
  const { freq } = rule;
  if (freq === undefined) return "FREQ is missing";
  const byDay = rule.byDay ?? [];
  const byMonthDay = rule.byMonthDay ?? [];
  const byMonth = rule.byMonth ?? [];
  const bySetPos = rule.bySetPos ?? [];

  if (rule.count != null && rule.until != null) return "COUNT and UNTIL cannot both be set";
  const month = byMonth.find((m) => m < 1 || m > 12);
  if (month !== undefined) return `BYMONTH has an invalid month: ${month}`;
  if (freq === "weekly" && byMonthDay.length > 0) return "BYMONTHDAY cannot be used with FREQ=WEEKLY";
  const monthDay = byMonthDay.find((n) => n === 0 || Math.abs(n) > 31);
  if (monthDay !== undefined) return `BYMONTHDAY has an invalid day: ${monthDay}`;
  const maxOrdinal = freq === "monthly" ? 5 : 53;
  const day = byDay.find(
    (d) => d.weekday < 1 || d.weekday > 7 || (d.ordinal !== null && (d.ordinal === 0 || Math.abs(d.ordinal) > maxOrdinal)),
  );
  if (day !== undefined) return `BYDAY has an invalid day: ${formatDay(day)}`;
  if ((freq === "daily" || freq === "weekly") && byDay.some((d) => d.ordinal !== null)) {
    return "BYDAY ordinals such as 1MO need FREQ=MONTHLY or FREQ=YEARLY";
  }
  const position = bySetPos.find((n) => n === 0 || Math.abs(n) > 366);
  if (position !== undefined) return `BYSETPOS has an invalid position: ${position}`;
  if (bySetPos.length > 0 && byDay.length === 0 && byMonthDay.length === 0 && byMonth.length === 0) {
    return "BYSETPOS needs BYDAY, BYMONTHDAY or BYMONTH";
  }
  return null;
}

function formatDay(day: ByDay): string {
  const code = DAYS[day.weekday - 1] ?? String(day.weekday);
  return day.ordinal === null ? code : `${day.ordinal}${code}`;
}

/** Checks a rule built in the browser (from a form, say): null, or the error parseRule would give. */
export function checkRule(rule: Rule): string | null {
  if (!Number.isInteger(rule.interval) || rule.interval < 1 || rule.interval > 999_999_999) {
    return "INTERVAL must be a positive whole number";
  }
  if (rule.count !== null && (!Number.isInteger(rule.count) || rule.count < 1 || rule.count > 999_999_999)) {
    return "COUNT must be a positive whole number";
  }
  if (rule.until !== null && untilDay(rule.until) === null) return UNTIL_ERROR;
  if (!Number.isInteger(rule.weekStart) || rule.weekStart < 1 || rule.weekStart > 7) {
    return `WKST has an invalid day: ${rule.weekStart}`;
  }
  return validate(rule);
}

/**
 * Writes the rule text in one order: FREQ, INTERVAL (left out when 1),
 * BYMONTH, BYMONTHDAY, BYDAY, BYSETPOS, WKST (left out when Monday), then
 * COUNT or UNTIL. The same rule gives the same text as on the server.
 */
export function formatRule(rule: Rule): string {
  const parts = [`FREQ=${rule.freq.toUpperCase()}`];
  if (rule.interval !== 1) parts.push(`INTERVAL=${rule.interval}`);
  if (rule.byMonth.length) parts.push(`BYMONTH=${rule.byMonth.join(",")}`);
  if (rule.byMonthDay.length) parts.push(`BYMONTHDAY=${rule.byMonthDay.join(",")}`);
  if (rule.byDay.length) parts.push(`BYDAY=${rule.byDay.map(formatDay).join(",")}`);
  if (rule.bySetPos.length) parts.push(`BYSETPOS=${rule.bySetPos.join(",")}`);
  if (rule.weekStart !== 1) parts.push(`WKST=${DAYS[rule.weekStart - 1]}`);
  if (rule.count !== null) parts.push(`COUNT=${rule.count}`);
  if (rule.until !== null) parts.push(`UNTIL=${rule.until.replace(/[-:]/g, "")}`);
  return parts.join(";");
}

/** The day of UNTIL (the UTC day of an instant), or null. */
export function untilDay(until: string): Day | null {
  const day = parseISO(until);
  if (day !== null) return day;
  const datetime = /Z$/.test(until) ? parseDateTime(until) : null;
  return datetime === null ? null : datetime.day;
}

// Occurrences.

// The Gregorian calendar repeats every 400 years (146 097 days): a rule
// with no occurrence in that long has none to come.
const GIVE_UP = 146_097;
const LAST_DAY = fromYMD(9999, 12, 31);

/**
 * The days of the first `limit` occurrences from `start` (DTSTART, the
 * first occurrence, which COUNT counts), up to UNTIL and up to `untilDay`,
 * both inclusive. A rule that stops producing ends after 400 years without
 * an occurrence, or at the year 9999.
 *
 * Each period (a day, a week from `weekStart`, a month or a year, every
 * `interval` periods) takes the days that pass each BY part, which is the
 * same as the RFC's expand and limit table; BYSETPOS then picks among them.
 */
export function occurrences(rule: Rule, start: Day, limit: number, untilDay_?: Day | null): Day[] {
  const ruleUntil = rule.until === null ? null : untilDay(rule.until);
  const end = Math.min(ruleUntil ?? Infinity, untilDay_ ?? Infinity);
  const max = Math.min(limit, rule.count ?? Infinity);
  const result: Day[] = [];
  if (max <= 0 || start > end) return result;
  result.push(start);

  const filled = withDefaults(rule, start);
  let last = start;
  for (let k = 0; result.length < max; k++) {
    const period = periodDays(filled, start, k);
    if (period === null) break;
    const days = period.days.filter((day) => day > start);
    if (days.length === 0) {
      if (period.first - last > GIVE_UP) break;
      continue;
    }
    for (const day of days) {
      if (day > end || result.length >= max) return result;
      result.push(day);
    }
    last = days[days.length - 1]!;
  }
  return result;
}

// The parts that the rule leaves out, from the start (RFC 5545, as
// python-dateutil and libical read it).
function withDefaults(rule: Rule, start: Day): Rule {
  const { month, day } = toYMD(start);
  if (rule.freq === "weekly" && rule.byDay.length === 0) {
    return { ...rule, byDay: [{ ordinal: null, weekday: weekday(start) }] };
  }
  if (rule.freq === "monthly" && rule.byDay.length === 0 && rule.byMonthDay.length === 0) {
    return { ...rule, byMonthDay: [day] };
  }
  if (rule.freq === "yearly" && rule.byDay.length === 0 && rule.byMonthDay.length === 0) {
    return { ...rule, byMonthDay: [day], byMonth: rule.byMonth.length ? rule.byMonth : [month] };
  }
  return rule;
}

function periodDays(rule: Rule, start: Day, k: number): { first: Day; days: Day[] } | null {
  const step = k * rule.interval;
  let first: Day;
  let last: Day;
  switch (rule.freq) {
    case "daily":
      first = last = start + step;
      break;
    case "weekly":
      first = start - ((((weekday(start) - rule.weekStart) % 7) + 7) % 7) + 7 * step;
      last = first + 6;
      break;
    case "monthly": {
      const { year, month } = toYMD(start);
      const index = year * 12 + month - 1 + step;
      const y = Math.floor(index / 12);
      if (y > 9999) return null;
      first = addMonths(fromYMD(year, month, 1), step);
      last = first + daysInMonth(y, index - y * 12 + 1) - 1;
      break;
    }
    case "yearly": {
      const y = toYMD(start).year + step;
      if (y > 9999) return null;
      first = fromYMD(y, 1, 1);
      last = fromYMD(y, 12, 31);
      break;
    }
  }
  if (first > LAST_DAY) return null;

  const days: Day[] = [];
  for (let day = first; day <= Math.min(last, LAST_DAY); day++) {
    if (matches(rule, day)) days.push(day);
  }
  return { first, days: setPositions(days, rule.bySetPos) };
}

function matches(rule: Rule, day: Day): boolean {
  const { year, month, day: dom } = toYMD(day);
  if (rule.byMonth.length && !rule.byMonth.includes(month)) return false;
  if (rule.byMonthDay.length) {
    const dim = daysInMonth(year, month);
    if (!rule.byMonthDay.some((n) => (n > 0 ? dom === n : dom === dim + n + 1))) return false;
  }
  if (rule.byDay.length) {
    const wd = weekday(day);
    const ok = rule.byDay.some((entry) => {
      if (entry.weekday !== wd) return false;
      if (entry.ordinal === null) return true;
      // An ordinal counts in the month for a monthly rule and for a
      // yearly rule with BYMONTH, in the year otherwise.
      const inMonth = rule.freq === "monthly" || rule.byMonth.length > 0;
      const first = inMonth ? fromYMD(year, month, 1) : fromYMD(year, 1, 1);
      const last = inMonth ? fromYMD(year, month, daysInMonth(year, month)) : fromYMD(year, 12, 31);
      return entry.ordinal > 0
        ? Math.floor((day - first) / 7) + 1 === entry.ordinal
        : -(Math.floor((last - day) / 7) + 1) === entry.ordinal;
    });
    if (!ok) return false;
  }
  return true;
}

function setPositions(days: Day[], positions: number[]): Day[] {
  if (positions.length === 0) return days;
  const size = days.length;
  const indexes = [...new Set(positions.map((n) => (n > 0 ? n - 1 : size + n)))]
    .filter((i) => i >= 0 && i < size)
    .sort((a, b) => a - b);
  return indexes.map((i) => days[i]!);
}

// Descriptions: word for word the same as Koyomi.Recurrence.describe/3
// (lib/koyomi/recurrence/describe.ex). A sentence is the frequency, the
// days, the months, a condition, the positions and the end. The day
// phrases carry their own article and preposition where the language
// needs one per day (pt "à segunda-feira", de "am Montag"); English and
// Dutch put one "on"/"op" before the list.

type Lang = "en" | "pt" | "es" | "fr" | "de" | "it" | "nl" | "ja";
type Gender = "m" | "f";
type Context = "on" | "subject";
const LANGS: Lang[] = ["en", "pt", "es", "fr", "de", "it", "nl", "ja"];
const FREQ_INDEX: Record<Freq, number> = { daily: 0, weekly: 1, monthly: 2, yearly: 3 };

const WEEKDAYS: Record<Lang, string[]> = {
  en: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
  pt: ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado", "domingo"],
  es: ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"],
  fr: ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"],
  de: ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"],
  it: ["lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato", "domenica"],
  nl: ["maandag", "dinsdag", "woensdag", "donderdag", "vrijdag", "zaterdag", "zondag"],
  ja: ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"],
};

const MONTHS: Record<Lang, string[]> = {
  en: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
  pt: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"],
  es: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
  fr: ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
  de: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
  it: ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"],
  nl: ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september", "oktober", "november", "december"],
  ja: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
};

const CONJUNCTIONS: Record<Lang, [string, string]> = {
  en: ["and", "or"],
  pt: ["e", "ou"],
  es: ["y", "o"],
  fr: ["et", "ou"],
  de: ["und", "oder"],
  it: ["e", "o"],
  nl: ["en", "of"],
  ja: ["と", "か"],
};

/** The language of a locale: `pt-BR` is `pt`, and a language without a table is `en`. */
export function describeLanguage(locale: string | null | undefined): Lang {
  const language = (locale ?? "").toLowerCase().split(/[-_]/)[0] as Lang;
  return LANGS.includes(language) ? language : "en";
}

/**
 * A sentence that describes the rule, in English, European Portuguese,
 * Spanish, French, German, Italian, Dutch or Japanese: "Every 2 weeks on
 * Monday and Wednesday, 10 times". With `start`, the days that the rule
 * takes from the start are named too ("Weekly on Wednesday").
 */
export function describeRule(rule: Rule, locale = "en", start?: Day | null): string {
  const lang = describeLanguage(locale);
  const r = start == null ? rule : withDefaults(rule, start);
  const plain = r.byDay.filter((d) => d.ordinal === null).map((d) => d.weekday);
  const ordinals = r.byDay.some((d) => d.ordinal !== null);
  const weekdays = !ordinals && plain.join() === "1,2,3,4,5";
  const everyDay = !ordinals && plain.join() === "1,2,3,4,5,6,7";
  const nounPositions = r.bySetPos.length > 0 && r.byMonthDay.length === 0 && (weekdays || everyDay);
  const date = r.freq === "yearly" && r.byMonth.length === 1 && r.byDay.length === 0 && r.byMonthDay.length === 1 && r.byMonthDay[0]! > 0;

  let days: string | null = null;
  let months: number[] = r.byMonth;
  if (date) {
    days = dateText(lang, r.byMonth[0]!, r.byMonthDay[0]!);
    months = [];
  } else if (r.byMonthDay.length) {
    days = onList(lang, r.byMonthDay.map((n) => monthDay(lang, n)));
  } else if (nounPositions) {
    days = onList(lang, r.bySetPos.map((n) => nth(lang, n, weekdays ? "weekday" : "day", "on")));
  } else if (weekdays) {
    days = WEEKDAYS_PHRASE[lang];
  } else if (r.byDay.length) {
    days = onList(lang, r.byDay.map((d) => dayText(lang, d, "on")));
  }

  const parts: Parts = {
    freq: freqText(lang, r.freq, r.interval),
    interval: r.interval,
    daily: r.freq === "daily",
    days,
    months: months.length ? months.map((m) => MONTHS[lang][m - 1]!) : null,
    ofYear: r.freq === "yearly" && r.byMonth.length === 0 && r.byMonthDay.length === 0 && ordinals,
    ofMonth: r.freq === "yearly" && r.byMonth.length === 0 && r.byMonthDay.length > 0,
    limit: r.byMonthDay.length && r.byDay.length ? limitText(lang, join(lang, r.byDay.map((d) => dayText(lang, d, "subject")), "or")) : null,
    positions: r.bySetPos.length && !nounPositions ? positionsText(lang, r.bySetPos, r.freq) : null,
    ending: endingText(lang, r),
  };
  return assemble(lang, parts);
}

interface Parts {
  freq: string;
  interval: number;
  daily: boolean;
  days: string | null;
  months: string[] | null;
  ofYear: boolean;
  ofMonth: boolean;
  limit: string | null;
  positions: string | null;
  ending: string;
}

function assemble(lang: Lang, p: Parts): string {
  if (lang === "ja") {
    const months = p.months && join("ja", p.months, "and");
    let details: string | null = null;
    if (p.days && months) details = `${months}の${p.days}`;
    else if (p.days && p.ofMonth) details = `各月の${p.days}`;
    else if (p.days) details = p.days;
    let head: string;
    if (details && p.daily) head = `${p.freq}（${details}）`;
    else if (details && p.interval > 1) head = `${p.freq}の${details}`;
    else if (details) head = p.freq + details;
    else if (months) head = `${p.freq}（${months}）`;
    else head = p.freq;
    return head + (p.limit ?? "") + (p.positions ?? "") + p.ending;
  }
  return (
    p.freq +
    (p.days ? " " + p.days : "") +
    (p.ofYear ? OF_YEAR[lang] : "") +
    (p.ofMonth ? OF_MONTH[lang] : "") +
    (p.months ? " " + monthsText(lang, p.months) : "") +
    (p.limit ?? "") +
    (p.positions ?? "") +
    p.ending
  );
}

function join(lang: Lang, items: string[], kind: "and" | "or"): string {
  const conj = CONJUNCTIONS[lang][kind === "and" ? 0 : 1];
  if (items.length === 1) return items[0]!;
  const head = items.slice(0, -1);
  const last = items[items.length - 1]!;
  return lang === "ja" ? head.join("、") + conj + last : `${head.join(", ")} ${conj} ${last}`;
}

function onList(lang: Lang, items: string[]): string {
  const on = lang === "en" ? "on " : lang === "nl" ? "op " : "";
  return on + join(lang, items, "and");
}

function freqText(lang: Lang, freq: Freq, n: number): string {
  const i = FREQ_INDEX[freq];
  if (n === 1) {
    return {
      en: ["Daily", "Weekly", "Monthly", "Every year"],
      pt: ["Todos os dias", "Todas as semanas", "Todos os meses", "Todos os anos"],
      es: ["Todos los días", "Todas las semanas", "Todos los meses", "Todos los años"],
      fr: ["Tous les jours", "Toutes les semaines", "Tous les mois", "Tous les ans"],
      de: ["Täglich", "Wöchentlich", "Monatlich", "Jährlich"],
      it: ["Ogni giorno", "Ogni settimana", "Ogni mese", "Ogni anno"],
      nl: ["Dagelijks", "Wekelijks", "Maandelijks", "Jaarlijks"],
      ja: ["毎日", "毎週", "毎月", "毎年"],
    }[lang][i]!;
  }
  switch (lang) {
    case "en":
      return `Every ${n} ` + ["days", "weeks", "months", "years"][i];
    case "pt":
      return `A cada ${n} ` + ["dias", "semanas", "meses", "anos"][i];
    case "es":
      return `Cada ${n} ` + ["días", "semanas", "meses", "años"][i];
    case "fr":
      return [`Tous les ${n} jours`, `Toutes les ${n} semaines`, `Tous les ${n} mois`, `Tous les ${n} ans`][i]!;
    case "de":
      return `Alle ${n} ` + ["Tage", "Wochen", "Monate", "Jahre"][i];
    case "it":
      return `Ogni ${n} ` + ["giorni", "settimane", "mesi", "anni"][i];
    case "nl":
      return `Om de ${n} ` + ["dagen", "weken", "maanden", "jaar"][i];
    case "ja":
      return `${n}` + ["日ごと", "週間ごと", "か月ごと", "年ごと"][i];
  }
}

// Ordinals: the word before the noun and what follows the noun, for a
// gender and a grammatical context ("on" after "on", "subject" as the
// subject of "it is", which only German tells apart).
function ordinal(lang: Exclude<Lang, "ja">, n: number, gender: Gender, context: Context): [string, string] {
  const f = gender === "f";
  switch (lang) {
    case "en": {
      const words = ["first", "second", "third", "fourth", "fifth"];
      if (n >= 1 && n <= 5) return [words[n - 1]!, ""];
      if (n > 0) return [numeralEn(n), ""];
      if (n === -1) return ["last", ""];
      if (-n <= 5) return [`${words[-n - 1]} to last`, ""];
      return [`${numeralEn(-n)} to last`, ""];
    }
    case "pt": {
      const o = f ? "a" : "o";
      if (n >= 1 && n <= 5) return [["primeir", "segund", "terceir", "quart", "quint"][n - 1]! + o, ""];
      if (n > 0) return [`${n}.${f ? "ª" : "º"}`, ""];
      if (n === -1) return ["últim" + o, ""];
      if (n === -2) return ["penúltim" + o, ""];
      return [ordinal("pt", -n, gender, "on")[0], " a contar do fim"];
    }
    case "es": {
      const words = f ? ["primera", "segunda", "tercera", "cuarta", "quinta"] : ["primer", "segundo", "tercer", "cuarto", "quinto"];
      const o = f ? "a" : "o";
      if (n >= 1 && n <= 5) return [words[n - 1]!, ""];
      if (n > 0) return [`${n}.${f ? "ª" : "º"}`, ""];
      if (n === -1) return ["últim" + o, ""];
      if (n === -2) return ["penúltim" + o, ""];
      return [ordinal("es", -n, gender, "on")[0], " desde el final"];
    }
    case "fr": {
      const last = f ? "dernière" : "dernier";
      if (n === 1) return [f ? "première" : "premier", ""];
      if (n >= 2 && n <= 5) return [["deuxième", "troisième", "quatrième", "cinquième"][n - 2]!, ""];
      if (n > 0) return [`${n}e`, ""];
      if (n === -1) return [last, ""];
      if (n === -2) return ["avant-" + last, ""];
      return [ordinal("fr", -n, gender, "on")[0], " en partant de la fin"];
    }
    case "de": {
      const e = context === "on" ? "en" : "e";
      if (n >= 1 && n <= 5) return [["erst", "zweit", "dritt", "viert", "fünft"][n - 1]! + e, ""];
      if (n > 0) return [`${n}.`, ""];
      if (n === -1) return ["letzt" + e, ""];
      if (n === -2) return ["vorletzt" + e, ""];
      if (-n <= 5) return [["dritt", "viert", "fünft"][-n - 3]! + "letzt" + e, ""];
      return [`${-n}.-letzt` + e, ""];
    }
    case "it": {
      const o = f ? "a" : "o";
      if (n >= 1 && n <= 5) return [["prim", "second", "terz", "quart", "quint"][n - 1]! + o, ""];
      if (n > 0) return [`${n}${f ? "ª" : "º"}`, ""];
      if (n === -1) return ["ultim" + o, ""];
      if (n === -2) return ["penultim" + o, ""];
      return [ordinal("it", -n, gender, "on")[0], " dalla fine"];
    }
    case "nl": {
      if (n >= 1 && n <= 5) return [["eerste", "tweede", "derde", "vierde", "vijfde"][n - 1]!, ""];
      if (n > 0) return [`${n}e`, ""];
      if (n === -1) return ["laatste", ""];
      if (n === -2) return ["voorlaatste", ""];
      return [ordinal("nl", -n, "m", "on")[0], " van achteren"];
    }
  }
}

function numeralEn(n: number): string {
  const suffix = n % 100 >= 11 && n % 100 <= 13 ? "th" : n % 10 === 1 ? "st" : n % 10 === 2 ? "nd" : n % 10 === 3 ? "rd" : "th";
  return `${n}${suffix}`;
}

// An article (and preposition) before an ordinal.
function article(lang: Exclude<Lang, "ja">, gender: Gender, context: Context, word: string): string {
  const f = gender === "f";
  switch (lang) {
    case "en":
      return "the ";
    case "pt":
      return context === "on" ? (f ? "na " : "no ") : f ? "a " : "o ";
    case "es":
      return f ? "la " : "el ";
    case "fr":
      return /^[aeiouéè]/u.test(word) ? "l'" : f ? "la " : "le ";
    case "de":
      return context === "on" ? "am " : "der ";
    case "it":
      return /^([aeiou]|8|11\D)/u.test(word) ? "l'" : f ? "la " : "il ";
    case "nl":
      return "de ";
  }
}

type Noun = number | "weekday" | "day";

const WEEKDAY_NOUN: Record<Exclude<Lang, "ja">, string> = {
  en: "weekday",
  pt: "dia útil",
  es: "día laborable",
  fr: "jour ouvré",
  de: "Arbeitstag",
  it: "giorno lavorativo",
  nl: "werkdag",
};

const DAY_NOUN: Record<Exclude<Lang, "ja">, string> = { en: "day", pt: "dia", es: "día", fr: "jour", de: "Tag", it: "giorno", nl: "dag" };

function gender(lang: Lang, day: number): Gender {
  if (lang === "pt" && day <= 5) return "f";
  if (lang === "it" && day === 7) return "f";
  return "m";
}

function positionJa(n: number): string {
  if (n === 1) return "最初";
  if (n === -1) return "最後";
  return n > 0 ? `${n}番目` : `最後から${-n}番目`;
}

// "The first Monday", or a noun: the day, a weekday (Monday to Friday).
function nth(lang: Lang, n: number, noun: Noun, context: Context): string {
  if (lang === "ja") {
    if (typeof noun === "number") {
      const name = WEEKDAYS.ja[noun - 1]!;
      if (n > 0) return `第${n}${name}`;
      if (n === -1) return "最終" + name;
      return `最後から${-n}番目の${name}`;
    }
    return positionJa(n) + "の" + (noun === "weekday" ? "平日" : "日");
  }
  const name = typeof noun === "number" ? WEEKDAYS[lang][noun - 1]! : noun === "weekday" ? WEEKDAY_NOUN[lang] : DAY_NOUN[lang];
  const g = typeof noun === "number" ? gender(lang, noun) : "m";
  const [word, tail] = ordinal(lang, n, g, context);
  return article(lang, g, context, word) + word + " " + name + tail;
}

// A weekday of BYDAY, after "on" or as the subject of "it is".
function dayText(lang: Lang, entry: ByDay, context: Context): string {
  if (entry.ordinal !== null) return nth(lang, entry.ordinal, entry.weekday, context);
  const name = WEEKDAYS[lang][entry.weekday - 1]!;
  const f = gender(lang, entry.weekday) === "f";
  const on = context === "on";
  switch (lang) {
    case "en":
      return on ? name : "a " + name;
    case "pt":
      return (on ? (f ? "à " : "ao ") : f ? "uma " : "um ") + name;
    case "es":
      return on ? "el " + name : name;
    case "fr":
      return (on ? "le " : "un ") + name;
    case "de":
      return (on ? "am " : "ein ") + name;
    case "it":
      return (on ? (f ? "la " : "il ") : f ? "una " : "un ") + name;
    case "nl":
      return on ? name : "een " + name;
    case "ja":
      return name;
  }
}

function monthDay(lang: Lang, n: number): string {
  if (n < 0) return lang === "ja" && n === -1 ? "末日" : nth(lang, n, "day", "on");
  switch (lang) {
    case "ja":
      return `${n}日`;
    case "en":
      return "the " + numeralEn(n);
    case "pt":
      return `no dia ${n}`;
    case "es":
      return `el día ${n}`;
    case "fr":
      return n === 1 ? "le 1er" : `le ${n}`;
    case "de":
      return `am ${n}.`;
    case "it":
      return `il giorno ${n}`;
    case "nl":
      return `de ${n}e`;
  }
}

const WEEKDAYS_PHRASE: Record<Lang, string> = {
  en: "on weekdays",
  pt: "de segunda a sexta-feira",
  es: "de lunes a viernes",
  fr: "du lundi au vendredi",
  de: "von Montag bis Freitag",
  it: "dal lunedì al venerdì",
  nl: "op werkdagen",
  ja: "平日",
};

function dayFr(day: number): string {
  return day === 1 ? "1er" : String(day);
}

function dayIt(day: number, art: string, elided: string): string {
  if (day === 1) return art + "1º";
  if (day === 8 || day === 11) return elided + day;
  return art + day;
}

// A day and month, without the year, after the frequency.
function dateText(lang: Lang, month: number, day: number): string {
  const name = MONTHS[lang][month - 1]!;
  switch (lang) {
    case "en":
      return `on ${day} ${name}`;
    case "pt":
      return `a ${day} de ${name}`;
    case "es":
      return `el ${day} de ${name}`;
    case "fr":
      return `le ${dayFr(day)} ${name}`;
    case "de":
      return `am ${day}. ${name}`;
    case "it":
      return dayIt(day, "il ", "l'") + " " + name;
    case "nl":
      return `op ${day} ${name}`;
    case "ja":
      return `${name}${day}日`;
  }
}

function monthsText(lang: Lang, names: string[]): string {
  const list = join(lang, names, "and");
  switch (lang) {
    case "en":
    case "nl":
      return "in " + list;
    case "pt":
      return "em " + list;
    case "es":
    case "fr":
      return "en " + list;
    case "de":
      return "im " + list;
    case "it":
      return (list.startsWith("a") ? "ad " : "a ") + list;
    case "ja":
      return list;
  }
}

const OF_YEAR: Record<Lang, string> = {
  en: " of the year",
  pt: " do ano",
  es: " del año",
  fr: " de l'année",
  de: " des Jahres",
  it: " dell'anno",
  nl: " van het jaar",
  ja: "",
};

const OF_MONTH: Record<Lang, string> = {
  en: " of every month",
  pt: " de cada mês",
  es: " de cada mes",
  fr: " de chaque mois",
  de: " jedes Monats",
  it: " di ogni mese",
  nl: " van elke maand",
  ja: "",
};

function limitText(lang: Lang, text: string): string {
  switch (lang) {
    case "en":
      return ", if it is " + text;
    case "pt":
      return ", se for " + text;
    case "es":
      return ", si es " + text;
    case "fr":
      return ", si c'est " + text;
    case "de":
      return ", wenn es " + text + " ist";
    case "it":
      return ", se è " + text;
    case "nl":
      return ", als het " + text + " is";
    case "ja":
      return "（" + text + "の場合）";
  }
}

// BYSETPOS other than "the last weekday": the positions in each period.
function positionsText(lang: Lang, list: number[], freq: Freq): string {
  const i = FREQ_INDEX[freq];
  if (lang === "ja") {
    return `（各${["日", "週", "月", "年"][i]}の` + join("ja", list.map(positionJa), "and") + "）";
  }
  const text = join(
    lang,
    list.map((n) => {
      const [word, tail] = ordinal(lang, n, "f", "subject");
      return article(lang, "f", "subject", word) + word + tail;
    }),
    "and",
  );
  switch (lang) {
    case "en":
      return ` (${text} of each ${["day", "week", "month", "year"][i]})`;
    case "pt":
      return ` (${text} de cada ${["dia", "semana", "mês", "ano"][i]})`;
    case "es":
      return ` (${text} de cada ${["día", "semana", "mes", "año"][i]})`;
    case "fr":
      return ` (${text} de chaque ${["jour", "semaine", "mois", "année"][i]})`;
    case "de":
      return ` (jeweils ${text} Termin ${["am Tag", "in der Woche", "im Monat", "im Jahr"][i]})`;
    case "it":
      return ` (${text} di ogni ${["giorno", "settimana", "mese", "anno"][i]})`;
    case "nl":
      return ` (${text} van ${["elke dag", "elke week", "elke maand", "elk jaar"][i]})`;
  }
}

function endingText(lang: Lang, rule: Rule): string {
  if (rule.count !== null) {
    const n = rule.count;
    const once = n === 1;
    switch (lang) {
      case "en":
        return once ? ", once" : `, ${n} times`;
      case "pt":
        return once ? ", uma vez" : `, ${n} vezes`;
      case "es":
        return once ? ", una vez" : `, ${n} veces`;
      case "fr":
        return once ? ", une fois" : `, ${n} fois`;
      case "de":
        return once ? ", einmal" : `, ${n}-mal`;
      case "it":
        return once ? ", una volta" : `, ${n} volte`;
      case "nl":
        return once ? ", één keer" : `, ${n} keer`;
      case "ja":
        return `、${n}回`;
    }
  }
  const day = rule.until === null ? null : untilDay(rule.until);
  if (day === null) return "";
  const { year: y, month, day: d } = toYMD(day);
  const name = MONTHS[lang][month - 1]!;
  switch (lang) {
    case "en":
      return ` until ${d} ${name} ${y}`;
    case "pt":
      return ` até ${d} de ${name} de ${y}`;
    case "es":
      return ` hasta el ${d} de ${name} de ${y}`;
    case "fr":
      return ` jusqu'au ${dayFr(d)} ${name} ${y}`;
    case "de":
      return ` bis zum ${d}. ${name} ${y}`;
    case "it":
      return " fino " + dayIt(d, "al ", "all'") + ` ${name} ${y}`;
    case "nl":
      return ` tot en met ${d} ${name} ${y}`;
    case "ja":
      return `、${y}年${name}${d}日まで`;
  }
}

