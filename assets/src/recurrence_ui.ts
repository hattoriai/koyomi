// The editor of a recurrence picker: how often (never, daily, weekly,
// monthly, yearly), every how many, on which weekdays or which day of the
// month, and until when; with the rule written out in words and the next
// dates. It writes an RFC 5545 rule (rrule.ts), the same that
// Koyomi.Recurrence reads on the server. The day of the end is picked on a
// Koyomi calendar that opens below the choices of the end.

import { Calendar } from "./calendar";
import type { Words } from "./config";
import { el } from "./dom";
import { type Day, formatISO, parseISO, toYMD, weekday } from "./iso";
import { type CalendarSystem, type WeekInfo, weekdayNames } from "./locale";
import { type Freq, type Rule, describeRule, emptyRule, formatRule, occurrences, parseRule } from "./rrule";
import { Rules } from "./rules";

export interface RecurrenceOptions {
  id: string;
  locale: string;
  words: Words;
  start: Day;
  today: Day;
  cal: CalendarSystem;
  week: WeekInfo;
  rtl: boolean;
  onChange: (rule: string | null) => void;
}

const UNITS: Record<Freq, string> = { daily: "unitDay", weekly: "unitWeek", monthly: "unitMonth", yearly: "unitYear" };

export class RecurrenceEditor {
  readonly root: HTMLElement;
  private rule: Rule | null = null;
  private freq!: HTMLSelectElement;
  private interval!: HTMLInputElement;
  private unit!: HTMLElement;
  private weekdays!: HTMLElement;
  private monthly!: HTMLElement;
  private ends!: HTMLElement;
  private count!: HTMLInputElement;
  private until!: HTMLButtonElement;
  private untilPanel!: HTMLElement;
  private untilCalendar!: Calendar;
  private summaryText!: HTMLElement;
  private next!: HTMLElement;
  private details!: HTMLElement;

  constructor(private options: RecurrenceOptions) {
    this.root = el("div", { class: "koyomi-recurrence" });
    this.build();
    this.draw();
  }

  private id(part: string): string {
    return `${this.options.id}-${part}`;
  }

  private build(): void {
    const { words } = this.options;
    this.freq = el("select", { id: this.id("freq"), class: "koyomi-select" });
    for (const [value, key] of [
      ["", "doesNotRepeat"],
      ["daily", "repeatDaily"],
      ["weekly", "repeatWeekly"],
      ["monthly", "repeatMonthly"],
      ["yearly", "repeatYearly"],
    ] as const) {
      this.freq.append(el("option", { value }, words.t(key)));
    }
    this.freq.addEventListener("change", () => {
      const freq = this.freq.value as Freq | "";
      this.rule = freq ? this.defaults(freq) : null;
      this.emit();
    });

    this.interval = el("input", { id: this.id("interval"), type: "number", min: "1", max: "999", class: "koyomi-number", inputmode: "numeric" });
    this.interval.addEventListener("input", () => {
      const n = Number(this.interval.value);
      if (this.rule && Number.isInteger(n) && n >= 1) {
        this.rule.interval = n;
        this.emit(false);
      }
    });
    this.unit = el("span", { class: "koyomi-unit" });

    this.weekdays = el("div", { class: "koyomi-weekdays", role: "group", "aria-label": words.t("onDays") });
    const names = weekdayNames(this.options.locale, "short", this.options.week.firstDay);
    const long = weekdayNames(this.options.locale, "long", this.options.week.firstDay);
    names.forEach((name, i) => {
      const iso = ((this.options.week.firstDay - 1 + i) % 7) + 1;
      const button = el("button", { type: "button", class: "koyomi-weekday", "data-weekday": String(iso), "aria-pressed": "false", "aria-label": long[i]! }, name);
      button.addEventListener("click", () => this.toggleWeekday(iso));
      this.weekdays.append(button);
    });

    this.monthly = el("div", { class: "koyomi-choices", role: "radiogroup" });
    this.ends = el("div", { class: "koyomi-choices", role: "radiogroup", "aria-labelledby": this.id("ends-label") });
    this.count = el("input", { type: "number", min: "1", max: "999", class: "koyomi-number", inputmode: "numeric", "aria-label": words.count("occurrences", 2) });
    this.until = el("button", {
      type: "button",
      id: this.id("until"),
      class: "koyomi-date-input koyomi-until",
      "aria-expanded": "false",
      "aria-controls": this.id("until-calendar"),
    });
    this.until.addEventListener("click", () => this.toggleUntil(this.until.getAttribute("aria-expanded") !== "true"));
    this.count.addEventListener("input", () => {
      const n = Number(this.count.value);
      if (this.rule && Number.isInteger(n) && n >= 1) {
        this.rule.count = n;
        this.rule.until = null;
        this.emit(false);
      }
    });
    // The end is on the start or after it, as Koyomi.Recurrence counts
    // the dates from the start.
    this.untilCalendar = new Calendar({
      id: this.id("until-calendar"),
      cal: this.options.cal,
      locale: this.options.locale,
      words,
      rules: new Rules({ min: formatISO(this.options.start) }),
      weekInfo: this.options.week,
      today: this.options.today,
      months: 1,
      weekNumbers: false,
      outsideDays: true,
      rtl: this.options.rtl,
      lowest: "days",
      holidays: {},
      content: () => undefined,
      onPick: (day) => this.pickUntil(day),
    });
    this.untilPanel = el("div", { id: this.id("until-calendar"), class: "koyomi-until-calendar", hidden: "" }, this.untilCalendar.root);
    // Escape closes the calendar of the end, not the whole popover.
    this.untilPanel.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      this.toggleUntil(false);
      this.until.focus();
    });

    this.summaryText = el("p", { class: "koyomi-recurrence-summary", "aria-live": "polite" });
    this.next = el("ol", { class: "koyomi-occurrences", "aria-label": words.t("nextOccurrences") });

    this.details = el(
      "div",
      { class: "koyomi-recurrence-details" },
      el("div", { class: "koyomi-row" }, el("label", { for: this.id("interval") }, words.t("every")), this.interval, this.unit),
      this.weekdays,
      this.monthly,
      el("div", { class: "koyomi-row" }, el("span", { id: this.id("ends-label"), class: "koyomi-label" }, words.t("ends"))),
      this.ends,
      this.untilPanel,
    );

    this.root.append(el("div", { class: "koyomi-row" }, el("label", { for: this.id("freq") }, words.t("repeat")), this.freq), this.details, this.summaryText, this.next);
  }

  /** A new rule of a frequency, on the start's weekday or day. */
  private defaults(freq: Freq): Rule {
    const rule = emptyRule(freq);
    if (freq === "weekly") rule.byDay = [{ ordinal: null, weekday: weekday(this.options.start) }];
    return rule;
  }

  firstFocus(): HTMLElement {
    return this.freq;
  }

  /** Sets the rule from its text (from the server), or none. */
  setRule(text: string | null): void {
    if (!text) {
      this.rule = null;
    } else {
      const parsed = parseRule(text);
      this.rule = parsed.ok ? parsed.rule : null;
    }
    this.draw();
  }

  summary(): string {
    return this.rule ? describeRule(this.rule, this.options.locale, this.options.start) : this.options.words.t("doesNotRepeat");
  }

  private toggleWeekday(iso: number): void {
    if (!this.rule) return;
    const has = this.rule.byDay.some((day) => day.weekday === iso && day.ordinal === null);
    const next = has ? this.rule.byDay.filter((day) => day.weekday !== iso) : [...this.rule.byDay, { ordinal: null, weekday: iso }];
    // A weekly rule keeps one weekday at least.
    if (next.length === 0) return;
    this.rule.byDay = next.sort((a, b) => a.weekday - b.weekday);
    this.emit();
  }

  /** The end date of the rule, or the default: 90 days after the start. */
  private untilDay(): Day {
    return (this.rule?.until ? parseISO(this.rule.until.slice(0, 10)) : null) ?? this.options.start + 90;
  }

  private toggleUntil(open: boolean): void {
    this.untilPanel.hidden = !open;
    this.until.setAttribute("aria-expanded", String(open));
    if (!open) return;
    const day = this.untilDay();
    this.untilCalendar.setSelection({ kind: "single", day });
    this.untilCalendar.showDay(day);
    this.untilCalendar.focus();
  }

  private pickUntil(day: Day): void {
    if (!this.rule) return;
    this.rule.until = formatISO(day);
    this.rule.count = null;
    this.toggleUntil(false);
    this.emit();
    this.until.focus();
  }

  private emit(redraw = true): void {
    this.options.onChange(this.rule ? formatRule(this.rule) : null);
    if (redraw) this.draw();
    else this.drawSummary();
  }

  private draw(): void {
    const { words } = this.options;
    const rule = this.rule;
    this.freq.value = rule?.freq ?? "";
    this.details.hidden = rule === null;
    if (!rule) {
      this.drawSummary();
      return;
    }
    this.interval.value = String(rule.interval);
    this.unit.textContent = words.t(UNITS[rule.freq] + (new Intl.PluralRules(this.options.locale).select(rule.interval) === "one" ? "One" : "Other"));

    this.weekdays.hidden = rule.freq !== "weekly";
    for (const button of this.weekdays.querySelectorAll<HTMLElement>("[data-weekday]")) {
      const iso = Number(button.dataset.weekday);
      button.setAttribute("aria-pressed", rule.byDay.some((day) => day.weekday === iso && day.ordinal === null) ? "true" : "false");
    }

    this.monthly.hidden = rule.freq !== "monthly";
    if (rule.freq === "monthly") this.drawMonthly(rule);
    this.drawEnds(rule);
    this.drawSummary();
  }

  private drawMonthly(rule: Rule): void {
    const { words, start, locale } = this.options;
    const { day } = toYMD(start);
    const iso = weekday(start);
    const nth = Math.ceil(day / 7);
    const last = toYMD(start + 7).month !== toYMD(start).month;
    const ordinal = last && nth >= 4 ? -1 : nth;
    const weekdayName = new Intl.DateTimeFormat(locale, { weekday: "long", timeZone: "UTC" }).format(new Date(start * 86_400_000));
    const nthWord = ordinal === -1 ? words.t("nthLast") : words.t(`nth${nth}`);
    const byWeekday = rule.byDay.length > 0;
    this.monthly.replaceChildren();
    const choice = (label: string, checked: boolean, apply: () => void) => {
      const id = this.id(`monthly-${this.monthly.childElementCount}`);
      const radio = el("input", { type: "radio", name: this.id("monthly"), id, checked: checked ? "" : null });
      radio.addEventListener("change", () => {
        apply();
        this.emit();
      });
      this.monthly.append(el("div", { class: "koyomi-choice" }, radio, el("label", { for: id }, label)));
    };
    choice(words.t("monthDay", { n: day }), !byWeekday, () => {
      rule.byDay = [];
      rule.byMonthDay = [];
      rule.bySetPos = [];
    });
    choice(words.t("monthWeekday", { nth: nthWord, weekday: weekdayName }), byWeekday, () => {
      rule.byMonthDay = [];
      rule.bySetPos = [];
      rule.byDay = [{ ordinal, weekday: iso }];
    });
  }

  private drawEnds(rule: Rule): void {
    const { words } = this.options;
    this.ends.replaceChildren();
    const mode = rule.count !== null ? "count" : rule.until !== null ? "until" : "never";
    const choice = (value: string, label: string, extra: HTMLElement | null, apply: () => void) => {
      const id = this.id(`ends-${value}`);
      const radio = el("input", { type: "radio", name: this.id("ends"), id, value, checked: mode === value ? "" : null });
      radio.addEventListener("change", () => {
        apply();
        this.emit();
      });
      const row = el("div", { class: "koyomi-choice" }, radio, el("label", { for: id }, label));
      if (extra) row.append(extra);
      this.ends.append(row);
    };
    choice("never", words.t("endsNever"), null, () => {
      rule.count = null;
      rule.until = null;
    });
    this.count.value = String(rule.count ?? 10);
    this.count.disabled = mode !== "count";
    choice("count", words.t("endsAfter"), el("span", { class: "koyomi-inline-group" }, this.count, el("span", {}, words.t(`occurrences${new Intl.PluralRules(this.options.locale).select(rule.count ?? 10) === "one" ? "One" : "Other"}`))), () => {
      rule.until = null;
      rule.count = Number(this.count.value) || 10;
    });
    const untilDay = this.untilDay();
    this.until.textContent = this.options.cal.format(untilDay, "medium");
    this.until.disabled = mode !== "until";
    if (mode !== "until") this.toggleUntil(false);
    choice("until", words.t("endsOn"), this.until, () => {
      rule.count = null;
      rule.until = formatISO(untilDay);
    });
  }

  private drawSummary(): void {
    this.summaryText.textContent = this.summary();
    this.next.replaceChildren();
    if (!this.rule) return;
    for (const day of occurrences(this.rule, this.options.start, 5)) {
      this.next.append(el("li", {}, this.options.cal.format(day, "full")));
    }
  }
}
