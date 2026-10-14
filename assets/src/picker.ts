// A picker: the field, the popover (or the inline panel) and the inputs
// that the form posts. One class for every kind; the kind decides the
// segments of the field, what the calendar selects and what is posted.
//
// The element that the server renders (Koyomi.Components) holds the
// browser's own inputs. The picker keeps them, hides them, and writes the
// value to them on each change, with an input event, so that the form's
// phx-change sees it. The server's later values and options arrive in
// data-value and data-config (`update`).

import { Calendar, type Selection } from "./calendar";
import { type Config, type DayContent, type Kind, type Preset, Words, readConfig } from "./config";
import { calendarIcon, clockIcon, closeIcon, el, repeatIcon } from "./dom";
import {
  type Day,
  type Seconds,
  formatDateTime,
  formatISO,
  formatISOWeek,
  formatMonth,
  formatTime,
  fromYMD,
  instantToLocal,
  isoWeek,
  isoWeeksInYear,
  localToInstant,
  parseDateTime,
  parseISO,
  parseISOWeek,
  parseMonth,
  parseTime,
  startOfWeek,
  toYMD,
  today as todayIn,
  fromISOWeek,
} from "./iso";
import {
  type CalendarSystem,
  type FieldPart,
  calendarSystem,
  dateFieldOrder,
  dayPeriods,
  fieldNames,
  fieldPlaceholders,
  formatNumber,
  hourCycle as localeHourCycle,
  relativeLabel,
  rtl,
  timeFieldOrder,
  weekInfo,
} from "./locale";
import { type ParseMode, type ParseResult, parseDate } from "./parse";
import { Popover } from "./popover";
import { RecurrenceEditor } from "./recurrence_ui";
import { type Reason, Rules } from "./rules";
import { type Part, type SegmentField, type SegmentSpec, Segments, type Values } from "./segments";
import { TimeList } from "./timelist";

/** How the picker talks to the LiveView: pushes, and the replies. */
export interface Transport {
  push(event: string, payload: Record<string, unknown>, onReply?: (reply: Record<string, unknown>) => void): void;
}

type Wire = string | { from: string | null; to: string | null } | string[] | null;

const GREGORIAN_LIKE = new Set(["gregory", "iso8601", "japanese", "buddhist", "roc"]);

export class Picker {
  config!: Config;
  private words!: Words;
  private cal!: CalendarSystem;
  private rules!: Rules;
  private week!: ReturnType<typeof weekInfo>;
  private today!: Day;
  private configText = "";
  private serverValue = "";
  /** The last values posted: the server's renders of them are echoes, not new values. */
  private posted: Wire[] = [];

  // The value.
  private day: Day | null = null;
  private time: Seconds | null = null;
  private from: Day | null = null;
  private to: Day | null = null;
  /** The first day of a range while the second is chosen. */
  private draft: Day | null = null;
  private days = new Set<Day>();
  private year: number | null = null;
  private rrule: string | null = null;
  /** Which of the two instants a repeated wall clock time is. */
  private ambiguous: "earlier" | "later" = "earlier";
  private built = false;

  // The parts of the UI.
  private control: HTMLElement | null = null;
  private segments: Segments | null = null;
  private toSegments: Segments | null = null;
  private timeSegments: Segments | null = null;
  private chips: HTMLElement | null = null;
  private trigger: HTMLButtonElement | null = null;
  private clearButton: HTMLButtonElement | null = null;
  private zoneLabel: HTMLElement | null = null;
  private popover: Popover | null = null;
  private panel: HTMLElement | null = null;
  private calendar: Calendar | null = null;
  private timeList: TimeList | null = null;
  private typeBox: HTMLInputElement | null = null;
  private preview: HTMLElement | null = null;
  private notice: HTMLElement | null = null;
  private message!: HTMLElement;
  /** Announcements for screen readers, outside the popover, so that they outlive it. */
  private live!: HTMLElement;
  private recurrence: RecurrenceEditor | null = null;

  // Day content from the LiveView.
  private content = new Map<Day, DayContent>();
  /** The days whose content came (or is coming) from the LiveView. */
  private loaded = new Set<Day>();
  private pending = new Map<string, [Day, Day]>();
  private refs = 0;
  private loadError = false;

  constructor(
    readonly root: HTMLElement,
    private transport: Transport | null,
  ) {
    this.root.classList.add("koyomi-ready");
    for (const input of this.nativeInputs()) {
      input.tabIndex = -1;
      input.setAttribute("aria-hidden", "true");
      // A click on a <label for> lands here: the field takes the focus.
      input.addEventListener("focus", () => this.focus());
    }
    this.message = el("div", { class: "koyomi-message", id: `${root.id}-message`, "aria-live": "polite" });
    this.live = el("div", { class: "koyomi-sr-only", "aria-live": "polite" });
    this.build();
    this.applyServerValue(true);
  }

  get id(): string {
    return this.root.id;
  }

  // Setup.

  private build(): void {
    this.configText = this.root.dataset.config ?? "";
    this.config = readConfig(this.root);
    const config = this.config;
    this.words = new Words(config.messages, config.locale);
    // A month, week or year picker posts ISO months, weeks and years: its
    // calendar is Gregorian unless the one asked for (or the locale's own)
    // has Gregorian months.
    this.cal = calendarSystem(config.locale, config.calendar);
    if (["month", "year", "week"].includes(config.kind) && !GREGORIAN_LIKE.has(this.cal.id)) this.cal = calendarSystem(config.locale, "gregory");
    if (!this.built) this.ambiguous = config.ambiguous ?? "earlier";
    this.built = true;
    this.week = weekInfo(config.locale);
    if (config.firstDay) this.week = { ...this.week, firstDay: config.firstDay };
    if (config.kind === "week") this.week = { ...this.week, firstDay: 1 };
    this.today = parseISO(config.today) ?? todayIn(config.timeZone);
    this.rules = new Rules(config.rules, (day) => this.content.get(day));
    this.root.classList.toggle("koyomi-is-disabled", config.disabled === true);
    this.root.classList.toggle("koyomi-is-readonly", config.readonly === true);
    if (rtl(config.locale)) this.root.setAttribute("dir", "rtl");

    this.teardownUI();
    const inline = config.inline || config.kind === "calendar";
    if (!inline) this.buildControl();
    if (config.kind !== "time" || !inline) this.buildPanel(inline);
    this.root.append(this.message, this.live);
    this.refresh();
  }

  private teardownUI(): void {
    this.popover?.destroy();
    this.calendar?.destroy();
    this.control?.remove();
    this.panel?.remove();
    this.popover = null;
    this.calendar = null;
    this.control = this.panel = null;
    this.segments = this.toSegments = this.timeSegments = null;
    this.timeList = null;
    this.typeBox = null;
    this.recurrence = null;
  }

  private nativeInputs(): HTMLInputElement[] {
    return [...this.root.querySelectorAll<HTMLInputElement>(":scope > input")];
  }

  private input(part: string): HTMLInputElement | null {
    return this.root.querySelector<HTMLInputElement>(`:scope > input[data-part="${part}"]`);
  }

  private get kind(): Kind {
    return this.config.kind;
  }

  private get labelText(): string {
    const { labelId, label } = this.config;
    if (labelId) return document.getElementById(labelId)?.textContent?.trim() ?? label ?? "";
    return label ?? "";
  }

  // The field.

  private buildControl(): void {
    const config = this.config;
    const control = el("div", { class: "koyomi-control", role: "group" });
    if (config.labelId) control.setAttribute("aria-labelledby", config.labelId);
    else if (config.label) control.setAttribute("aria-label", config.label);
    this.control = control;

    const kind = this.kind;
    if (kind === "dates") {
      this.chips = el("div", { class: "koyomi-chips" });
      control.append(this.chips);
    } else if (kind === "recurrence") {
      this.chips = el("div", { class: "koyomi-summary" });
      control.append(this.chips);
    } else if (kind === "range") {
      this.segments = this.dateSegments("from");
      this.toSegments = this.dateSegments("to");
      this.segments.link(null, this.toSegments);
      this.toSegments.link(this.segments, null);
      control.append(this.segments.root, el("span", { class: "koyomi-range-dash", "aria-hidden": "true" }, "–"), this.toSegments.root);
    } else if (kind === "time") {
      this.timeSegments = this.buildTimeSegments();
      control.append(this.timeSegments.root);
    } else if (kind === "datetime") {
      this.segments = this.dateSegments("value");
      this.timeSegments = this.buildTimeSegments();
      this.segments.link(null, this.timeSegments);
      this.timeSegments.link(this.segments, null);
      control.append(this.segments.root, el("span", { class: "koyomi-literal", "aria-hidden": "true" }, " "), this.timeSegments.root);
      if (config.timeZone) {
        this.zoneLabel = el("span", { class: "koyomi-zone" });
        control.append(this.zoneLabel);
      }
    } else {
      this.segments = this.dateSegments("value");
      control.append(this.segments.root);
    }

    const icon = kind === "time" ? clockIcon() : kind === "recurrence" ? repeatIcon() : calendarIcon();
    this.trigger = el(
      "button",
      {
        type: "button",
        class: "koyomi-trigger",
        "aria-haspopup": "dialog",
        "aria-expanded": "false",
        "aria-label": this.words.t(kind === "time" ? "showTimes" : "showCalendar"),
        disabled: config.disabled ? "" : null,
      },
      icon,
    );
    this.trigger.addEventListener("click", () => this.toggle());

    if (config.clearable && !config.readonly) {
      this.clearButton = el("button", { type: "button", class: "koyomi-clear", "aria-label": this.words.t("clear"), disabled: config.disabled ? "" : null }, closeIcon());
      this.clearButton.addEventListener("click", () => {
        this.clear();
        this.focus();
      });
      control.append(this.clearButton);
    }
    control.append(this.trigger);
    if (kind === "dates" || kind === "recurrence") {
      // The field itself opens the popover.
      this.chips!.addEventListener("click", (event) => {
        if (!(event.target as HTMLElement).closest("button")) this.open();
      });
    }
    this.root.append(control);
    this.describe();
  }

  private describe(): void {
    const ids = [this.config.describedBy, this.message.textContent ? this.message.id : null].filter(Boolean).join(" ") || null;
    for (const segments of [this.segments, this.toSegments, this.timeSegments]) {
      segments?.setDescribedBy(ids);
      segments?.setInvalid(this.config.invalid === true);
    }
    this.control?.classList.toggle("koyomi-invalid", this.config.invalid === true);
  }

  /** The date segments of a field: day, month and year in the locale's order (or fewer, by kind). */
  private dateSegments(part: "value" | "from" | "to"): Segments {
    const { locale } = this.config;
    const names = fieldNames(locale);
    const placeholders = fieldPlaceholders(locale);
    const calendarId = this.cal.id;
    const isoNumbers = calendarId === "gregory" || calendarId === "iso8601" || calendarId === "japanese";
    // The order and the separators of the locale's numeric dates; the
    // numbers are those of the calendar.
    let parts: Part[] = dateFieldOrder(locale, "gregory") as Part[];

    if (this.kind === "month") parts = withoutField(parts, "day");
    if (this.kind === "year") parts = [{ field: "year" }];
    if (this.kind === "week") parts = [{ literal: `${this.words.t("weekShort")} ` }, { field: "week" }, { literal: ", " }, { field: "year" }];

    const today = this.today;
    const todayFields = isoNumbers ? toYMD(today) : this.cal.fields(today);
    const prefix = part === "from" ? `${this.words.t("startDate")}, ` : part === "to" ? `${this.words.t("endDate")}, ` : "";
    const specs: Partial<Record<SegmentField, SegmentSpec>> = {
      day: { field: "day", label: prefix + names.day, placeholder: placeholders.day, min: 1, max: 31, pad: 2, digits: 2, start: () => todayFields.day },
      month: { field: "month", label: prefix + names.month, placeholder: placeholders.month, min: 1, max: isoNumbers ? 12 : 13, pad: 2, digits: 2, start: () => todayFields.month },
      year: { field: "year", label: prefix + names.year, placeholder: placeholders.year, min: 1, max: 9999, pad: isoNumbers ? 4 : 1, digits: 4, start: () => todayFields.year },
      week: { field: "week", label: prefix + names.weekOfYear, placeholder: "––", min: 1, max: 53, pad: 2, digits: 2, start: () => isoWeek(today).week },
    };

    const segments = new Segments({
      locale,
      parts,
      specs,
      disabled: this.config.disabled,
      readonly: this.config.readonly,
      max: (field, values) => {
        if (field === "day" && values.month && values.year) {
          if (isoNumbers) return new Date(Date.UTC(values.year, values.month, 0)).getUTCDate();
          return null;
        }
        if (field === "week" && values.year) return isoWeeksInYear(values.year);
        return null;
      },
      expandYear: (year) => expandYear(year, toYMD(today).year),
      onChange: () => this.onSegments(part),
      onLetter: (key) => this.openTyping(key),
      onPaste: (text) => this.typeText(text),
      onEnter: () => this.toggle(),
    });
    segments.root.dataset.part = part;
    this.labelSegments(segments);
    return segments;
  }

  private buildTimeSegments(): Segments {
    const { locale } = this.config;
    const names = fieldNames(locale);
    const placeholders = fieldPlaceholders(locale);
    const cycle = this.hourCycle();
    const twelve = cycle === "h12" || cycle === "h11";
    const periods = dayPeriods(locale);
    const parts = timeFieldOrder(locale, { seconds: this.config.seconds, hourCycle: cycle }) as Part[];
    const specs: Partial<Record<SegmentField, SegmentSpec>> = {
      hour: twelve
        ? { field: "hour", label: names.hour, placeholder: placeholders.hour, min: cycle === "h11" ? 0 : 1, max: cycle === "h11" ? 11 : 12, pad: 2, digits: 2, start: () => 9 }
        : { field: "hour", label: names.hour, placeholder: placeholders.hour, min: 0, max: 23, pad: 2, digits: 2, start: () => 9 },
      minute: { field: "minute", label: names.minute, placeholder: placeholders.minute, min: 0, max: 59, pad: 2, digits: 2, start: () => 0 },
      second: { field: "second", label: names.second, placeholder: placeholders.second, min: 0, max: 59, pad: 2, digits: 2, start: () => 0 },
      dayPeriod: {
        field: "dayPeriod",
        label: names.dayPeriod,
        placeholder: periods.am,
        min: 0,
        max: 1,
        pad: 1,
        digits: 1,
        text: (value) => (value === 1 ? periods.pm : periods.am),
        letter: (key) => {
          const k = key.toLocaleLowerCase(locale);
          if (periods.am.toLocaleLowerCase(locale).startsWith(k) || k === "a") return 0;
          if (periods.pm.toLocaleLowerCase(locale).startsWith(k) || k === "p") return 1;
          return null;
        },
        start: () => 0,
      },
    };
    const segments = new Segments({
      locale,
      parts,
      specs,
      disabled: this.config.disabled,
      readonly: this.config.readonly,
      onChange: () => this.onTimeSegments(),
      onPaste: (text) => this.typeText(text),
      onEnter: () => this.toggle(),
    });
    segments.root.dataset.part = "time";
    this.labelSegments(segments);
    return segments;
  }

  // The field (.koyomi-control) is the group with the label; the segments
  // of the inline picker without a field are not labelled twice.
  private labelSegments(_segments: Segments): void {}

  private hourCycle(): "h11" | "h12" | "h23" | "h24" {
    return this.config.hourCycle ?? localeHourCycle(this.config.locale);
  }

  // The panel: in a popover, or on the page.

  private buildPanel(inline: boolean): void {
    const config = this.config;
    const panel = el("div", { class: "koyomi-panel" });
    this.panel = panel;
    const kind = this.kind;

    if (kind === "recurrence") {
      this.recurrence = new RecurrenceEditor({
        id: `${this.id}-rrule`,
        locale: config.locale,
        words: this.words,
        start: parseISO(config.start ?? "") ?? this.today,
        cal: this.cal,
        week: this.week,
        onChange: (rule) => this.setRecurrence(rule, true),
      });
      panel.append(this.recurrence.root);
    } else {
      if (config.typing !== false && kind !== "time" && !config.readonly && !config.disabled && kind !== "calendar") panel.append(this.buildTyping());
      const body = el("div", { class: "koyomi-panel-body" });
      if (config.presets?.length && kind !== "time") body.append(this.buildPresets(config.presets));
      if (kind !== "time") {
        // On a narrow screen the popover is a sheet: one month, or a list
        // of months that scrolls for a range or several days.
        const narrow = window.matchMedia("(max-width: 40rem)").matches;
        this.calendar = new Calendar({
          id: `${this.id}-calendar`,
          cal: this.cal,
          locale: config.locale,
          words: this.words,
          rules: this.rules,
          weekInfo: this.week,
          today: this.today,
          months: narrow && !inline ? 1 : config.months,
          weekNumbers: config.weekNumbers === true,
          outsideDays: config.outsideDays !== false,
          rtl: rtl(config.locale),
          lowest: kind === "month" ? "months" : kind === "year" ? "years" : "days",
          holidays: config.holidays ?? {},
          content: (day) => this.content.get(day),
          onPick: (day) => this.pick(day),
          onShow: (first, last) => this.loadDays(first, last),
          onHover: (day) => this.onHover(day),
          scrolling: !inline && narrow && (kind === "range" || kind === "dates"),
        });
        body.append(this.calendar.root);
      }
      if (kind === "time" || kind === "datetime") {
        this.timeList = new TimeList({
          id: `${this.id}-times`,
          label: this.words.t("showTimes"),
          format: (time) => this.formatTimeOfDay(time),
          rules: this.rules,
          step: this.rules.step ?? 30,
          onPick: (time) => this.pickTime(time),
        });
        body.append(this.timeList.root);
      }
      panel.append(body);
      this.notice = el("div", { class: "koyomi-notice", hidden: "" });
      panel.append(this.notice);
      panel.append(this.buildFooter(inline));
    }

    if (inline) {
      panel.classList.add("koyomi-panel-inline");
      this.root.append(panel);
    } else {
      this.popover = new Popover({
        anchor: this.control!,
        inside: () => [this.control!],
        label: this.labelText || this.words.t("showCalendar"),
        onClose: () => this.onClosed(),
        returnFocus: () => this.focus(),
        initialFocus: () => (this.kind === "time" ? this.timeList!.root : this.kind === "recurrence" ? this.recurrence!.firstFocus() : this.calendar?.root.querySelector<HTMLElement>("[data-stop]") ?? null),
      });
      this.popover.body.append(panel);
      this.popover.mount(this.root);
    }
  }

  private buildTyping(): HTMLElement {
    const id = `${this.id}-type`;
    this.typeBox = el("input", {
      type: "text",
      id,
      class: "koyomi-type",
      autocomplete: "off",
      spellcheck: "false",
      placeholder: this.words.t("typePlaceholder"),
      "aria-label": this.words.t("typeLabel"),
      "aria-describedby": `${id}-preview`,
    });
    this.preview = el("div", { class: "koyomi-type-preview", id: `${id}-preview`, "aria-live": "polite" });
    this.typeBox.addEventListener("input", () => this.onTyping());
    this.typeBox.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        this.commitTyping();
      } else if (event.key === "ArrowDown") {
        event.preventDefault();
        this.calendar?.focus();
      }
    });
    return el("div", { class: "koyomi-typing" }, this.typeBox, this.preview);
  }

  private buildPresets(presets: Preset[]): HTMLElement {
    const list = el("div", { class: "koyomi-presets" });
    for (const preset of presets) {
      const button = el("button", { type: "button", class: "koyomi-preset", "data-preset": preset.id }, this.presetLabel(preset));
      const value = preset.value;
      const disabled = typeof value === "string" ? !this.rules.allowed(parseISO(value)!) : this.rules.checkRange(parseISO(value.from)!, parseISO(value.to)!) !== null;
      if (disabled) button.setAttribute("aria-disabled", "true");
      button.addEventListener("click", () => {
        if (button.getAttribute("aria-disabled") !== "true") this.applyPreset(preset);
      });
      list.append(button);
    }
    return list;
  }

  private presetLabel(preset: Preset): string {
    if (preset.label) return preset.label;
    if (preset.relative) return capitalize(relativeLabel(this.config.locale, preset.relative.n, preset.relative.unit), this.config.locale);
    if (preset.message) return this.words.t(preset.message, { n: preset.n ?? "" });
    return preset.id;
  }

  private buildFooter(inline: boolean): HTMLElement {
    const footer = el("div", { class: "koyomi-footer" });
    const kind = this.kind;
    const button = (label: string, action: () => void, className = "koyomi-action") => {
      const node = el("button", { type: "button", class: className }, label);
      node.addEventListener("click", action);
      footer.append(node);
    };
    if (!this.config.readonly && !this.config.disabled && kind !== "calendar") {
      if (kind === "time") button(this.words.t("now"), () => this.pickTime(nowTime(this.config.timeZone)));
      else if (kind !== "dates") button(this.words.t("today"), () => this.pickToday());
      if (this.config.clearable) button(this.words.t("clear"), () => this.clear());
    }
    if (!inline && (kind === "range" || kind === "dates" || kind === "datetime")) button(this.words.t("done"), () => this.close(), "koyomi-action koyomi-done");
    return footer;
  }

  // Opening and closing.

  open(focus = true): void {
    if (!this.popover || this.config.disabled || this.config.readonly) return;
    if (this.calendar) {
      const day = this.kind === "range" ? (this.from ?? this.draft) : this.kind === "dates" ? [...this.days].sort()[0] ?? null : this.day;
      this.calendar.showDay(day ?? this.clampToRules(this.today));
    }
    this.popover.open(focus);
    this.trigger?.setAttribute("aria-expanded", "true");
    this.calendar?.announceShown();
    this.root.classList.add("koyomi-open");
  }

  close(): void {
    this.popover?.close("api");
  }

  toggle(): void {
    if (this.popover?.isOpen) this.close();
    else this.open();
  }

  private onClosed(): void {
    this.trigger?.setAttribute("aria-expanded", "false");
    this.root.classList.remove("koyomi-open");
    // A range left half chosen keeps its previous value.
    if (this.draft !== null) {
      this.draft = null;
      this.refresh();
    }
    if (this.typeBox) {
      this.typeBox.value = "";
      this.preview!.textContent = "";
    }
  }

  focus(): void {
    if (this.segments) this.segments.focus("first");
    else if (this.timeSegments) this.timeSegments.focus("first");
    else if (this.trigger) this.trigger.focus();
    else this.calendar?.focus();
  }

  private clampToRules(day: Day): Day {
    if (this.rules.min !== null && day < this.rules.min) return this.rules.min;
    if (this.rules.max !== null && day > this.rules.max) return this.rules.max;
    return day;
  }

  // Picking.

  private pick(day: Day): void {
    switch (this.kind) {
      case "date":
        this.setDay(day, true);
        this.announce(this.cal.format(day, "full"));
        this.close();
        break;
      case "datetime":
        this.setDay(day, true);
        this.announce(this.cal.format(day, "full"));
        if (this.config.slots) this.showSlots();
        if (this.time === null) this.timeList?.focus();
        break;
      case "month":
        this.setDay(day, true);
        this.close();
        break;
      case "year":
        this.year = toYMD(day).year;
        this.commit();
        this.close();
        break;
      case "week":
        this.setDay(startOfWeek(day, 1), true);
        this.close();
        break;
      case "range":
        this.pickRangeEnd(day);
        break;
      case "dates":
        this.toggleDay(day);
        break;
      case "calendar":
        this.pickOnCalendar(day);
        break;
      default:
        break;
    }
  }

  private pickRangeEnd(day: Day): void {
    if (this.draft === null) {
      this.draft = day;
      this.announce(`${this.words.t("startDate")}: ${this.cal.format(day, "full")}. ${this.words.t("rangeEndHint")}`);
      this.refresh();
      return;
    }
    const reason = this.rules.checkRange(this.draft, day);
    if (reason && reason.code !== "tooShort") {
      // A second click that cannot end the range starts a new one.
      this.draft = day;
      this.refresh();
      return;
    }
    const from = Math.min(this.draft, day);
    const to = Math.max(this.draft, day);
    this.draft = null;
    this.from = from;
    this.to = to;
    this.commit();
    this.announce(`${this.cal.formatRange(from, to, "full")}, ${this.lengthText(from, to)}`);
    if (!this.config.inline) this.close();
  }

  private toggleDay(day: Day): void {
    if (this.days.has(day)) {
      this.days.delete(day);
    } else {
      if (!this.rules.canAdd(this.days.size)) {
        this.showMessage(this.words.t("errTooMany", { n: this.config.rules?.maxCount ?? 0 }));
        return;
      }
      this.days.add(day);
    }
    this.commit();
    this.announce(this.words.count("dates", this.days.size));
  }

  private pickOnCalendar(day: Day): void {
    switch (this.config.select) {
      case "date":
        this.day = day;
        this.commit();
        break;
      case "range":
        this.pickRangeEnd(day);
        break;
      case "dates":
        this.toggleDay(day);
        break;
      default:
        break;
    }
  }

  private pickTime(time: Seconds): void {
    this.time = time;
    if (this.kind === "datetime" && this.day === null) this.day = this.clampToRules(this.today);
    this.commit();
    this.announce(this.formatTimeOfDay(time));
    if (this.kind === "time" || (this.kind === "datetime" && this.day !== null)) this.close();
  }

  private pickToday(): void {
    const today = this.clampToRules(this.today);
    if (this.kind === "range") {
      this.draft = null;
      this.from = this.to = today;
      this.commit();
      this.close();
    } else if (this.kind === "year") {
      this.year = toYMD(today).year;
      this.commit();
      this.close();
    } else if (this.kind === "month") {
      this.setDay(fromYMD(toYMD(today).year, toYMD(today).month, 1), true);
      this.close();
    } else if (this.kind === "week") {
      this.setDay(startOfWeek(today, 1), true);
      this.close();
    } else {
      this.pick(today);
    }
  }

  private applyPreset(preset: Preset): void {
    const value = preset.value;
    if (typeof value === "string") {
      const day = parseISO(value);
      if (day === null) return;
      if (this.kind === "dates") this.toggleDay(day);
      else this.pick(day);
    } else {
      const from = parseISO(value.from);
      const to = parseISO(value.to);
      if (from === null || to === null) return;
      this.draft = null;
      this.from = from;
      this.to = to;
      this.commit();
      this.announce(`${this.cal.formatRange(from, to, "full")}, ${this.lengthText(from, to)}`);
      this.close();
    }
  }

  private setDay(day: Day | null, commit: boolean): void {
    this.day = day;
    if (commit) this.commit();
  }

  clear(): void {
    this.day = this.time = this.from = this.to = this.draft = this.year = null;
    this.days.clear();
    this.rrule = null;
    this.recurrence?.setRule(null);
    this.commit();
  }

  // The segments.

  private onSegments(part: "value" | "from" | "to"): void {
    const segments = part === "to" ? this.toSegments! : this.segments!;
    const values = segments.values;
    const day = this.dayFromValues(values);
    if (this.kind === "range") {
      if (part === "from") this.from = day;
      else this.to = day;
      if ((this.from === null) === (this.to === null)) this.commit();
      return;
    }
    if (this.kind === "year") {
      this.year = values.year ?? null;
      this.commit();
      return;
    }
    if (this.kind === "week") {
      this.day = values.week && values.year ? fromISOWeek(values.year, Math.min(values.week, isoWeeksInYear(values.year))) : null;
      this.commit();
      return;
    }
    if (segments.complete || segments.empty) {
      this.day = segments.empty ? null : day;
      if (this.kind === "datetime" && this.day !== null && this.config.slots) this.showSlots();
      this.commit();
    }
  }

  private onTimeSegments(): void {
    const segments = this.timeSegments!;
    if (segments.empty) {
      this.time = null;
      this.commit();
      return;
    }
    if (!segments.complete) return;
    const values = segments.values;
    let hour = values.hour ?? 0;
    const cycle = this.hourCycle();
    if (cycle === "h12" || cycle === "h11") hour = (hour % 12) + (values.dayPeriod === 1 ? 12 : 0);
    this.time = hour * 3600 + (values.minute ?? 0) * 60 + (values.second ?? 0);
    this.commit();
  }

  private dayFromValues(values: Values): Day | null {
    const { year, month, day } = values;
    if (this.kind === "month") {
      if (!year || !month) return null;
      return this.isoNumbers() ? fromYMD(year, month, 1) : this.cal.fromFields({ year, month, day: 1 });
    }
    if (!year || !month || !day) return null;
    if (this.isoNumbers()) {
      const result = fromYMD(year, month, day);
      const back = toYMD(result);
      return back.month === month && back.day === day ? result : null;
    }
    return this.cal.fromFields({ year, month, day });
  }

  private isoNumbers(): boolean {
    return this.cal.id === "gregory" || this.cal.id === "iso8601" || this.cal.id === "japanese";
  }

  private valuesOf(day: Day | null): Values {
    if (day === null) return {};
    if (this.kind === "week") {
      const week = isoWeek(day);
      return { week: week.week, year: week.year };
    }
    const fields = this.isoNumbers() ? toYMD(day) : this.cal.fields(day);
    return { year: fields.year, month: fields.month, day: fields.day };
  }

  private timeValues(time: Seconds | null): Values {
    if (time === null) return {};
    const hour = Math.floor(time / 3600);
    const cycle = this.hourCycle();
    const twelve = cycle === "h12" || cycle === "h11";
    return {
      hour: twelve ? (this.hourCycle() === "h11" ? hour % 12 : hour % 12 || 12) : hour,
      minute: Math.floor((time % 3600) / 60),
      second: time % 60,
      dayPeriod: hour >= 12 ? 1 : 0,
    };
  }

  // Typing a date in words.

  private parseMode(): ParseMode {
    const kind = this.kind;
    if (kind === "calendar") return this.config.select === "range" ? "range" : "date";
    if (kind === "recurrence") return "date";
    return kind as ParseMode;
  }

  private parse(text: string): ParseResult | null {
    return parseDate(text, {
      locale: this.config.locale,
      today: this.today,
      now: nowTime(this.config.timeZone),
      mode: this.parseMode(),
      firstDay: this.week.firstDay,
    });
  }

  private openTyping(key: string): void {
    if (!this.typeBox) return;
    if (!this.popover?.isOpen) this.open(false);
    // The letter goes into the box at once, so that the next keys follow it.
    this.typeBox.value += key;
    this.typeBox.focus();
    this.onTyping();
  }

  private onTyping(): void {
    const text = this.typeBox!.value.trim();
    if (!text) {
      this.preview!.textContent = "";
      return;
    }
    const result = this.parse(text);
    this.preview!.textContent = result ? this.describeResult(result) : this.words.t("noMatch");
    this.preview!.classList.toggle("koyomi-no-match", !result);
    if (result && this.calendar) {
      const day = result.kind === "range" ? result.from : result.kind === "time" ? null : result.day;
      if (day !== null) this.calendar.showDay(day);
    }
  }

  private describeResult(result: ParseResult): string {
    switch (result.kind) {
      case "date":
        return this.cal.format(result.day, "full");
      case "range":
        return `${this.cal.formatRange(result.from, result.to, "full")}, ${this.lengthText(result.from, result.to)}`;
      case "datetime":
        return `${this.cal.format(result.day, "full")}, ${this.formatTimeOfDay(result.time)}`;
      case "time":
        return this.formatTimeOfDay(result.time);
    }
  }

  private commitTyping(): void {
    const result = this.parse(this.typeBox!.value);
    if (!result) return;
    this.applyResult(result);
    this.typeBox!.value = "";
    this.preview!.textContent = "";
  }

  /** Text pasted into the field: an ISO date, or words. */
  private typeText(text: string): void {
    const result = this.parse(text);
    if (result) this.applyResult(result);
  }

  private applyResult(result: ParseResult): void {
    switch (result.kind) {
      case "date":
        if (this.kind === "range") {
          this.draft = null;
          this.pickRangeEnd(result.day);
        } else if (this.kind === "dates") this.toggleDay(result.day);
        else if (this.kind === "datetime") {
          this.setDay(result.day, true);
        } else this.pick(result.day);
        break;
      case "range":
        if (this.kind === "range") {
          this.draft = null;
          this.from = result.from;
          this.to = result.to;
          this.commit();
          this.close();
        } else this.pick(result.from);
        break;
      case "datetime":
        this.day = result.day;
        this.time = result.time;
        this.commit();
        this.close();
        break;
      case "time":
        this.pickTime(result.time);
        break;
    }
  }

  // Time zones.

  /** The instant of the value of a date and time picker with a time zone. */
  private resolved(): ReturnType<typeof localToInstant> | null {
    const zone = this.config.timeZone;
    if (this.day === null || this.time === null || !zone) return null;
    return localToInstant(this.day, this.time, zone, this.ambiguous);
  }

  private offsetName(epochMs: number): string {
    try {
      const parts = new Intl.DateTimeFormat(this.config.locale, { timeZone: this.config.timeZone, timeZoneName: "shortOffset" }).formatToParts(new Date(epochMs));
      return parts.find((part) => part.type === "timeZoneName")?.value ?? "";
    } catch {
      return "";
    }
  }

  private zoneName(): string {
    const zone = this.config.timeZone!;
    const at = this.resolved()?.epochMs ?? Date.now();
    try {
      const parts = new Intl.DateTimeFormat(this.config.locale, { timeZone: zone, timeZoneName: "short" }).formatToParts(new Date(at));
      return parts.find((part) => part.type === "timeZoneName")?.value ?? zone;
    } catch {
      return zone;
    }
  }

  private updateNotice(): void {
    if (!this.notice) return;
    this.notice.replaceChildren();
    this.notice.hidden = true;
    const resolved = this.resolved();
    if (!resolved || resolved.status === "ok") return;
    const zone = this.config.timeZone!;
    const time = this.formatTimeOfDay(this.time!);
    if (resolved.status === "gap") {
      const local = instantToLocal(resolved.epochMs!, zone);
      this.notice.append(this.words.t("gap", { time, zone, next: this.formatTimeOfDay(local.time) }));
    } else {
      this.notice.append(el("p", {}, this.words.t("ambiguous", { time, zone })));
      const earlier = localToInstant(this.day!, this.time!, zone, "earlier");
      const later = localToInstant(this.day!, this.time!, zone, "later");
      for (const [which, instant] of [
        ["earlier", earlier],
        ["later", later],
      ] as const) {
        const button = el(
          "button",
          { type: "button", class: "koyomi-action", "aria-pressed": this.ambiguous === which ? "true" : "false" },
          this.words.t(which, { offset: this.offsetName(instant.epochMs!) }),
        );
        button.addEventListener("click", () => {
          this.ambiguous = which;
          this.commit();
        });
        this.notice.append(button);
      }
    }
    this.notice.hidden = false;
  }

  // Slots and day content.

  private showSlots(): void {
    if (!this.timeList || !this.config.slots) return;
    if (this.day === null) {
      this.timeList.setSlots([], null);
      return;
    }
    const content = this.content.get(this.day);
    if (content?.slots) {
      this.timeList.setSlots(content.slots, this.words.t("noSlots"));
    } else if (this.isLoaded(this.day)) {
      this.timeList.setSlots([], this.words.t("noSlots"));
    } else {
      this.timeList.setSlots([], this.words.t("loading"));
    }
    this.timeList.root.setAttribute("aria-label", this.words.t("slotsFor", { date: this.cal.format(this.day, "long") }));
    this.timeList.setSelected(this.time);
  }

  private isLoaded(day: Day): boolean {
    return this.loaded.has(day);
  }

  private loadDays(first: Day, last: Day): void {
    if (!this.config.days || !this.transport) return;
    // A popover's days load when it opens.
    const inline = this.config.inline || this.kind === "calendar";
    if (!inline && !this.popover?.isOpen) return;
    // Ask only for the days not asked for yet, in spans the server takes
    // (Koyomi.Live answers at most 800 days at a time).
    let start: Day | null = null;
    for (let day = first; day <= last + 1; day++) {
      const wanted = day <= last && !this.loaded.has(day);
      if (wanted && start === null) start = day;
      if (start !== null && (!wanted || day - start >= 366)) {
        this.requestDays(start, day - 1);
        start = wanted ? day : null;
      }
    }
  }

  private requestDays(first: Day, last: Day): void {
    for (let day = first; day <= last; day++) this.loaded.add(day);
    const ref = `${this.id}-${++this.refs}`;
    this.pending.set(ref, [first, last]);
    this.calendar?.root.setAttribute("aria-busy", "true");
    this.transport!.push(
      "koyomi:days",
      { id: this.id, from: formatISO(first), to: formatISO(last), ref, timeZone: this.config.timeZone ?? null },
      (reply) => {
        if (reply.pending) return;
        this.receiveDays(reply);
      },
    );
  }

  /** Days from the LiveView: a reply, or a push after an async callback. */
  receiveDays(payload: Record<string, unknown>): void {
    const ref = String(payload.ref ?? "");
    const range = this.pending.get(ref);
    if (!range) return;
    this.pending.delete(ref);
    if (this.pending.size === 0) this.calendar?.root.removeAttribute("aria-busy");
    if (payload.error) {
      // The days may be asked for again, when they are shown again.
      for (let day = range[0]; day <= range[1]; day++) this.loaded.delete(day);
      this.loadError = true;
      this.showMessage(this.words.t("loadError"));
      return;
    }
    this.loadError = false;
    for (let day = range[0]; day <= range[1]; day++) this.content.delete(day);
    const days = (payload.days ?? {}) as Record<string, DayContent>;
    for (const [iso, content] of Object.entries(days)) {
      const day = parseISO(iso);
      if (day !== null) this.content.set(day, content);
    }
    this.refresh();
    if (this.config.slots) this.showSlots();
  }

  /** The LiveView says that the days changed: load the shown days again. */
  refreshDays(): void {
    // A reply to a request made before the change is dropped.
    this.pending.clear();
    this.calendar?.root.removeAttribute("aria-busy");
    this.loaded.clear();
    this.content.clear();
    this.calendar?.setOptions({});
  }

  private onHover(day: Day | null): void {
    if (this.kind !== "range" || this.draft === null || day === null || !this.preview) return;
    if (this.typeBox && this.typeBox.value.trim()) return;
    this.preview.textContent = `${this.cal.formatRange(Math.min(this.draft, day), Math.max(this.draft, day), "medium")}, ${this.lengthText(this.draft, day)}`;
  }

  // The value: from the server, and to the form.

  /** The value of data-value, when the server changed it (or at mount). */
  private applyServerValue(initial = false): void {
    const text = this.root.dataset.value ?? "null";
    if (!initial && text === this.serverValue) return;
    this.serverValue = text;
    let wire: Wire = null;
    try {
      wire = JSON.parse(text) as Wire;
    } catch {
      wire = null;
    }
    // The server sends back what the picker posted (in its own form, a UTC
    // instant for an offset): the picker keeps its state, a resolved
    // daylight-saving notice included.
    if (!initial && sameValue(wire, this.wire())) {
      // In step with the server: a later value from it is a real change.
      this.posted = [];
      return;
    }
    if (!initial && this.posted.some((value) => sameValue(wire, value))) return;
    this.setWire(wire);
    this.writeInputs(false);
    this.refresh();
  }

  /** Sets the value from its wire form, without posting it. */
  setWire(wire: Wire): void {
    this.draft = null;
    switch (this.kind) {
      case "date":
        this.day = typeof wire === "string" ? parseISO(wire) : null;
        break;
      case "range":
        this.from = wire && typeof wire === "object" && !Array.isArray(wire) ? parseISO(wire.from) : null;
        this.to = wire && typeof wire === "object" && !Array.isArray(wire) ? parseISO(wire.to) : null;
        break;
      case "dates":
        this.days = new Set(Array.isArray(wire) ? wire.map((text) => parseISO(text)).filter((day): day is Day => day !== null) : []);
        break;
      case "month":
        this.day = typeof wire === "string" ? parseMonth(wire) : null;
        break;
      case "year":
        this.year = typeof wire === "string" && /^\d{1,4}$/.test(wire) ? Number(wire) : null;
        break;
      case "week":
        this.day = typeof wire === "string" ? parseISOWeek(wire) : null;
        break;
      case "time":
        this.time = typeof wire === "string" ? parseTime(wire) : null;
        break;
      case "datetime": {
        const parsed = typeof wire === "string" ? parseDateTime(wire) : null;
        if (!parsed) {
          this.day = this.time = null;
        } else if (parsed.offset !== null && this.config.timeZone) {
          const epochMs = (parsed.day * 86_400 + parsed.time - parsed.offset * 60) * 1000;
          const local = instantToLocal(epochMs, this.config.timeZone);
          this.day = local.day;
          this.time = local.time;
          const later = localToInstant(local.day, local.time, this.config.timeZone, "later");
          // The server's instant says which of a repeated hour it is.
          if (later.status === "ambiguous") this.ambiguous = later.epochMs === epochMs ? "later" : "earlier";
        } else {
          this.day = parsed.day;
          this.time = parsed.time;
        }
        break;
      }
      case "recurrence":
        this.rrule = typeof wire === "string" && wire ? wire : null;
        this.recurrence?.setRule(this.rrule);
        break;
      case "calendar":
        if (this.config.select === "range") {
          this.from = wire && typeof wire === "object" && !Array.isArray(wire) ? parseISO(wire.from) : null;
          this.to = wire && typeof wire === "object" && !Array.isArray(wire) ? parseISO(wire.to) : null;
        } else if (this.config.select === "dates") {
          this.days = new Set(Array.isArray(wire) ? wire.map((text) => parseISO(text)).filter((day): day is Day => day !== null) : []);
        } else {
          this.day = typeof wire === "string" ? parseISO(wire) : null;
        }
        break;
    }
  }

  /** The value in its wire form. */
  wire(): Wire {
    switch (this.kind) {
      case "date":
        return this.day === null ? null : formatISO(this.day);
      case "range":
        return { from: this.from === null ? null : formatISO(this.from), to: this.to === null ? null : formatISO(this.to) };
      case "dates":
        return [...this.days].sort((a, b) => a - b).map(formatISO);
      case "month":
        return this.day === null ? null : formatMonth(this.day);
      case "year":
        return this.year === null ? null : String(this.year);
      case "week":
        return this.day === null ? null : formatISOWeek(this.day);
      case "time":
        return this.time === null ? null : formatTime(this.time, true);
      case "datetime": {
        if (this.day === null || this.time === null) return null;
        const resolved = this.resolved();
        if (resolved) {
          if (resolved.epochMs === null) return null;
          const local = instantToLocal(resolved.epochMs, this.config.timeZone!);
          return formatDateTime(local.day, local.time, resolved.offset);
        }
        return formatDateTime(this.day, this.time, null);
      }
      case "recurrence":
        return this.rrule;
      case "calendar":
        if (this.config.select === "range") return { from: this.from === null ? null : formatISO(this.from), to: this.to === null ? null : formatISO(this.to) };
        if (this.config.select === "dates") return [...this.days].sort((a, b) => a - b).map(formatISO);
        return this.day === null ? null : formatISO(this.day);
    }
  }

  private setRecurrence(rule: string | null, post: boolean): void {
    this.rrule = rule;
    if (post) this.commit();
  }

  /** Writes the value to the inputs and, with `post`, tells the form; then draws. */
  private commit(post = true): void {
    this.writeInputs(post);
    this.refresh(post);
    if (post && this.config.onChange && this.transport) this.transport.push(this.config.onChange, { id: this.id, value: this.wire() });
  }

  private writeInputs(post: boolean): void {
    const wire = this.wire();
    if (post) this.posted = [...this.posted.slice(-7), wire];
    const changed: HTMLInputElement[] = [];
    const set = (input: HTMLInputElement | null, value: string) => {
      if (!input) return;
      if (input.value !== value) {
        input.value = value;
        changed.push(input);
      }
    };

    if (this.kind === "range" || (this.kind === "calendar" && this.config.select === "range" && this.input("from"))) {
      const range = wire as { from: string | null; to: string | null };
      // Only whole ranges, or none, reach the form.
      if ((range.from === null) !== (range.to === null)) return;
      set(this.input("from"), range.from ?? "");
      set(this.input("to"), range.to ?? "");
    } else if (this.kind === "dates") {
      const sentinel = this.input("sentinel");
      const inputs = [...this.root.querySelectorAll<HTMLInputElement>(':scope > input[data-part="date"]')];
      const values = wire as string[];
      const current = inputs.map((input) => input.value).filter(Boolean);
      if (current.join() !== values.join()) {
        const name = sentinel?.name ?? inputs[0]?.name ?? "";
        inputs.forEach((input) => input.remove());
        let last: HTMLInputElement | null = sentinel;
        for (const value of values) {
          const input = el("input", { type: "text", class: "koyomi-native", "data-part": "date", name, value, tabindex: "-1", "aria-hidden": "true", hidden: "" });
          (last ?? this.root).after(input);
          last = input;
          changed.push(input);
        }
        if (values.length === 0 && sentinel) changed.push(sentinel);
      }
    } else if (this.kind === "calendar") {
      const input = this.input("value");
      if (input) {
        const value = Array.isArray(wire) ? wire.join(",") : wire && typeof wire === "object" ? `${wire.from ?? ""}/${wire.to ?? ""}` : (wire ?? "");
        set(input, value);
      }
    } else {
      const input = this.input("value");
      // The browser's own input cannot hold an offset: the picker posts text.
      if (input && this.kind === "datetime" && input.type !== "text") input.type = "text";
      set(input, (wire as string | null) ?? "");
    }

    // Once the person has picked, every input of the picker is used, so
    // that LiveView sends no _unused_ marker for the other end of a range.
    if (post) for (const input of this.nativeInputs()) input.setAttribute("phx-no-unused-field", "");

    if (post && changed.length > 0) {
      changed[changed.length - 1]!.dispatchEvent(new Event("input", { bubbles: true }));
      changed[changed.length - 1]!.dispatchEvent(new Event("change", { bubbles: true }));
    }
  }

  // Drawing.

  private refresh(validate = false): void {
    const kind = this.kind;
    if (this.segments) {
      if (kind === "range") {
        sync(this.segments, this.valuesOf(this.from), this.from === null);
        sync(this.toSegments!, this.valuesOf(this.to), this.to === null);
      } else if (kind === "year") {
        sync(this.segments, this.year === null ? {} : { year: this.year }, this.year === null);
      } else {
        sync(this.segments, this.valuesOf(this.day), this.day === null);
      }
    }
    if (this.timeSegments) sync(this.timeSegments, this.timeValues(this.time), this.time === null);
    if (this.zoneLabel) this.zoneLabel.textContent = this.zoneName();
    if (kind === "dates" && this.chips) this.drawChips();
    if (kind === "recurrence" && this.chips) this.chips.textContent = this.recurrence?.summary() ?? this.words.t("doesNotRepeat");
    if (this.clearButton) this.clearButton.hidden = !this.hasValue();

    if (this.calendar) this.calendar.setSelection(this.selection());
    if (this.timeList) {
      if (this.config.slots) this.showSlots();
      else this.timeList.setSelected(this.time);
    }
    this.updateNotice();
    if (validate) this.validate();
    this.root.classList.toggle("koyomi-has-value", this.hasValue());
  }

  private selection(): Selection {
    switch (this.kind) {
      case "range":
        return this.draft !== null ? { kind: "range", from: this.draft, to: null } : { kind: "range", from: this.from, to: this.to };
      case "dates":
        return { kind: "multiple", days: this.days };
      case "week":
        return { kind: "week", day: this.day };
      case "year":
        return { kind: "single", day: this.year === null ? null : fromYMD(this.year, 1, 1) };
      case "calendar":
        if (this.config.select === "range") return this.draft !== null ? { kind: "range", from: this.draft, to: null } : { kind: "range", from: this.from, to: this.to };
        if (this.config.select === "dates") return { kind: "multiple", days: this.days };
        if (this.config.select === "date") return { kind: "single", day: this.day };
        return { kind: "none" };
      default:
        return { kind: "single", day: this.day };
    }
  }

  private hasValue(): boolean {
    switch (this.kind) {
      case "range":
        return this.from !== null || this.to !== null;
      case "dates":
        return this.days.size > 0;
      case "year":
        return this.year !== null;
      case "time":
        return this.time !== null;
      case "datetime":
        return this.day !== null || this.time !== null;
      case "recurrence":
        return this.rrule !== null;
      default:
        return this.day !== null;
    }
  }

  private drawChips(): void {
    const chips = this.chips!;
    chips.replaceChildren();
    const sorted = [...this.days].sort((a, b) => a - b);
    if (sorted.length === 0) {
      chips.append(el("span", { class: "koyomi-chips-empty" }, this.labelText ? "" : this.words.t("showCalendar")));
    }
    for (const day of sorted) {
      const text = this.cal.format(day, this.config.display);
      const remove = el("button", { type: "button", class: "koyomi-chip-remove", "aria-label": this.words.t("removeDate", { date: text }), disabled: this.config.disabled || this.config.readonly ? "" : null }, closeIcon());
      remove.addEventListener("click", (event) => {
        event.stopPropagation();
        this.days.delete(day);
        this.commit();
        this.trigger?.focus();
      });
      chips.append(el("span", { class: "koyomi-chip" }, el("span", {}, text), remove));
    }
  }

  /** Checks the value with the rules and shows why it is refused, as the changeset would. */
  private validate(): void {
    let reason: Reason | null = null;
    if (this.kind === "range" && this.from !== null && this.to !== null) reason = this.rules.checkRange(this.from, this.to);
    else if (this.kind === "dates") {
      for (const day of this.days) reason ??= this.rules.checkDay(day);
    } else if ((this.kind === "date" || this.kind === "datetime") && this.day !== null) reason = this.rules.checkDay(this.day);
    if (!reason && (this.kind === "time" || this.kind === "datetime") && this.time !== null) reason = this.rules.checkTime(this.time);
    this.showMessage(reason ? this.reasonText(reason) : "");
  }

  private reasonText(reason: Reason): string {
    const date = (day: Day) => this.cal.format(day, "medium");
    switch (reason.code) {
      case "beforeMin":
        return this.words.t("errBeforeMin", { date: date(reason.day) });
      case "afterMax":
        return this.words.t("errAfterMax", { date: date(reason.day) });
      case "disabled":
        return this.words.t("errDisabled");
      case "disabledInRange":
        return this.words.t("errDisabledInRange");
      case "tooShort":
        return this.words.t("errTooShort", { n: reason.n });
      case "tooLong":
        return this.words.t("errTooLong", { n: reason.n });
      case "tooMany":
        return this.words.t("errTooMany", { n: reason.n });
      case "timeBeforeMin":
        return this.words.t("errTimeBeforeMin", { time: this.formatTimeOfDay(reason.time) });
      case "timeAfterMax":
        return this.words.t("errTimeAfterMax", { time: this.formatTimeOfDay(reason.time) });
      case "timeStep":
        return this.words.t("errTimeStep", { n: reason.n });
    }
  }

  private showMessage(text: string): void {
    if (this.loadError && !text) text = this.words.t("loadError");
    this.message.textContent = text;
    this.describe();
  }

  private announce(text: string): void {
    this.live.textContent = "";
    requestAnimationFrame(() => (this.live.textContent = text));
  }

  private lengthText(a: Day, b: Day): string {
    const days = Math.abs(b - a) + 1;
    return this.config.nights ? this.words.count("nights", days - 1) : this.words.count("days", days);
  }

  private formatTimeOfDay(time: Seconds): string {
    const cycle = this.hourCycle();
    return new Intl.DateTimeFormat(this.config.locale, {
      hour: cycle === "h23" || cycle === "h24" ? "2-digit" : "numeric",
      minute: "2-digit",
      second: this.config.seconds ? "2-digit" : undefined,
      hourCycle: cycle,
      timeZone: "UTC",
    }).format(new Date(time * 1000));
  }

  // From the hook.

  /** The server rendered the picker again: new options, or a new value. */
  update(): void {
    const text = this.root.dataset.config ?? "";
    if (text !== this.configText && sameShape(text, this.configText)) {
      // Only the field's error state changed: no need to build again.
      this.configText = text;
      this.config = readConfig(this.root);
      this.describe();
    } else if (text !== this.configText) {
      // The value stays as it is (a time the clocks skip, as typed); only
      // the field and the panel are built again.
      const wasOpen = this.popover?.isOpen ?? false;
      this.build();
      this.recurrence?.setRule(this.rrule);
      this.refresh();
      if (wasOpen) this.open();
    }
    this.applyServerValue();
  }

  /** The value from Koyomi.Live.push_value: shown, and posted. */
  set(wire: Wire): void {
    this.setWire(wire);
    this.commit();
  }

  destroy(): void {
    this.teardownUI();
    this.message.remove();
    this.live.remove();
    this.root.classList.remove("koyomi-ready");
  }
}

/** Two configs that differ only in the field's error state. */
function sameShape(a: string, b: string): boolean {
  try {
    const strip = (text: string) => {
      const { invalid: _invalid, describedBy: _describedBy, ...rest } = JSON.parse(text) as Record<string, unknown>;
      return JSON.stringify(rest);
    };
    return strip(a) === strip(b);
  } catch {
    return false;
  }
}

function sameValue(a: Wire, b: Wire): boolean {
  if (typeof a === "string" && typeof b === "string") {
    const x = parseDateTime(a);
    const y = parseDateTime(b);
    if (x && y && x.offset !== null && y.offset !== null) {
      return x.day * 86_400 + x.time - x.offset * 60 === y.day * 86_400 + y.time - y.offset * 60;
    }
    if (parseTime(a) !== null && parseTime(a) === parseTime(b)) return true;
  }
  return JSON.stringify(a) === JSON.stringify(b);
}

// Draws a value into a field, unless the person is typing in it: a field
// with the focus, or one half filled while the value is still empty, keeps
// what was typed.
function sync(segments: Segments, values: Values, empty: boolean): void {
  if (segments.contains(document.activeElement)) return;
  if (empty && !segments.empty && !segments.complete) return;
  segments.setValues(values);
}

function withoutField(parts: Part[], field: SegmentField): Part[] {
  const index = parts.findIndex((part) => "field" in part && part.field === field);
  if (index < 0) return parts;
  const copy = [...parts];
  // Drop the field and one literal next to it.
  if (index + 1 < copy.length && "literal" in copy[index + 1]!) copy.splice(index, 2);
  else if (index > 0 && "literal" in copy[index - 1]!) copy.splice(index - 1, 2);
  else copy.splice(index, 1);
  return copy;
}

function expandYear(year: number, current: number): number {
  if (year >= 100) return year;
  const century = Math.floor(current / 100) * 100;
  let full = century + year;
  if (full > current + 50) full -= 100;
  else if (full < current - 50) full += 100;
  return full;
}

function nowTime(timeZone: string | undefined): Seconds {
  const local = instantToLocal(Date.now(), timeZone ?? Intl.DateTimeFormat().resolvedOptions().timeZone);
  return local.time - (local.time % 60);
}

function capitalize(text: string, locale: string): string {
  return text.charAt(0).toLocaleUpperCase(locale) + text.slice(1);
}

export type { FieldPart };
export { formatNumber };
