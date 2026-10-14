// Dates, times and instants as plain numbers, in the ISO calendar.
//
// A day is the number of days since 1970-01-01 (negative before it), so
// that arithmetic is integer arithmetic and no JavaScript Date, with its
// local time zone, takes part. A time of day is a number of seconds since
// midnight. An instant is a number of milliseconds since the epoch, as in
// Date.now(). The server speaks ISO 8601 strings; this module reads and
// writes them.

export type Day = number;
export type Seconds = number;

export interface YMD {
  year: number;
  month: number;
  day: number;
}

const DAY_MS = 86_400_000;

// Days from civil, after Howard Hinnant's algorithm: exact for every year
// of the proleptic Gregorian calendar.
export function fromYMD(year: number, month: number, day: number): Day {
  const y = month <= 2 ? year - 1 : year;
  const era = Math.floor(y / 400);
  const yoe = y - era * 400;
  const mp = (month + 9) % 12;
  const doy = Math.floor((153 * mp + 2) / 5) + day - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146_097 + doe - 719_468;
}

export function toYMD(value: Day): YMD {
  const z = value + 719_468;
  const era = Math.floor(z / 146_097);
  const doe = z - era * 146_097;
  const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36_524) - Math.floor(doe / 146_096)) / 365);
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const day = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const month = mp < 10 ? mp + 3 : mp - 9;
  const year = yoe + era * 400 + (month <= 2 ? 1 : 0);
  return { year, month, day };
}

export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

export function daysInMonth(year: number, month: number): number {
  if (month === 2) return isLeapYear(year) ? 29 : 28;
  return [4, 6, 9, 11].includes(month) ? 30 : 31;
}

/** True when the parts make a real date (no 31 April, no 29 February in 2027). */
export function isValidYMD(year: number, month: number, day: number): boolean {
  return (
    Number.isInteger(year) &&
    Number.isInteger(month) &&
    Number.isInteger(day) &&
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    day <= daysInMonth(year, month)
  );
}

/** The ISO weekday: 1 is Monday, 7 is Sunday. */
export function weekday(value: Day): number {
  // 1970-01-01 was a Thursday (4).
  return ((((value + 3) % 7) + 7) % 7) + 1;
}

export function addDays(value: Day, days: number): Day {
  return value + days;
}

/** Adds months, keeping the day of the month when the month has it, else its last day. */
export function addMonths(value: Day, months: number): Day {
  const { year, month, day } = toYMD(value);
  const index = year * 12 + (month - 1) + months;
  const y = Math.floor(index / 12);
  const m = index - y * 12 + 1;
  return fromYMD(y, m, Math.min(day, daysInMonth(y, m)));
}

export function addYears(value: Day, years: number): Day {
  return addMonths(value, years * 12);
}

export function startOfMonth(value: Day): Day {
  const { year, month } = toYMD(value);
  return fromYMD(year, month, 1);
}

export function endOfMonth(value: Day): Day {
  const { year, month } = toYMD(value);
  return fromYMD(year, month, daysInMonth(year, month));
}

export function startOfYear(value: Day): Day {
  return fromYMD(toYMD(value).year, 1, 1);
}

export function endOfYear(value: Day): Day {
  return fromYMD(toYMD(value).year, 12, 31);
}

/** The first day of the week of `value`, for weeks that start on `firstDay` (ISO, 1 to 7). */
export function startOfWeek(value: Day, firstDay = 1): Day {
  return value - ((weekday(value) - firstDay + 7) % 7);
}

export function endOfWeek(value: Day, firstDay = 1): Day {
  return startOfWeek(value, firstDay) + 6;
}

export function startOfQuarter(value: Day): Day {
  const { year, month } = toYMD(value);
  return fromYMD(year, month - ((month - 1) % 3), 1);
}

export function endOfQuarter(value: Day): Day {
  return addMonths(startOfQuarter(value), 3) - 1;
}

/** Months between the months of two days (`b` minus `a`). */
export function monthDiff(a: Day, b: Day): number {
  const x = toYMD(a);
  const y = toYMD(b);
  return (y.year - x.year) * 12 + (y.month - x.month);
}

export function clamp(value: Day, min: Day | null, max: Day | null): Day {
  if (min !== null && value < min) return min;
  if (max !== null && value > max) return max;
  return value;
}

function pad(value: number, length = 2): string {
  const sign = value < 0 ? "-" : "";
  return sign + String(Math.abs(value)).padStart(length, "0");
}

function padYear(year: number): string {
  if (year >= 0 && year <= 9999) return pad(year, 4);
  return (year < 0 ? "-" : "+") + String(Math.abs(year)).padStart(6, "0");
}

export function formatISO(value: Day): string {
  const { year, month, day } = toYMD(value);
  return `${padYear(year)}-${pad(month)}-${pad(day)}`;
}

/** Reads `YYYY-MM-DD`, or null. */
export function parseISO(text: string | null | undefined): Day | null {
  if (!text) return null;
  const match = /^([+-]\d{6}|\d{4})-(\d{2})-(\d{2})$/.exec(text.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  return isValidYMD(year, month, day) ? fromYMD(year, month, day) : null;
}

/** `YYYY-MM` of the month of `value`. */
export function formatMonth(value: Day): string {
  const { year, month } = toYMD(value);
  return `${padYear(year)}-${pad(month)}`;
}

/** Reads `YYYY-MM` into the first day of the month, or null. */
export function parseMonth(text: string | null | undefined): Day | null {
  if (!text) return null;
  const match = /^(\d{4})-(\d{2})$/.exec(text.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  return month >= 1 && month <= 12 ? fromYMD(year, month, 1) : null;
}

export interface ISOWeek {
  year: number;
  week: number;
}

/** The ISO 8601 week of a day: weeks start on Monday, week 1 holds the year's first Thursday. */
export function isoWeek(value: Day): ISOWeek {
  const thursday = value + (4 - weekday(value));
  const year = toYMD(thursday).year;
  const week = Math.floor((thursday - fromYMD(year, 1, 1)) / 7) + 1;
  return { year, week };
}

export function isoWeeksInYear(year: number): number {
  return isoWeek(fromYMD(year, 12, 28)).week;
}

/** The Monday of an ISO week. */
export function fromISOWeek(year: number, week: number): Day {
  const jan4 = fromYMD(year, 1, 4);
  return startOfWeek(jan4, 1) + (week - 1) * 7;
}

export function formatISOWeek(value: Day): string {
  const { year, week } = isoWeek(value);
  return `${pad(year, 4)}-W${pad(week)}`;
}

/** Reads `YYYY-Www` into the Monday of the week, or null. */
export function parseISOWeek(text: string | null | undefined): Day | null {
  if (!text) return null;
  const match = /^(\d{4})-W(\d{2})$/.exec(text.trim());
  if (!match) return null;
  const year = Number(match[1]);
  const week = Number(match[2]);
  if (week < 1 || week > isoWeeksInYear(year)) return null;
  return fromISOWeek(year, week);
}

// Times of day.

export function timeOf(hour: number, minute: number, second = 0): Seconds {
  return hour * 3600 + minute * 60 + second;
}

export function timeParts(value: Seconds): { hour: number; minute: number; second: number } {
  const hour = Math.floor(value / 3600);
  const minute = Math.floor((value % 3600) / 60);
  return { hour, minute, second: value % 60 };
}

/** `HH:MM`, or `HH:MM:SS` with `seconds`. */
export function formatTime(value: Seconds, seconds = false): string {
  const { hour, minute, second } = timeParts(value);
  return seconds ? `${pad(hour)}:${pad(minute)}:${pad(second)}` : `${pad(hour)}:${pad(minute)}`;
}

/** Reads `HH:MM` or `HH:MM:SS` (fractions of a second are dropped), or null. */
export function parseTime(text: string | null | undefined): Seconds | null {
  if (!text) return null;
  const match = /^(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$/.exec(text.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? 0);
  if (hour > 23 || minute > 59 || second > 59) return null;
  return timeOf(hour, minute, second);
}

// Instants and time zones.

const offsetFormats = new Map<string, Intl.DateTimeFormat>();

function offsetFormat(timeZone: string): Intl.DateTimeFormat {
  let format = offsetFormats.get(timeZone);
  if (!format) {
    format = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "numeric",
      day: "numeric",
      hour: "numeric",
      minute: "numeric",
      second: "numeric",
      era: "short",
    });
    offsetFormats.set(timeZone, format);
  }
  return format;
}

/** True when the browser knows the IANA time zone. */
export function isTimeZone(timeZone: string): boolean {
  try {
    offsetFormat(timeZone);
    return true;
  } catch {
    return false;
  }
}

export interface Local {
  day: Day;
  time: Seconds;
}

/** The wall clock of an instant in a time zone ("UTC" when none is given). */
export function instantToLocal(epochMs: number, timeZone = "UTC"): Local {
  if (timeZone === "UTC" || timeZone === "Etc/UTC") {
    const day = Math.floor(epochMs / DAY_MS);
    return { day, time: Math.floor((epochMs - day * DAY_MS) / 1000) };
  }
  const parts: Record<string, string> = {};
  for (const part of offsetFormat(timeZone).formatToParts(new Date(epochMs))) parts[part.type] = part.value;
  let year = Number(parts.year);
  if (parts.era === "BC" || parts.era === "B") year = 1 - year;
  return {
    day: fromYMD(year, Number(parts.month), Number(parts.day)),
    time: timeOf(Number(parts.hour) % 24, Number(parts.minute), Number(parts.second)),
  };
}

/** The offset of a time zone from UTC at an instant, in minutes (east is positive). */
export function offsetAt(epochMs: number, timeZone = "UTC"): number {
  const local = instantToLocal(epochMs, timeZone);
  const wall = local.day * DAY_MS + local.time * 1000;
  return Math.round((wall - Math.floor(epochMs / 1000) * 1000) / 60_000);
}

export type Disambiguation = "earlier" | "later" | "reject";

export interface Resolved {
  /** The instant, or null for a time that the zone skips and `reject`. */
  epochMs: number | null;
  offset: number;
  /** `gap`: the clocks skip this time (spring forward); `ambiguous`: it happens twice (fall back). */
  status: "ok" | "gap" | "ambiguous";
}

/**
 * The instant of a wall clock time in a time zone. A time that happens
 * twice takes the earlier instant, or the later one with `later`. A time
 * that the clocks skip is moved forward by the length of the gap (02:30
 * becomes 03:30), as Temporal and java.time do, unless `reject`.
 */
export function localToInstant(day: Day, time: Seconds, timeZone = "UTC", disambiguation: Disambiguation = "earlier"): Resolved {
  const wall = day * DAY_MS + time * 1000;
  if (timeZone === "UTC" || timeZone === "Etc/UTC") return { epochMs: wall, offset: 0, status: "ok" };

  // The offsets a day before and a day after bracket every transition of a
  // real zone; the wall time minus each one is a candidate.
  const before = offsetAt(wall - DAY_MS, timeZone);
  const after = offsetAt(wall + DAY_MS, timeZone);
  const candidates = [...new Set([before, after])]
    .map((offset) => wall - offset * 60_000)
    .filter((instant) => {
      const local = instantToLocal(instant, timeZone);
      return local.day * DAY_MS + local.time * 1000 === wall;
    })
    .sort((a, b) => a - b);

  if (candidates.length === 1) {
    const epochMs = candidates[0]!;
    return { epochMs, offset: offsetAt(epochMs, timeZone), status: "ok" };
  }
  if (candidates.length > 1) {
    const epochMs = disambiguation === "later" ? candidates[candidates.length - 1]! : candidates[0]!;
    return { epochMs, offset: offsetAt(epochMs, timeZone), status: "ambiguous" };
  }
  // A gap: the offset before the transition, applied to the wall time,
  // lands after it by the length of the gap.
  if (disambiguation === "reject") return { epochMs: null, offset: before, status: "gap" };
  const epochMs = wall - before * 60_000;
  return { epochMs, offset: offsetAt(epochMs, timeZone), status: "gap" };
}

export function formatOffset(minutes: number): string {
  if (minutes === 0) return "Z";
  const sign = minutes < 0 ? "-" : "+";
  const abs = Math.abs(minutes);
  return `${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`;
}

/** `YYYY-MM-DDTHH:MM:SS` and the offset, for example `2027-03-15T14:30:00+01:00`. */
export function formatDateTime(day: Day, time: Seconds, offset: number | null): string {
  const text = `${formatISO(day)}T${formatTime(time, true)}`;
  return offset === null ? text : text + formatOffset(offset);
}

export interface ParsedDateTime {
  day: Day;
  time: Seconds;
  /** Minutes east of UTC, or null for a naive date and time. */
  offset: number | null;
}

/** Reads an ISO 8601 date and time, with or without an offset (`Z`, `+01:00`). */
export function parseDateTime(text: string | null | undefined): ParsedDateTime | null {
  if (!text) return null;
  const match = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?)(Z|[+-]\d{2}:?\d{2})?$/.exec(text.trim());
  if (!match) return null;
  const day = parseISO(match[1]);
  const time = parseTime(match[2]);
  if (day === null || time === null) return null;
  let offset: number | null = null;
  if (match[3] === "Z") offset = 0;
  else if (match[3]) {
    const digits = match[3].replace(":", "");
    const sign = digits[0] === "-" ? -1 : 1;
    offset = sign * (Number(digits.slice(1, 3)) * 60 + Number(digits.slice(3, 5)));
  }
  return { day, time, offset };
}

/** Today in a time zone, or in the browser's own zone. */
export function today(timeZone?: string | null, now = Date.now()): Day {
  if (timeZone) return instantToLocal(now, timeZone).day;
  const date = new Date(now);
  return fromYMD(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

/** The browser's IANA time zone. */
export function browserTimeZone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
}
