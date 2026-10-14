// The calendar: one or more months of days, a grid of months and a grid
// of years, in any calendar system that Intl knows. It follows the WAI-ARIA
// grid pattern: one tab stop, the arrow keys move between days, Page Up and
// Page Down between months (with Shift, years), Home and End to the ends
// of the week, Enter or Space picks.
//
// The calendar draws; the picker owns the value. It tells the calendar
// what is selected (`setSelection`) and hears what the person picks
// (`onPick`) and which days are shown (`onShow`, to load day content).

import type { DayContent } from "./config";
import type { Words } from "./config";
import { type Day, addDays, formatISO, isoWeek, startOfWeek, weekday } from "./iso";
import type { CalendarSystem, CalMonth, WeekInfo } from "./locale";
import { formatNumber, weekdayNames } from "./locale";
import type { Rules } from "./rules";
import { chevron, el } from "./dom";

export type Selection =
  | { kind: "none" }
  | { kind: "single"; day: Day | null }
  | { kind: "range"; from: Day | null; to: Day | null }
  | { kind: "multiple"; days: Set<Day> }
  | { kind: "week"; day: Day | null };

export type View = "days" | "months" | "years";

export interface CalendarOptions {
  id: string;
  cal: CalendarSystem;
  locale: string;
  words: Words;
  rules: Rules;
  weekInfo: WeekInfo;
  today: Day;
  months: number;
  weekNumbers: boolean;
  outsideDays: boolean;
  rtl: boolean;
  /** The view that the calendar stops at: "months" for a month picker, "years" for a year picker. */
  lowest: View;
  holidays: Record<string, string>;
  content: (day: Day) => DayContent | undefined;
  onPick: (day: Day) => void;
  onShow?: (first: Day, last: Day) => void;
  onHover?: (day: Day | null) => void;
  /** A vertical list of months that grows as it scrolls, for small screens. */
  scrolling?: boolean;
}

const YEARS_PER_PAGE = 12;

export class Calendar {
  readonly root: HTMLElement;
  private view: View;
  /** The first day of the first month shown. */
  private first: CalMonth;
  /** The day with the tab stop. */
  focused: Day;
  private selection: Selection = { kind: "none" };
  private hover: Day | null = null;
  private shown = "";
  private scrollCount = 12;
  private observer: IntersectionObserver | null = null;
  private live: HTMLElement;

  constructor(private options: CalendarOptions) {
    this.view = options.lowest;
    this.focused = options.today;
    this.first = options.cal.monthOf(options.today);
    this.root = el("div", { class: "koyomi-calendar", dir: options.rtl ? "rtl" : null });
    this.live = el("div", { class: "koyomi-sr-only", "aria-live": "polite" });
    this.root.addEventListener("keydown", (event) => this.onKeydown(event));
    this.root.addEventListener("click", (event) => this.onClick(event));
    this.root.addEventListener("pointerover", (event) => this.onPointer(event));
    this.root.addEventListener("pointerleave", () => this.setHover(null));
    this.render();
  }

  setOptions(options: Partial<CalendarOptions>): void {
    this.options = { ...this.options, ...options };
    this.render();
  }

  setSelection(selection: Selection): void {
    this.selection = selection;
    this.render();
  }

  /** Shows the month of `day` and gives it the tab stop. */
  showDay(day: Day): void {
    this.focused = day;
    this.view = this.options.lowest;
    this.reveal(day, "start");
    this.render();
  }

  /** Moves the focus into the calendar, to the day (or month, or year) with the tab stop. */
  focus(): void {
    this.root.querySelector<HTMLElement>("[data-stop]")?.focus({ preventScroll: false });
  }

  /** Tells `onShow` the days shown again, as when the calendar comes into view. */
  announceShown(): void {
    this.shown = "";
    this.render();
  }

  get currentView(): View {
    return this.view;
  }

  destroy(): void {
    this.observer?.disconnect();
  }

  // Which months are shown: `first` and the ones after it.
  private visibleMonths(): CalMonth[] {
    const count = this.options.scrolling ? this.scrollCount : this.options.months;
    const months = [this.first];
    while (months.length < count) months.push(this.options.cal.nextMonth(months[months.length - 1]!));
    return months;
  }

  private reveal(day: Day, align: "start" | "end"): void {
    const months = this.visibleMonths();
    const last = months[months.length - 1]!;
    if (day >= this.first.start && day < last.start + last.length) return;
    const target = this.options.cal.monthOf(day);
    if (align === "start" || this.options.scrolling) {
      this.first = target;
    } else {
      let first = target;
      for (let i = 1; i < this.options.months; i++) first = this.options.cal.prevMonth(first);
      this.first = first;
    }
  }

  private render(): void {
    const hadFocus = this.root.contains(document.activeElement);
    this.observer?.disconnect();
    this.root.replaceChildren();
    this.root.dataset.view = this.view;
    if (this.view === "days") this.renderDays();
    else if (this.view === "months") this.renderMonths();
    else this.renderYears();
    this.root.append(this.live);
    if (hadFocus) this.focus();
  }

  private header(caption: HTMLElement, prev: string, next: string): HTMLElement {
    const flip = this.options.rtl;
    return el(
      "div",
      { class: "koyomi-header" },
      el("button", { type: "button", class: "koyomi-nav", "data-nav": "prev", "aria-label": prev }, chevron(flip ? "right" : "left")),
      caption,
      el("button", { type: "button", class: "koyomi-nav", "data-nav": "next", "aria-label": next }, chevron(flip ? "left" : "right")),
    );
  }

  private renderDays(): void {
    const { words } = this.options;
    const months = this.visibleMonths();
    const lowestIsDays = this.options.lowest === "days";

    if (!this.options.scrolling) {
      const caption = el("div", { class: "koyomi-captions" });
      months.forEach((month, index) => {
        const id = `${this.options.id}-caption-${index}`;
        caption.append(
          lowestIsDays
            ? el("button", { type: "button", class: "koyomi-caption", id, "data-to": "months", "aria-label": `${month.label}, ${words.t("chooseMonth")}` }, month.label)
            : el("span", { class: "koyomi-caption", id }, month.label),
        );
      });
      this.root.append(this.header(caption, words.t("previousMonth"), words.t("nextMonth")));
    }

    const body = el("div", { class: "koyomi-months" });
    months.forEach((month, index) => body.append(this.monthGrid(month, index)));
    this.root.append(body);

    if (this.options.scrolling) {
      const sentinel = el("div", { class: "koyomi-more", "aria-hidden": "true" });
      body.append(sentinel);
      if (typeof IntersectionObserver !== "undefined") {
        this.observer = new IntersectionObserver((entries) => {
          if (entries.some((entry) => entry.isIntersecting)) {
            this.scrollCount += 6;
            const top = body.scrollTop;
            this.render();
            this.root.querySelector(".koyomi-months")!.scrollTop = top;
          }
        });
        this.observer.observe(sentinel);
      }
    }

    const last = months[months.length - 1]!;
    const shown = `${months[0]!.start}:${last.start + last.length - 1}`;
    if (shown !== this.shown) {
      this.shown = shown;
      this.options.onShow?.(this.gridStart(months[0]!), this.gridStart(last) + this.weeksOf(last) * 7 - 1);
      if (!this.options.scrolling) this.live.textContent = months.map((m) => m.label).join(", ");
    }
  }

  private firstDay(): number {
    return this.options.weekInfo.firstDay;
  }

  private gridStart(month: CalMonth): Day {
    return startOfWeek(month.start, this.firstDay());
  }

  private weeksOf(month: CalMonth): number {
    const start = this.gridStart(month);
    return Math.ceil((month.start + month.length - start) / 7);
  }

  private monthGrid(month: CalMonth, index: number): HTMLElement {
    const { words, weekNumbers, locale } = this.options;
    const captionId = `${this.options.id}-caption-${index}`;
    const table = el("table", { role: "grid", class: "koyomi-grid", "aria-labelledby": this.options.scrolling ? null : captionId, "aria-label": this.options.scrolling ? month.label : null });
    const wrap = el("div", { class: "koyomi-month" });
    if (this.options.scrolling) wrap.append(el("div", { class: "koyomi-caption", "aria-hidden": "true" }, month.label));

    const short = weekdayNames(locale, "narrow", this.firstDay());
    const long = weekdayNames(locale, "long", this.firstDay());
    const head = el("tr", {});
    if (weekNumbers) head.append(el("th", { scope: "col", class: "koyomi-week-number", abbr: words.t("weekNumber", { n: "" }).trim() }, words.t("weekShort")));
    short.forEach((name, i) => {
      const iso = ((this.firstDay() - 1 + i) % 7) + 1;
      const weekend = this.options.weekInfo.weekend.includes(iso);
      head.append(el("th", { scope: "col", abbr: long[i]!, class: weekend ? "koyomi-weekend" : null }, el("span", { "aria-hidden": "true" }, name), el("span", { class: "koyomi-sr-only" }, long[i]!)));
    });
    table.append(el("thead", {}, head));

    const tbody = el("tbody", {});
    const start = this.gridStart(month);
    const weeks = this.weeksOf(month);
    const end = month.start + month.length - 1;
    for (let w = 0; w < weeks; w++) {
      const row = el("tr", {});
      const rowStart = start + w * 7;
      if (weekNumbers) {
        // The ISO week of the row: the week of its Thursday.
        const number = isoWeek(rowStart + ((4 - weekday(rowStart) + 7) % 7)).week;
        row.append(el("th", { scope: "row", class: "koyomi-week-number", "aria-label": words.t("weekNumber", { n: number }) }, formatNumber(number, locale)));
      }
      if (this.selection.kind === "week") {
        row.classList.add("koyomi-week-row");
        const selected = this.selection.day;
        if (selected !== null && selected >= rowStart && selected < rowStart + 7) row.classList.add("koyomi-week-selected");
        if (this.hover !== null && this.hover >= rowStart && this.hover < rowStart + 7) row.classList.add("koyomi-week-hover");
      }
      for (let d = 0; d < 7; d++) {
        const day = rowStart + d;
        const outside = day < month.start || day > end;
        row.append(this.dayCell(day, outside, month));
      }
      tbody.append(row);
    }
    table.append(tbody);
    wrap.append(table);
    return wrap;
  }

  private dayCell(day: Day, outside: boolean, month: CalMonth): HTMLElement {
    const { cal, rules, words, today } = this.options;
    const cell = el("td", { role: "gridcell" });
    // A day outside the month is drawn in the month it belongs to; with
    // several months, only once, and never with the tab stop here.
    if (outside && (!this.options.outsideDays || this.options.months > 1 || this.options.scrolling)) {
      cell.classList.add("koyomi-blank");
      return cell;
    }

    const content = this.options.content(day);
    const holiday = this.options.holidays[isoKey(day)];
    const disabled = rules.checkDay(day) !== null || !this.reachable(day);
    const state = this.dayState(day);
    const stop = !outside && day === this.focusTarget(month);

    const description = [cal.format(day, "full"), holiday, content?.title ?? content?.label, disabled ? words.t("unavailable") : null]
      .filter(Boolean)
      .join(", ");

    const button = el(
      "button",
      {
        type: "button",
        class: "koyomi-day",
        tabindex: stop ? "0" : "-1",
        "data-day": String(day),
        "data-stop": stop ? "" : null,
        "aria-label": description,
        "aria-disabled": disabled ? "true" : null,
        "aria-current": day === today ? "date" : null,
        "data-tone": content?.tone ?? null,
        title: holiday ?? content?.title ?? null,
      },
      el("span", { class: "koyomi-day-number" }, cal.dayNumber(day)),
    );
    if (content?.label) button.append(el("span", { class: "koyomi-day-label", "aria-hidden": "true" }, content.label));
    if (content?.marks?.length) {
      const marks = el("span", { class: "koyomi-day-marks", "aria-hidden": "true" });
      content.marks.forEach((tone) => marks.append(el("span", { class: "koyomi-mark", "data-tone": tone })));
      button.append(marks);
    }

    cell.setAttribute("aria-selected", state.selected ? "true" : "false");
    if (outside) cell.classList.add("koyomi-outside");
    if (day === today) cell.classList.add("koyomi-today");
    if (disabled) cell.classList.add("koyomi-unavailable");
    if (holiday) cell.classList.add("koyomi-holiday");
    if (this.options.weekInfo.weekend.includes(weekday(day))) cell.classList.add("koyomi-weekend");
    if (state.selected) cell.classList.add("koyomi-selected");
    if (state.start) cell.classList.add("koyomi-range-start");
    if (state.end) cell.classList.add("koyomi-range-end");
    if (state.middle) cell.classList.add("koyomi-range-middle");
    if (state.preview) cell.classList.add("koyomi-range-preview");
    cell.append(button);
    return cell;
  }

  // The tab stop: the focused day when it is in this month, else nothing
  // (another month has it), so that the grid keeps one tab stop.
  private focusTarget(month: CalMonth): Day | null {
    const months = this.visibleMonths();
    const inShown = months.some((m) => this.focused >= m.start && this.focused < m.start + m.length);
    if (!inShown) this.focused = months[0]!.start;
    return this.focused >= month.start && this.focused < month.start + month.length ? this.focused : null;
  }

  private reachable(day: Day): boolean {
    const s = this.selection;
    if (s.kind !== "range" || s.from === null || s.to !== null) return true;
    return this.options.rules.reachable(s.from, day);
  }

  private dayState(day: Day): { selected: boolean; start: boolean; end: boolean; middle: boolean; preview: boolean } {
    const s = this.selection;
    const none = { selected: false, start: false, end: false, middle: false, preview: false };
    switch (s.kind) {
      case "single":
        return { ...none, selected: s.day === day };
      case "multiple":
        return { ...none, selected: s.days.has(day) };
      case "week":
        return { ...none, selected: s.day !== null && day >= s.day && day < s.day + 7 };
      case "range": {
        if (s.from === null) return none;
        if (s.to === null) {
          const hover = this.hover !== null && this.reachable(this.hover) ? this.hover : null;
          if (hover === null || hover === s.from) return { ...none, selected: day === s.from, start: day === s.from, end: day === s.from };
          const a = Math.min(s.from, hover);
          const b = Math.max(s.from, hover);
          return { selected: day === s.from, start: day === a, end: day === b, middle: false, preview: day >= a && day <= b };
        }
        const a = Math.min(s.from, s.to);
        const b = Math.max(s.from, s.to);
        return { selected: day >= a && day <= b, start: day === a, end: day === b, middle: day > a && day < b, preview: false };
      }
      default:
        return none;
    }
  }

  private renderMonths(): void {
    const { cal, words } = this.options;
    const year = cal.yearOf(this.focused);
    const caption =
      this.options.lowest === "years"
        ? el("span", { class: "koyomi-caption" }, year.label)
        : el("button", { type: "button", class: "koyomi-caption", "data-to": "years", "aria-label": `${year.label}, ${words.t("chooseYear")}` }, year.label);
    this.root.append(this.header(caption, words.t("previousYear"), words.t("nextYear")));
    const focusedMonth = cal.monthOf(this.focused);
    const grid = el("div", { class: "koyomi-month-grid", role: "grid", "aria-label": year.label });
    let row = el("div", { role: "row", class: "koyomi-cells-row" });
    year.months.forEach((month, i) => {
      if (i > 0 && i % 3 === 0) {
        grid.append(row);
        row = el("div", { role: "row", class: "koyomi-cells-row" });
      }
      const allowed = this.monthAllowed(month);
      const selected = this.isSelectedMonth(month);
      const stop = month.key === focusedMonth.key;
      row.append(
        el(
          "div",
          { role: "gridcell", "aria-selected": selected ? "true" : "false", class: selected ? "koyomi-selected" : null },
          el(
            "button",
            {
              type: "button",
              class: "koyomi-cell",
              "data-month": String(month.start),
              "data-stop": stop ? "" : null,
              tabindex: stop ? "0" : "-1",
              "aria-disabled": allowed ? null : "true",
              "aria-current": this.options.today >= month.start && this.options.today < month.start + month.length ? "date" : null,
              "aria-label": month.label,
            },
            month.monthLabel,
          ),
        ),
      );
    });
    grid.append(row);
    this.root.append(grid);
    this.live.textContent = year.label;
  }

  private renderYears(): void {
    const { cal, words } = this.options;
    const focusedYear = cal.yearOf(this.focused);
    // A page of years around the focused one, from the year that starts a
    // page (aligned on the calendar's own year count).
    const years = [];
    let year = focusedYear;
    const index = Number.parseInt(focusedYear.label.replace(/\D/g, "") || "0", 10);
    const offset = Number.isFinite(index) ? ((index % YEARS_PER_PAGE) + YEARS_PER_PAGE) % YEARS_PER_PAGE : 0;
    for (let i = 0; i < offset; i++) year = cal.yearOf(year.start - 1);
    for (let i = 0; i < YEARS_PER_PAGE; i++) {
      years.push(year);
      year = cal.yearOf(year.end + 1);
    }
    const label = `${years[0]!.label} – ${years[years.length - 1]!.label}`;
    this.root.append(this.header(el("span", { class: "koyomi-caption" }, label), words.t("previousYears"), words.t("nextYears")));
    const grid = el("div", { class: "koyomi-year-grid", role: "grid", "aria-label": label });
    let row = el("div", { role: "row", class: "koyomi-cells-row" });
    years.forEach((y, i) => {
      if (i > 0 && i % 3 === 0) {
        grid.append(row);
        row = el("div", { role: "row", class: "koyomi-cells-row" });
      }
      const stop = y.start === focusedYear.start;
      const allowed = this.rangeAllowed(y.start, y.end);
      const selected = this.isSelectedSpan(y.start, y.end);
      row.append(
        el(
          "div",
          { role: "gridcell", "aria-selected": selected ? "true" : "false", class: selected ? "koyomi-selected" : null },
          el(
            "button",
            {
              type: "button",
              class: "koyomi-cell",
              "data-year": String(y.start),
              "data-stop": stop ? "" : null,
              tabindex: stop ? "0" : "-1",
              "aria-disabled": allowed ? null : "true",
              "aria-current": this.options.today >= y.start && this.options.today <= y.end ? "date" : null,
            },
            y.label,
          ),
        ),
      );
    });
    grid.append(row);
    this.root.append(grid);
    this.live.textContent = label;
  }

  private monthAllowed(month: CalMonth): boolean {
    return this.rangeAllowed(month.start, month.start + month.length - 1);
  }

  private rangeAllowed(first: Day, last: Day): boolean {
    const { min, max } = this.options.rules;
    return !((min !== null && last < min) || (max !== null && first > max));
  }

  private isSelectedMonth(month: CalMonth): boolean {
    return this.isSelectedSpan(month.start, month.start + month.length - 1);
  }

  private isSelectedSpan(first: Day, last: Day): boolean {
    const s = this.selection;
    if (s.kind === "single" && s.day !== null) return s.day >= first && s.day <= last;
    return false;
  }

  // Events.

  private onClick(event: MouseEvent): void {
    const target = (event.target as HTMLElement).closest<HTMLElement>("button");
    if (!target || !this.root.contains(target)) return;
    if (target.dataset.nav) {
      this.navigate(target.dataset.nav === "prev" ? -1 : 1);
      return;
    }
    if (target.dataset.to) {
      this.view = target.dataset.to as View;
      this.render();
      this.focus();
      return;
    }
    if (target.getAttribute("aria-disabled") === "true") return;
    if (target.dataset.day) this.pickDay(Number(target.dataset.day));
    else if (target.dataset.month) this.pickMonth(Number(target.dataset.month));
    else if (target.dataset.year) this.pickYear(Number(target.dataset.year));
  }

  private pickDay(day: Day): void {
    this.focused = day;
    this.options.onPick(day);
  }

  private pickMonth(start: Day): void {
    if (this.options.lowest === "months") {
      this.focused = start;
      this.options.onPick(start);
      return;
    }
    // Keep the day of the month that had the focus, when the month has it.
    const offset = this.focused - this.options.cal.monthOf(this.focused).start;
    const month = this.options.cal.monthOf(start);
    this.focused = start + Math.min(offset, month.length - 1);
    this.first = month;
    this.view = "days";
    this.render();
    this.focus();
  }

  private pickYear(start: Day): void {
    if (this.options.lowest === "years") {
      this.focused = start;
      this.options.onPick(start);
      return;
    }
    const { cal } = this.options;
    const fromYear = cal.yearOf(this.focused);
    const monthIndex = fromYear.months.findIndex((m) => this.focused >= m.start && this.focused < m.start + m.length);
    const year = cal.yearOf(start);
    const month = year.months[Math.min(monthIndex, year.months.length - 1)] ?? year.months[0]!;
    this.focused = month.start + Math.min(this.focused - fromYear.months[monthIndex]!.start, month.length - 1);
    this.view = "months";
    this.render();
    this.focus();
  }

  private navigate(step: number): void {
    const { cal } = this.options;
    if (this.view === "days") {
      const first = step < 0 ? cal.prevMonth(this.first) : cal.nextMonth(this.first);
      this.first = first;
      const offset = this.focused - cal.monthOf(this.focused).start;
      this.focused = first.start + Math.min(Math.max(offset, 0), first.length - 1);
    } else if (this.view === "months") {
      this.focused = cal.addMonths(this.focused, 12 * step);
      const year = cal.yearOf(this.focused);
      if (step > 0 && this.focused < year.start) this.focused = year.start;
    } else {
      this.focused = cal.addMonths(this.focused, 12 * YEARS_PER_PAGE * step);
    }
    this.render();
  }

  private onPointer(event: PointerEvent): void {
    const button = (event.target as HTMLElement).closest<HTMLElement>("[data-day]");
    this.setHover(button ? Number(button.dataset.day) : null);
  }

  private setHover(day: Day | null): void {
    if (day === this.hover) return;
    this.hover = day;
    this.options.onHover?.(day);
    const s = this.selection;
    if ((s.kind === "range" && s.from !== null && s.to === null) || s.kind === "week") this.render();
  }

  private onKeydown(event: KeyboardEvent): void {
    const target = event.target as HTMLElement;
    const forward = this.options.rtl ? -1 : 1;
    if (target.dataset.day) {
      const day = Number(target.dataset.day);
      const moves: Record<string, () => Day> = {
        ArrowLeft: () => addDays(day, -forward),
        ArrowRight: () => addDays(day, forward),
        ArrowUp: () => addDays(day, -7),
        ArrowDown: () => addDays(day, 7),
        Home: () => startOfWeek(day, this.firstDay()),
        End: () => startOfWeek(day, this.firstDay()) + 6,
        PageUp: () => this.options.cal.addMonths(day, event.shiftKey ? -12 : -1),
        PageDown: () => this.options.cal.addMonths(day, event.shiftKey ? 12 : 1),
      };
      const move = moves[event.key];
      if (move) {
        event.preventDefault();
        this.moveFocus(move(), move() < day ? "start" : "end");
        return;
      }
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (target.getAttribute("aria-disabled") !== "true") this.pickDay(day);
      }
      return;
    }
    if (target.dataset.month || target.dataset.year) {
      const cells = [...this.root.querySelectorAll<HTMLElement>(".koyomi-cell")];
      const index = cells.indexOf(target);
      const moves: Record<string, number> = { ArrowLeft: -forward, ArrowRight: forward, ArrowUp: -3, ArrowDown: 3, Home: -index, End: cells.length - 1 - index };
      if (event.key in moves) {
        event.preventDefault();
        const next = index + moves[event.key]!;
        if (next < 0 || next >= cells.length) {
          this.navigate(next < 0 ? -1 : 1);
        } else {
          const cell = cells[next]!;
          this.focused = Number(cell.dataset.month ?? cell.dataset.year);
          this.render();
        }
        this.focus();
        return;
      }
      if (event.key === "PageUp" || event.key === "PageDown") {
        event.preventDefault();
        this.navigate(event.key === "PageUp" ? -1 : 1);
        this.focus();
      }
    }
  }

  private moveFocus(day: Day, align: "start" | "end"): void {
    this.focused = day;
    this.reveal(day, align);
    if (this.selection.kind === "range" || this.selection.kind === "week") this.hover = day;
    this.render();
    this.focus();
  }

  /** Announces a message to screen readers. */
  announce(text: string): void {
    this.live.textContent = "";
    requestAnimationFrame(() => (this.live.textContent = text));
  }
}

export function isoKey(day: Day): string {
  return formatISO(day);
}
