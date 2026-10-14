// The rules of a picker in the browser: the same checks as Koyomi.Rules on
// the server, so that what the calendar disables is what the changeset
// refuses. Days that the LiveView marks disabled (day content) are
// refused too.

import type { ClientRules, DayContent } from "./config";
import { type Day, type Seconds, parseDateTime, parseISO, parseTime, weekday } from "./iso";

export type Reason =
  | { code: "beforeMin"; day: Day }
  | { code: "afterMax"; day: Day }
  | { code: "disabled"; day: Day }
  | { code: "disabledInRange"; day: Day }
  | { code: "tooShort"; n: number }
  | { code: "tooLong"; n: number }
  | { code: "tooMany"; n: number }
  | { code: "timeBeforeMin"; time: Seconds }
  | { code: "timeAfterMax"; time: Seconds }
  | { code: "timeStep"; n: number };

function boundDay(text: string | undefined): Day | null {
  if (!text) return null;
  return parseISO(text) ?? parseDateTime(text)?.day ?? null;
}

export class Rules {
  readonly min: Day | null;
  readonly max: Day | null;
  readonly minTime: Seconds | null;
  readonly maxTime: Seconds | null;
  readonly step: number | null;
  private dates: Set<Day>;
  private ranges: [Day, Day][];
  private weekdays: Set<number>;

  constructor(
    readonly rules: ClientRules = {},
    private content: (day: Day) => DayContent | undefined = () => undefined,
  ) {
    this.min = boundDay(rules.min);
    this.max = boundDay(rules.max);
    this.minTime = parseTime(rules.minTime);
    this.maxTime = parseTime(rules.maxTime);
    this.step = rules.step ?? null;
    this.dates = new Set((rules.disabledDates ?? []).map((text) => parseISO(text)).filter((day): day is Day => day !== null));
    this.ranges = (rules.disabledRanges ?? [])
      .map(([a, b]) => [parseISO(a), parseISO(b)] as const)
      .filter((pair): pair is readonly [Day, Day] => pair[0] !== null && pair[1] !== null)
      .map(([a, b]) => [Math.min(a, b), Math.max(a, b)]);
    this.weekdays = new Set(rules.disabledWeekdays ?? []);
  }

  /** Disabled by a rule or by the day content, the bounds aside. */
  disabled(day: Day): boolean {
    if (this.weekdays.has(weekday(day)) || this.dates.has(day)) return true;
    if (this.ranges.some(([a, b]) => day >= a && day <= b)) return true;
    return this.content(day)?.disabled === true;
  }

  outOfBounds(day: Day): boolean {
    return (this.min !== null && day < this.min) || (this.max !== null && day > this.max);
  }

  /** Why a day may not be chosen, or null. */
  checkDay(day: Day): Reason | null {
    if (this.min !== null && day < this.min) return { code: "beforeMin", day: this.min };
    if (this.max !== null && day > this.max) return { code: "afterMax", day: this.max };
    if (this.disabled(day)) return { code: "disabled", day };
    return null;
  }

  allowed(day: Day): boolean {
    return this.checkDay(day) === null;
  }

  /** Why a range may not be chosen, or null. Both ends count: Monday to Wednesday is 3 days. */
  checkRange(from: Day, to: Day): Reason | null {
    const a = Math.min(from, to);
    const b = Math.max(from, to);
    const ends = this.checkDay(a) ?? this.checkDay(b);
    if (ends) return ends;
    const days = b - a + 1;
    if (this.rules.minDays && days < this.rules.minDays) return { code: "tooShort", n: this.rules.minDays };
    if (this.rules.maxDays && days > this.rules.maxDays) return { code: "tooLong", n: this.rules.maxDays };
    if (!this.rules.allowDisabledInRange) {
      for (let day = a; day <= b; day++) if (this.disabled(day)) return { code: "disabledInRange", day };
    }
    return null;
  }

  /**
   * While the second end of a range is chosen: the days that a range from
   * `start` can reach. A day outside them is shown disabled.
   */
  reachable(start: Day, day: Day): boolean {
    if (day === start) return true;
    return this.checkRange(start, day) === null || this.checkRange(start, day)?.code === "tooShort";
  }

  /** Whether one more day may be added to a set of `count` days. */
  canAdd(count: number): boolean {
    return !this.rules.maxCount || count < this.rules.maxCount;
  }

  checkTime(time: Seconds): Reason | null {
    if (this.minTime !== null && time < this.minTime) return { code: "timeBeforeMin", time: this.minTime };
    if (this.maxTime !== null && time > this.maxTime) return { code: "timeAfterMax", time: this.maxTime };
    if (this.step && time % (this.step * 60) !== 0) return { code: "timeStep", n: this.step };
    return null;
  }

  /** The bounds of the rules as instants, for a date and time picker. */
  instantBounds(): { min: string | null; max: string | null } {
    const instant = (text: string | undefined) => (text && parseDateTime(text) ? text : null);
    return { min: instant(this.rules.min), max: instant(this.rules.max) };
  }
}
