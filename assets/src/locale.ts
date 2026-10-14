// What the picker needs to know about a locale and a calendar system, read
// from Intl (the CLDR data built into the browser), with small built-in
// tables where an engine lacks an API.
//
// Days are the integer days of iso.ts. JavaScript Dates appear only as the
// input of Intl formatters, built from `day * 86400000` and formatted with
// `timeZone: "UTC"`, so the browser's own zone never moves a day.
//
// Week numbers are always ISO 8601 weeks (iso.ts `isoWeek`), whatever the
// locale or calendar system.

import {
  type Day,
  addMonths as isoAddMonths,
  daysInMonth,
  formatISO,
  formatMonth,
  fromYMD,
  isValidYMD,
  isoWeek,
  type ISOWeek,
  startOfMonth,
  toYMD,
} from "./iso";

const DAY_MS = 86_400_000;

function utc(day: Day): Date {
  return new Date(day * DAY_MS);
}

// Formatters and locale objects are slow to build; every one is cached.

const formats = new Map<string, Intl.DateTimeFormat>();

function dateFormat(locale: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const key = locale + "\u0000" + JSON.stringify(options);
  let format = formats.get(key);
  if (!format) {
    format = new Intl.DateTimeFormat(locale, { timeZone: "UTC", ...options });
    formats.set(key, format);
  }
  return format;
}

const numberFormats = new Map<string, Intl.NumberFormat>();

function numberFormat(locale: string, minDigits: number): Intl.NumberFormat {
  const key = locale + "\u0000" + minDigits;
  let format = numberFormats.get(key);
  if (!format) {
    format = new Intl.NumberFormat(locale, { useGrouping: false, minimumIntegerDigits: Math.max(1, Math.min(21, minDigits)) });
    numberFormats.set(key, format);
  }
  return format;
}

const locales = new Map<string, Intl.Locale>();

/** The Intl.Locale of a tag, or of "en" when the tag is not valid. */
function intlLocale(locale: string): Intl.Locale {
  let value = locales.get(locale);
  if (!value) {
    try {
      value = new Intl.Locale(locale);
    } catch {
      value = new Intl.Locale("en");
    }
    locales.set(locale, value);
  }
  return value;
}

/** A tag Intl accepts: the given one, or "en". */
function safe(locale: string): string {
  return intlLocale(locale).toString();
}

function region(locale: string): string {
  const value = intlLocale(locale);
  return (value.region ?? value.maximize().region ?? "US").toUpperCase();
}

function language(locale: string): string {
  return intlLocale(locale).language.toLowerCase();
}

/** The value of a `-u-<key>-` extension of a tag, if any. */
function unicodeExtension(locale: string, key: string): string | undefined {
  const lower = locale.toLowerCase();
  const start = lower.indexOf("-u-");
  if (start < 0) return undefined;
  const subtags = lower.slice(start + 3).split("-");
  for (let i = 0; i < subtags.length; i++) {
    const tag = subtags[i]!;
    if (tag.length === 1) return undefined; // another singleton (-x-, -t-) ends the extension
    if (tag === key) return subtags[i + 1];
  }
  return undefined;
}

// Weeks.

export interface WeekInfo {
  /** ISO weekday the week starts on: 1 Monday to 7 Sunday. */
  firstDay: number;
  /** ISO weekdays of the weekend. */
  weekend: number[];
  /** Days the first week of a year must have in that year. */
  minimalDays: number;
}

// CLDR weekData, by region, for engines without Intl.Locale#getWeekInfo.
const SUNDAY_FIRST = new Set(
  (
    "AG AS BD BR BS BT BW BZ CA CO DM DO ET GT GU HK HN ID IL IN JM JP KE KH KR LA MH MM MO MT MX MZ NI NP " +
    "PA PE PH PK PR PT PY SA SG SV TH TT TW UM US VE VI WS YE ZA ZW"
  ).split(" "),
);
const SATURDAY_FIRST = new Set("AF BH DJ DZ EG IQ IR JO KW LY OM QA SD SY".split(" "));
const FRIDAY_FIRST = new Set(["MV"]);
const FRIDAY_SATURDAY_WEEKEND = new Set("BH DZ EG IL IQ JO KW LY OM QA SA SD SY YE".split(" "));
const MINIMAL_DAYS_4 = new Set(
  (
    "AD AN AT AX BE BG CH CZ DE DK EE ES FI FJ FO FR GB GF GG GI GP GR HU IE IM IS IT JE LI LT LU MC MQ NL NO " +
    "PL PT RE RU SE SJ SK SM VA"
  ).split(" "),
);
const FW: Record<string, number> = { mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6, sun: 7 };

function weekTable(code: string): WeekInfo {
  const firstDay = SUNDAY_FIRST.has(code) ? 7 : SATURDAY_FIRST.has(code) ? 6 : FRIDAY_FIRST.has(code) ? 5 : 1;
  let weekend = [6, 7];
  if (FRIDAY_SATURDAY_WEEKEND.has(code)) weekend = [5, 6];
  else if (code === "AF") weekend = [4, 5];
  else if (code === "IR") weekend = [5];
  else if (code === "IN" || code === "UG") weekend = [7];
  return { firstDay, weekend, minimalDays: MINIMAL_DAYS_4.has(code) ? 4 : 1 };
}

interface WeekInfoLocale {
  getWeekInfo?: () => WeekInfo;
  weekInfo?: WeekInfo;
}

const weekInfos = new Map<string, WeekInfo>();

/** First day of the week, weekend and minimal days of a locale (`-u-fw-` overrides the first day). */
export function weekInfo(locale: string): WeekInfo {
  let info = weekInfos.get(locale);
  if (info) return info;
  const value = intlLocale(locale) as Intl.Locale & WeekInfoLocale;
  let found: WeekInfo | undefined;
  try {
    found = typeof value.getWeekInfo === "function" ? value.getWeekInfo() : value.weekInfo;
  } catch {
    found = undefined;
  }
  info = found
    ? { firstDay: found.firstDay, weekend: [...found.weekend], minimalDays: found.minimalDays }
    : weekTable(region(locale));
  const fw = FW[unicodeExtension(locale, "fw") ?? ""];
  if (fw) info.firstDay = fw;
  weekInfos.set(locale, info);
  return info;
}

/** ISO week of a day; week numbers are ISO 8601 for every locale and calendar. */
export function weekNumber(day: Day): ISOWeek {
  return isoWeek(day);
}

// 1970-01-05 was a Monday.
const MONDAY: Day = 4;

/** The names of the seven weekdays, in display order from `firstDay` (ISO, 1 to 7). */
export function weekdayNames(locale: string, style: "narrow" | "short" | "long" = "short", firstDay = weekInfo(locale).firstDay): string[] {
  const format = dateFormat(safe(locale), { weekday: style });
  const names: string[] = [];
  for (let i = 0; i < 7; i++) names.push(format.format(utc(MONDAY + ((firstDay - 1 + i) % 7))));
  return names;
}

// Times.

export type HourCycle = "h11" | "h12" | "h23" | "h24";

const HOUR_CYCLES = new Set(["h11", "h12", "h23", "h24"]);

/** The hour cycle a locale writes times in (honours `-u-hc-`). */
export function hourCycle(locale: string): HourCycle {
  const hc = unicodeExtension(locale, "hc");
  if (hc && HOUR_CYCLES.has(hc)) return hc as HourCycle;
  const options = dateFormat(safe(locale), { hour: "numeric" }).resolvedOptions();
  if (options.hourCycle && HOUR_CYCLES.has(options.hourCycle)) return options.hourCycle;
  return options.hour12 ? "h12" : "h23";
}

export type DateField = "year" | "month" | "day";
export type TimeField = "hour" | "minute" | "second" | "dayPeriod";
export type FieldPart<F extends string> = { field: F } | { literal: string };

function fieldOrder<F extends string>(parts: Intl.DateTimeFormatPart[], fields: Record<string, F>): FieldPart<F>[] {
  const order: FieldPart<F>[] = [];
  for (const part of parts) {
    const field = fields[part.type];
    if (field) {
      if (!order.some((item) => "field" in item && item.field === field)) order.push({ field });
      continue;
    }
    if (part.type !== "literal") continue;
    const last = order[order.length - 1];
    if (last && "literal" in last) last.literal += part.value;
    else order.push({ literal: part.value });
  }
  return order;
}

const DATE_FIELDS: Record<string, DateField> = { year: "year", relatedYear: "year", month: "month", day: "day" };

/** The order of the numeric date fields of a locale and the literals between them (`15/03/2027` → day / month / year). */
export function dateFieldOrder(locale: string, calendar = "gregory"): FieldPart<DateField>[] {
  const format = dateFormat(safe(locale), { calendar, year: "numeric", month: "2-digit", day: "2-digit" });
  return fieldOrder(format.formatToParts(utc(fromYMD(2027, 3, 15))), DATE_FIELDS);
}

const TIME_FIELDS: Record<string, TimeField> = { hour: "hour", minute: "minute", second: "second", dayPeriod: "dayPeriod" };

/** The order of the time fields of a locale (hour, minute, second, day period) and the literals between them. */
export function timeFieldOrder(locale: string, options: { seconds?: boolean; hourCycle?: HourCycle } = {}): FieldPart<TimeField>[] {
  const format = dateFormat(safe(locale), {
    hour: "numeric",
    minute: "2-digit",
    ...(options.seconds ? { second: "2-digit" } : {}),
    hourCycle: options.hourCycle ?? hourCycle(locale),
  });
  return fieldOrder(format.formatToParts(new Date(Date.UTC(2027, 2, 15, 21, 5, 9))), TIME_FIELDS);
}

export interface DayPeriods {
  am: string;
  pm: string;
}

/** The locale's words for the morning and afternoon halves of a 12-hour clock. */
export function dayPeriods(locale: string): DayPeriods {
  const format = dateFormat(safe(locale), { hour: "numeric", hourCycle: "h12" });
  const period = (hour: number) =>
    format.formatToParts(new Date(Date.UTC(2027, 2, 15, hour))).find((part) => part.type === "dayPeriod")?.value;
  return { am: period(9) ?? "AM", pm: period(21) ?? "PM" };
}

export interface FieldPlaceholders {
  day: string;
  month: string;
  year: string;
  hour: string;
  minute: string;
  second: string;
  dayPeriod: string;
}

const PLACEHOLDERS: Record<string, [day: string, month: string, year: string]> = {
  en: ["dd", "mm", "yyyy"],
  pt: ["dd", "mm", "aaaa"],
  es: ["dd", "mm", "aaaa"],
  fr: ["jj", "mm", "aaaa"],
  de: ["TT", "MM", "JJJJ"],
  it: ["gg", "mm", "aaaa"],
  nl: ["dd", "mm", "jjjj"],
  ja: ["日", "月", "年"],
  zh: ["日", "月", "年"],
  ko: ["일", "월", "년"],
};

/** What empty date and time fields show while a person types (`dd/mm/yyyy`, `jj/mm/aaaa`). */
export function fieldPlaceholders(locale: string): FieldPlaceholders {
  const [day, month, year] = PLACEHOLDERS[language(locale)] ?? ["––", "––", "––––"];
  return { day, month, year, hour: "––", minute: "––", second: "––", dayPeriod: dayPeriods(locale).am };
}

export interface FieldNames {
  era: string;
  year: string;
  month: string;
  day: string;
  hour: string;
  minute: string;
  second: string;
  dayPeriod: string;
  weekOfYear: string;
  weekday: string;
}

const ENGLISH_FIELD_NAMES: FieldNames = {
  era: "era",
  year: "year",
  month: "month",
  day: "day",
  hour: "hour",
  minute: "minute",
  second: "second",
  dayPeriod: "AM/PM",
  weekOfYear: "week",
  weekday: "day of the week",
};

/** The locale's names of the date and time fields, for labels read by assistive technology. */
export function fieldNames(locale: string): FieldNames {
  const names = { ...ENGLISH_FIELD_NAMES };
  try {
    const display = new Intl.DisplayNames(safe(locale), { type: "dateTimeField" } as Intl.DisplayNamesOptions);
    for (const key of Object.keys(names) as (keyof FieldNames)[]) {
      const name = display.of(key);
      if (name) names[key] = name;
    }
  } catch {
    // An engine without dateTimeField display names keeps the English ones.
  }
  return names;
}

// Numbers.

/** An integer in the locale's numbering system (`-u-nu-` honoured), padded to `minDigits`, without grouping. */
export function formatNumber(n: number, locale: string, minDigits = 1): string {
  return numberFormat(safe(locale), minDigits).format(n);
}

const zeros = new Map<number, number>();
const DIGIT = /\p{Nd}/u;

function digitZero(code: number): number {
  let zero = zeros.get(code);
  if (zero !== undefined) return zero;
  // Unicode encodes every set of decimal digits as a contiguous run 0 to 9,
  // and runs that touch are whole sets, so the zero is found from the start
  // of the run.
  let start = code;
  while (start > 0 && DIGIT.test(String.fromCodePoint(start - 1))) start--;
  zero = start + Math.floor((code - start) / 10) * 10;
  zeros.set(code, zero);
  return zero;
}

/** Turns every Unicode decimal digit (Arabic-Indic, Persian, Devanagari, full-width…) into ASCII; other characters are kept. */
export function parseDigits(text: string): string {
  let out = "";
  for (const char of text) {
    const code = char.codePointAt(0)!;
    if (code >= 0x30 && code <= 0x39) out += char;
    else if (code > 0x7f && DIGIT.test(char)) out += String(code - digitZero(code));
    else out += char;
  }
  return out;
}

// Direction.

const RTL_SCRIPTS = new Set(["Arab", "Hebr", "Thaa", "Syrc", "Nkoo", "Adlm", "Rohg", "Mand", "Samr", "Mend", "Yezi"]);
const RTL_LANGUAGES = new Set(["ar", "he", "iw", "fa", "ur", "ps", "yi", "ji", "dv", "ckb", "sd", "ug", "syr", "ku", "lrc", "mzn", "glk", "ks"]);

/** True when the locale is written right to left. */
export function rtl(locale: string): boolean {
  const value = intlLocale(locale) as Intl.Locale & { getTextInfo?: () => { direction?: string }; textInfo?: { direction?: string } };
  // A script written in the locale decides; then the language tables,
  // since an engine with older CLDR data says "ltr" for a language it does
  // not know (Dhivehi in Node 20); then the engine; then the likely script.
  if (value.script) return RTL_SCRIPTS.has(value.script);
  if (RTL_LANGUAGES.has(value.language)) return true;
  try {
    const info = typeof value.getTextInfo === "function" ? value.getTextInfo() : value.textInfo;
    if (info?.direction) return info.direction === "rtl";
  } catch {
    // Fall through to the script.
  }
  const script = value.maximize().script;
  return script ? RTL_SCRIPTS.has(script) : false;
}

// Relative labels.

const relativeFormats = new Map<string, Intl.RelativeTimeFormat>();

/** "today", "tomorrow", "in 30 days", "next week"… in the locale. */
export function relativeLabel(locale: string, n: number, unit: Intl.RelativeTimeFormatUnit): string {
  const key = safe(locale);
  let format = relativeFormats.get(key);
  if (!format) {
    try {
      format = new Intl.RelativeTimeFormat(key, { numeric: "auto" });
    } catch {
      return `${n} ${unit}`;
    }
    relativeFormats.set(key, format);
  }
  return format.format(n, unit);
}

// Calendar systems.

export type CalendarId =
  | "gregory"
  | "iso8601"
  | "buddhist"
  | "japanese"
  | "roc"
  | "persian"
  | "islamic"
  | "islamic-umalqura"
  | "islamic-civil"
  | "islamic-tbla"
  | "hebrew"
  | "chinese"
  | "dangi"
  | "indian"
  | "ethiopic"
  | "coptic";

export const CALENDAR_IDS: readonly CalendarId[] = [
  "gregory",
  "iso8601",
  "buddhist",
  "japanese",
  "roc",
  "persian",
  "islamic",
  "islamic-umalqura",
  "islamic-civil",
  "islamic-tbla",
  "hebrew",
  "chinese",
  "dangi",
  "indian",
  "ethiopic",
  "coptic",
];

const GREGORIAN_LIKE = new Set<CalendarId>(["gregory", "iso8601", "buddhist", "japanese", "roc"]);

export interface CalMonth {
  /** The first day of the month. */
  start: Day;
  /** Its number of days. */
  length: number;
  /** Tells months apart within a calendar system (era, year and month). */
  key: string;
  /** Month and year as the locale writes them: "March 2027", "Adar II 5787", "令和9年3月". */
  label: string;
  /** The month's name alone. */
  monthLabel: string;
  /** The year alone. */
  yearLabel: string;
}

export interface CalYear {
  start: Day;
  /** The last day of the year. */
  end: Day;
  label: string;
  /** The months of the calendar year, 12 or 13 (Hebrew leap years, Chinese leap months, Ethiopic Pagume). */
  months: CalMonth[];
}

export interface CalFields {
  /** Only for japanese (meiji … reiwa, ce/bce before Meiji) and roc (roc/broc); `year` is then the year of the era. */
  era?: string;
  year: number;
  /** The month's position in its year, from 1 (Adar II is 7 in a Hebrew leap year). */
  month: number;
  /** Temporal's month code: M01 … M13, with L for a leap month (M05L is Adar I, M06L a leap sixth Chinese month). */
  monthCode: string;
  day: number;
}

export interface FieldsInput {
  era?: string;
  year: number;
  month?: number;
  monthCode?: string;
  day: number;
}

export type DateStyle = "short" | "medium" | "long" | "full";

export interface CalendarSystem {
  readonly id: CalendarId;
  readonly locale: string;
  /** Months line up with Gregorian months (gregory, iso8601, buddhist, roc, japanese). */
  readonly isGregorianLike: boolean;
  /** True when this system answers fields and fromFields through Temporal. */
  readonly usesTemporal: boolean;
  monthOf(day: Day): CalMonth;
  nextMonth(month: CalMonth): CalMonth;
  prevMonth(month: CalMonth): CalMonth;
  /** Adds months in this calendar, keeping the day of the month, else the month's last day. */
  addMonths(day: Day, months: number): Day;
  yearOf(day: Day): CalYear;
  /** The day of the month in the locale's digits ("15", "١٥"), number only. */
  dayNumber(day: Day): string;
  format(day: Day, style?: DateStyle): string;
  formatParts(day: Day, style?: DateStyle): Intl.DateTimeFormatPart[];
  formatRange(a: Day, b: Day, style?: DateStyle): string;
  fields(day: Day): CalFields;
  /** The day of a date in this calendar, or null when it does not exist. */
  fromFields(fields: FieldsInput): Day | null;
  /** ISO 8601 week, for every calendar. */
  weekNumber(day: Day): ISOWeek;
}

export interface CalendarOptions {
  /** Use Temporal when the browser has it (default true). False forces the Intl search, for tests. */
  temporal?: boolean;
}

// The few members of Temporal this module uses.
interface TemporalDate {
  readonly year: number;
  readonly month: number;
  readonly monthCode: string;
  readonly day: number;
  readonly era?: string | undefined;
  readonly eraYear?: number | undefined;
  withCalendar(calendar: string): TemporalDate;
}

interface TemporalNamespace {
  PlainDate: {
    from(item: string | Record<string, unknown>, options?: { overflow?: "constrain" | "reject" }): TemporalDate;
  };
}

function temporalNamespace(): TemporalNamespace | undefined {
  return (globalThis as { Temporal?: TemporalNamespace }).Temporal;
}

/** The calendar a locale asks for with `-u-ca-`, else gregory. */
export function localeCalendar(locale: string): CalendarId {
  const calendar = intlLocale(locale).calendar ?? unicodeExtension(locale, "ca");
  if (calendar === "gregorian") return "gregory";
  if (calendar === "ethiopic-amete-alem") return "ethiopic";
  return calendar && (CALENDAR_IDS as readonly string[]).includes(calendar) ? (calendar as CalendarId) : "gregory";
}

/** True when the browser formats this calendar (else calendarSystem falls back to gregory). */
export function supportsCalendar(id: string): boolean {
  try {
    return new Intl.DateTimeFormat("en", { calendar: id, timeZone: "UTC" }).resolvedOptions().calendar === id;
  } catch {
    return false;
  }
}

const systems = new Map<string, CalendarSystem>();

/** The calendar system of a locale: `calendarId`, else the locale's `-u-ca-`, else gregory. */
export function calendarSystem(locale: string, calendarId?: CalendarId | string | null, options: CalendarOptions = {}): CalendarSystem {
  const tag = safe(locale);
  let id = (calendarId ?? localeCalendar(locale)) as CalendarId;
  if (!(CALENDAR_IDS as readonly string[]).includes(id) || (id !== "gregory" && !supportsCalendar(id))) id = "gregory";
  const temporal = options.temporal !== false && !GREGORIAN_LIKE.has(id) && temporalSupports(id);
  const key = `${tag}|${id}|${temporal}`;
  let system = systems.get(key);
  if (!system) {
    system = GREGORIAN_LIKE.has(id) ? gregorianSystem(tag, id) : lunisolarSystem(tag, id, temporal);
    systems.set(key, system);
  }
  return system;
}

function temporalSupports(id: CalendarId): boolean {
  const temporal = temporalNamespace();
  if (!temporal) return false;
  try {
    temporal.PlainDate.from("2000-01-01").withCalendar(id);
    return true;
  } catch {
    return false;
  }
}

// What every system shares: labels and formatting.

function labelCalendar(id: CalendarId): string {
  // Intl writes iso8601 months year first ("2027 March"); the picker shows them as gregory.
  return id === "iso8601" ? "gregory" : id;
}

function commonFormatting(locale: string, id: CalendarId) {
  const calendar = labelCalendar(id);
  const styled = (style: DateStyle) => dateFormat(locale, { calendar, dateStyle: style });
  const nu = numberFormat(locale, 1).resolvedOptions().numberingSystem;
  const latn = nu === "latn";
  return {
    label: (day: Day) => dateFormat(locale, { calendar, year: "numeric", month: "long" }).format(utc(day)),
    monthLabel: (day: Day) => dateFormat(locale, { calendar, month: "long" }).format(utc(day)),
    yearLabel: (day: Day) => dateFormat(locale, { calendar, year: "numeric" }).format(utc(day)),
    format: (day: Day, style: DateStyle = "long") => styled(style).format(utc(day)),
    formatParts: (day: Day, style: DateStyle = "long") => styled(style).formatToParts(utc(day)),
    formatRange: (a: Day, b: Day, style: DateStyle = "long") => {
      const format = styled(style) as Intl.DateTimeFormat & { formatRange?: (x: Date, y: Date) => string };
      if (a === b) return format.format(utc(a));
      if (typeof format.formatRange === "function") return format.formatRange(utc(Math.min(a, b)), utc(Math.max(a, b)));
      return `${format.format(utc(Math.min(a, b)))} – ${format.format(utc(Math.max(a, b)))}`;
    },
    dayNumber: (dom: number) => (latn ? String(dom) : numberFormat(locale, 1).format(dom)),
  };
}

// Gregorian-like systems: months straight from iso.ts.

interface JapaneseEra {
  code: string;
  start: Day;
  year: number;
}

const JAPANESE_ERAS: JapaneseEra[] = [
  { code: "reiwa", start: fromYMD(2019, 5, 1), year: 2019 },
  { code: "heisei", start: fromYMD(1989, 1, 8), year: 1989 },
  { code: "showa", start: fromYMD(1926, 12, 25), year: 1926 },
  { code: "taisho", start: fromYMD(1912, 7, 30), year: 1912 },
  { code: "meiji", start: fromYMD(1868, 9, 8), year: 1868 },
];

function monthCode(n: number, leap = false): string {
  return "M" + String(n).padStart(2, "0") + (leap ? "L" : "");
}

function parseMonthCode(code: string | undefined): { n: number; leap: boolean } | null {
  if (code === undefined) return null;
  const match = /^M(\d{2})(L?)$/.exec(code);
  return match ? { n: Number(match[1]), leap: match[2] === "L" } : null;
}

function gregorianSystem(locale: string, id: CalendarId): CalendarSystem {
  const common = commonFormatting(locale, id);
  const months = new Map<Day, CalMonth>();

  const monthOf = (day: Day): CalMonth => {
    const start = startOfMonth(day);
    let month = months.get(start);
    if (!month) {
      const { year, month: m } = toYMD(start);
      month = {
        start,
        length: daysInMonth(year, m),
        key: formatMonth(start),
        label: common.label(start),
        monthLabel: common.monthLabel(start),
        yearLabel: common.yearLabel(start),
      };
      if (months.size > 2000) months.clear();
      months.set(start, month);
    }
    return month;
  };

  const fields = (day: Day): CalFields => {
    const { year, month, day: dom } = toYMD(day);
    const base = { month, monthCode: monthCode(month), day: dom };
    switch (id) {
      case "buddhist":
        return { year: year + 543, ...base };
      case "roc":
        return year >= 1912 ? { era: "roc", year: year - 1911, ...base } : { era: "broc", year: 1912 - year, ...base };
      case "japanese": {
        const era = JAPANESE_ERAS.find((item) => day >= item.start);
        if (era) return { era: era.code, year: year - era.year + 1, ...base };
        return year > 0 ? { era: "ce", year, ...base } : { era: "bce", year: 1 - year, ...base };
      }
      default:
        return { year, ...base };
    }
  };

  const fromFields = (input: FieldsInput): Day | null => {
    const code = parseMonthCode(input.monthCode);
    if (input.monthCode !== undefined && (!code || code.leap)) return null;
    const month = input.month ?? code?.n;
    if (month === undefined || (code && code.n !== month)) return null;
    let year = input.year;
    let range: [Day, Day] | null = null;
    if (id === "buddhist") year -= 543;
    else if (id === "roc") {
      if (input.era === "broc") {
        if (year < 1) return null;
        year = 1912 - year;
      } else year += 1911;
    } else if (id === "japanese") {
      const index = JAPANESE_ERAS.findIndex((item) => item.code === input.era);
      if (index >= 0) {
        if (year < 1) return null;
        const era = JAPANESE_ERAS[index]!;
        year = era.year + year - 1;
        range = [era.start, index > 0 ? JAPANESE_ERAS[index - 1]!.start : Infinity];
      } else if (input.era === "bce") year = 1 - year;
      else if (input.era !== undefined && input.era !== "ce") return null;
    }
    if (!isValidYMD(year, month, input.day)) return null;
    const day = fromYMD(year, month, input.day);
    if (range && (day < range[0] || day >= range[1])) return null;
    return day;
  };

  const yearOf = (day: Day): CalYear => {
    const { year } = toYMD(day);
    const start = fromYMD(year, 1, 1);
    const list: CalMonth[] = [];
    for (let m = 1; m <= 12; m++) list.push(monthOf(fromYMD(year, m, 1)));
    return { start, end: fromYMD(year, 12, 31), label: common.yearLabel(start), months: list };
  };

  return {
    id,
    locale,
    isGregorianLike: true,
    usesTemporal: false,
    monthOf,
    nextMonth: (month) => monthOf(month.start + month.length),
    prevMonth: (month) => monthOf(month.start - 1),
    addMonths: (day, n) => isoAddMonths(day, n),
    yearOf,
    dayNumber: (day) => common.dayNumber(toYMD(day).day),
    format: common.format,
    formatParts: common.formatParts,
    formatRange: common.formatRange,
    fields,
    fromFields,
    weekNumber: isoWeek,
  };
}

// Other systems: months found by formatting days in the calendar.

interface Raw {
  era: string;
  year: string;
  month: string;
  dom: number;
}

// Average lengths, to guess where a date falls before correcting the guess.
function averages(id: CalendarId): { year: number; month: number } {
  if (id.startsWith("islamic")) return { year: 354.367, month: 29.5306 };
  if (id === "hebrew" || id === "chinese" || id === "dangi") return { year: 365.2468, month: 29.5306 };
  if (id === "ethiopic" || id === "coptic") return { year: 365.25, month: 30 };
  return { year: 365.2422, month: 30.437 };
}

const HEBREW_MONTHS: Record<string, string> = {
  Tishri: "M01",
  Heshvan: "M02",
  Kislev: "M03",
  Tevet: "M04",
  Shevat: "M05",
  "Adar I": "M05L",
  Adar: "M06",
  "Adar II": "M06",
  Nisan: "M07",
  Iyar: "M08",
  Sivan: "M09",
  Tamuz: "M10",
  Av: "M11",
  Elul: "M12",
};

function hebrewLeap(year: number): boolean {
  return (((7 * year + 1) % 19) + 19) % 19 < 7;
}

// Intl handles dates within ±100,000,000 days of 1970.
const LIMIT = 99_999_000;

function lunisolarSystem(locale: string, id: CalendarId, temporal: boolean): CalendarSystem {
  const common = commonFormatting(locale, id);
  const lunar = id === "chinese" || id === "dangi";
  const parts = new Intl.DateTimeFormat("en-u-nu-latn", {
    calendar: id,
    timeZone: "UTC",
    year: "numeric",
    month: "numeric",
    day: "numeric",
    ...(lunar ? {} : { era: "short" }),
  });
  const raws = new Map<Day, Raw>();
  const months = new Map<Day, CalMonth>();
  const monthYears = new Map<Day, string>(); // month start → year key
  const years = new Map<string, CalYear>();

  const read = (day: Day): Raw => {
    let raw = raws.get(day);
    if (!raw) {
      raw = { era: "", year: "", month: "", dom: 1 };
      for (const part of parts.formatToParts(utc(day))) {
        if (part.type === "era") raw.era = part.value;
        else if (part.type === "year" || (part.type as string) === "relatedYear") raw.year = part.value;
        else if (part.type === "month") raw.month = part.value;
        else if (part.type === "day") raw.dom = Number(parseDigits(part.value));
      }
      if (raws.size > 5000) raws.clear();
      raws.set(day, raw);
    }
    return raw;
  };

  const yearKey = (raw: Raw) => `${raw.era}|${raw.year}`;

  const monthOf = (day: Day): CalMonth => {
    const raw = read(day);
    const start = day - (raw.dom - 1);
    let month = months.get(start);
    if (!month) {
      // 32 days on lands in the next month for every length from 5 (Pagume) to 31.
      const probe = start + 32;
      const next = probe - (read(probe).dom - 1);
      month = {
        start,
        length: next - start,
        key: `${id}|${raw.era}|${raw.year}|${raw.month}`,
        label: common.label(start),
        monthLabel: common.monthLabel(start),
        yearLabel: common.yearLabel(start),
      };
      if (months.size > 2000) {
        months.clear();
        monthYears.clear();
      }
      months.set(start, month);
      monthYears.set(start, yearKey(raw));
    }
    return month;
  };

  const nextMonth = (month: CalMonth) => monthOf(month.start + month.length);
  const prevMonth = (month: CalMonth) => monthOf(month.start - 1);

  const yearKeyOf = (month: CalMonth): string => monthYears.get(month.start) ?? yearKey(read(month.start));

  const yearOf = (day: Day): CalYear => {
    const month = monthOf(day);
    const key = yearKeyOf(month);
    let year = years.get(key);
    if (year) return year;
    let first = month;
    for (let i = 0; i < 14; i++) {
      const prev = prevMonth(first);
      if (yearKeyOf(prev) !== key) break;
      first = prev;
    }
    const list = [first];
    for (let i = 0; i < 14; i++) {
      const next = nextMonth(list[list.length - 1]!);
      if (yearKeyOf(next) !== key) break;
      list.push(next);
    }
    const last = list[list.length - 1]!;
    year = { start: first.start, end: last.start + last.length - 1, label: common.yearLabel(first.start), months: list };
    if (years.size > 500) years.clear();
    years.set(key, year);
    return year;
  };

  // The month's position in its year and its Temporal month code.
  const position = (month: CalMonth): { ordinal: number; code: string } => {
    const raw = read(month.start);
    if (id === "hebrew") {
      const code = HEBREW_MONTHS[raw.month];
      if (code) {
        const n = Number(code.slice(1, 3));
        const leapYear = hebrewLeap(Number(raw.year));
        return { ordinal: leapYear && (n >= 6 || code === "M05L") ? n + 1 : n, code };
      }
    } else if (!lunar) {
      const n = Number(raw.month);
      if (Number.isInteger(n) && n > 0) return { ordinal: n, code: monthCode(n) };
    }
    const ordinal = yearOf(month.start).months.findIndex((item) => item.start === month.start) + 1;
    if (lunar) {
      const leap = /bis$/.test(raw.month);
      const n = parseInt(raw.month, 10);
      return { ordinal, code: monthCode(Number.isInteger(n) ? n : ordinal, leap) };
    }
    return { ordinal, code: monthCode(ordinal) };
  };

  const yearNumber = (month: CalMonth): number => Number(read(month.start).year);

  const intlFields = (day: Day): CalFields => {
    const month = monthOf(day);
    const { ordinal, code } = position(month);
    return { year: yearNumber(month), month: ordinal, monthCode: code, day: day - month.start + 1 };
  };

  // The month at (year, ordinal), found from an estimate and corrected a month at a time.
  let anchor: { day: Day; fields: CalFields } | null = null;
  const average = averages(id);

  const locateMonth = (year: number, ordinal: number): CalMonth | null => {
    if (!Number.isInteger(year) || !Number.isInteger(ordinal) || ordinal < 1 || ordinal > 13) return null;
    if (!anchor) {
      const day = fromYMD(2000, 1, 1);
      anchor = { day, fields: intlFields(day) };
    }
    const guess = Math.round(
      anchor.day + (year - anchor.fields.year) * average.year + (ordinal - anchor.fields.month) * average.month - (anchor.fields.day - 15),
    );
    if (!(guess > -LIMIT && guess < LIMIT)) return null;
    let month = monthOf(guess);
    let direction = 0;
    for (let i = 0; i < 400; i++) {
      const y = yearNumber(month);
      const o = y === year ? position(month).ordinal : 0;
      const compare = y !== year ? Math.sign(y - year) : Math.sign(o - ordinal);
      if (compare === 0) return month;
      const step = -compare;
      if (direction !== 0 && step !== direction) return null; // stepped past it: no such month
      direction = step;
      // Far from it, jump by about a year.
      if (Math.abs(y - year) > 1) {
        const jump = Math.round((year - y) * average.year);
        const target = month.start + jump;
        if (!(target > -LIMIT && target < LIMIT)) return null;
        month = monthOf(target);
        direction = 0;
        continue;
      }
      const next = step > 0 ? month.start + month.length : month.start - 1;
      if (!(next > -LIMIT && next < LIMIT)) return null;
      month = monthOf(next);
    }
    return null;
  };

  const searchFromFields = (input: FieldsInput): Day | null => {
    if (!Number.isInteger(input.day) || input.day < 1) return null;
    let month: CalMonth | null = null;
    const code = input.monthCode;
    if (code !== undefined) {
      const parsed = parseMonthCode(code);
      if (!parsed) return null;
      if (id === "hebrew") {
        const leapYear = hebrewLeap(input.year);
        if (parsed.leap && !(parsed.n === 5 && leapYear)) return null;
        if (!parsed.leap && (parsed.n < 1 || parsed.n > 12)) return null;
        month = locateMonth(input.year, parsed.leap ? 6 : leapYear && parsed.n >= 6 ? parsed.n + 1 : parsed.n);
      } else if (lunar) {
        const first = locateMonth(input.year, 1);
        month = first ? (yearOf(first.start).months.find((item) => position(item).code === code) ?? null) : null;
      } else {
        if (parsed.leap) return null;
        month = locateMonth(input.year, parsed.n);
      }
      if (month && input.month !== undefined && position(month).ordinal !== input.month) return null;
    } else if (input.month !== undefined) {
      month = locateMonth(input.year, input.month);
    }
    if (!month || input.day > month.length) return null;
    return month.start + input.day - 1;
  };

  const temporalFields = (day: Day): CalFields => {
    const date = temporalNamespace()!.PlainDate.from(formatISO(day)).withCalendar(id);
    return { year: date.eraYear ?? date.year, month: date.month, monthCode: date.monthCode, day: date.day };
  };

  const temporalFromFields = (input: FieldsInput): Day | null => {
    const item: Record<string, unknown> = { calendar: id, year: input.year, day: input.day };
    if (input.month !== undefined) item.month = input.month;
    if (input.monthCode !== undefined) item.monthCode = input.monthCode;
    try {
      const iso = temporalNamespace()!.PlainDate.from(item, { overflow: "reject" }).withCalendar("iso8601");
      return fromYMD(iso.year, iso.month, iso.day);
    } catch {
      return null;
    }
  };

  return {
    id,
    locale,
    isGregorianLike: false,
    usesTemporal: temporal,
    monthOf,
    nextMonth,
    prevMonth,
    addMonths: (day, n) => {
      let month = monthOf(day);
      const dom = day - month.start + 1;
      for (let i = 0; i < Math.abs(n); i++) month = n > 0 ? nextMonth(month) : prevMonth(month);
      return month.start + Math.min(dom, month.length) - 1;
    },
    yearOf,
    dayNumber: (day) => common.dayNumber(read(day).dom),
    format: common.format,
    formatParts: common.formatParts,
    formatRange: common.formatRange,
    fields: temporal ? temporalFields : intlFields,
    fromFields: temporal ? temporalFromFields : searchFromFields,
    weekNumber: isoWeek,
  };
}
