// The options of a picker, as the server writes them in data-config
// (Koyomi.Components), and the words of Koyomi.Messages.

import type { Day } from "./iso";

export type Kind = "date" | "range" | "dates" | "month" | "year" | "week" | "time" | "datetime" | "recurrence" | "calendar";

export interface ClientRules {
  min?: string;
  max?: string;
  disabledDates?: string[];
  disabledRanges?: [string, string][];
  disabledWeekdays?: number[];
  minDays?: number;
  maxDays?: number;
  allowDisabledInRange?: boolean;
  minCount?: number;
  maxCount?: number;
  minTime?: string;
  maxTime?: string;
  step?: number;
}

export interface Preset {
  id: string;
  value: string | { from: string; to: string };
  label?: string;
  relative?: { n: number; unit: Intl.RelativeTimeFormatUnit };
  message?: string;
  n?: number;
}

export interface Config {
  v: number;
  kind: Kind;
  locale: string;
  calendar?: string;
  timeZone?: string;
  today: string;
  firstDay?: number;
  months: number;
  inline?: boolean;
  weekNumbers?: boolean;
  outsideDays?: boolean;
  typing?: boolean;
  clearable?: boolean;
  required?: boolean;
  disabled?: boolean;
  readonly?: boolean;
  display: "short" | "medium" | "long" | "full";
  label?: string;
  labelId?: string;
  describedBy?: string;
  invalid?: boolean;
  rules?: ClientRules;
  presets?: Preset[];
  holidays?: Record<string, string>;
  days?: boolean;
  slots?: boolean;
  onChange?: string;
  messages: Record<string, string>;
  seconds?: boolean;
  hourCycle?: "h12" | "h23";
  ambiguous?: "earlier" | "later";
  nights?: boolean;
  select?: "date" | "range" | "dates";
  start?: string;
}

/** The content of a day, from the LiveView (Koyomi.Live). */
export interface DayContent {
  disabled?: boolean;
  label?: string;
  title?: string;
  tone?: string;
  marks?: string[];
  slots?: Slot[];
}

export interface Slot {
  time: string;
  label?: string;
  disabled?: boolean;
}

export function readConfig(el: HTMLElement): Config {
  const config = JSON.parse(el.dataset.config ?? "{}") as Config;
  config.months = Math.max(1, Math.min(config.months ?? 1, 12));
  config.display ??= "medium";
  config.messages ??= {};
  return config;
}

/** The words of a picker: `t("weekNumber", {n: 11})`, and plural forms with `count`. */
export class Words {
  private plurals: Intl.PluralRules;

  constructor(
    private messages: Record<string, string>,
    readonly locale: string,
  ) {
    this.plurals = new Intl.PluralRules(locale);
  }

  t(key: string, vars: Record<string, string | number> = {}): string {
    const text = this.messages[key] ?? key;
    return text.replace(/\{(\w+)\}/g, (match, name: string) => (name in vars ? String(vars[name]) : match));
  }

  /** The plural form of `base` for `n` (`daysOne`, `daysOther`), with `{n}` filled. */
  count(base: string, n: number, vars: Record<string, string | number> = {}): string {
    const form = this.plurals.select(n) === "one" ? "One" : "Other";
    return this.t(base + form, { n: new Intl.NumberFormat(this.locale).format(n), ...vars });
  }
}

export type Value =
  | { kind: "date"; day: Day | null }
  | { kind: "range"; from: Day | null; to: Day | null }
  | { kind: "dates"; days: Day[] };
