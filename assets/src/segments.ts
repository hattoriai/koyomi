// A field of segments (day, month, year, hour, minute, second, day period,
// week), in the order and with the separators of the locale. Each segment
// is a spinbutton: digits are typed into it (the next segment takes the
// focus when no other digit fits), the arrow keys change it, Backspace
// clears it.
//
// The segments are contenteditable with inputmode="numeric", so that a
// phone shows its number keyboard; every edit is caught (beforeinput,
// keydown) and the segment's text is always written here, never by the
// browser.

import { el } from "./dom";
import { formatNumber, parseDigits } from "./locale";

export type SegmentField = "era" | "year" | "month" | "day" | "hour" | "minute" | "second" | "dayPeriod" | "week";

export interface SegmentSpec {
  field: SegmentField;
  label: string;
  placeholder: string;
  min: number;
  max: number;
  /** Digits shown (2 for 03); a year shows its own length. */
  pad: number;
  /** Digits that a full value has, to move on without waiting (4 for a year). */
  digits: number;
  /** The text of a value, for a day period (AM/PM) or a month written out. */
  text?: (value: number) => string;
  /** The value of a typed letter (a for AM), for a day period. */
  letter?: (key: string) => number | null;
  /** The value that the arrow keys start from on an empty segment. */
  start?: () => number;
}

export type Part = { field: SegmentField } | { literal: string };

export type Values = Partial<Record<SegmentField, number | null>>;

export interface SegmentsOptions {
  locale: string;
  parts: Part[];
  specs: Partial<Record<SegmentField, SegmentSpec>>;
  /** The largest value of a field given the others (the days of a month). */
  max?: (field: SegmentField, values: Values) => number | null;
  /** A two-digit year typed in full: 27 becomes 2027. */
  expandYear?: (year: number) => number;
  onChange: (values: Values, field: SegmentField) => void;
  /** A letter typed into a numeric segment, for typing a date in words. */
  onLetter?: (key: string) => void;
  /** Text pasted into the field. */
  onPaste?: (text: string) => void;
  /** Enter, for a popover to open or a value to be committed. */
  onEnter?: () => void;
  disabled?: boolean;
  readonly?: boolean;
}

interface Segment {
  spec: SegmentSpec;
  node: HTMLElement;
  value: number | null;
  /** The digits typed since the segment took the focus. */
  typed: string;
}

export class Segments {
  readonly root: HTMLElement;
  private segments: Segment[] = [];
  private before: Segments | null = null;
  private after: Segments | null = null;

  constructor(private options: SegmentsOptions) {
    this.root = el("div", { class: "koyomi-segments" });
    this.build();
  }

  private build(): void {
    this.root.replaceChildren();
    this.segments = [];
    for (const part of this.options.parts) {
      if ("literal" in part) {
        this.root.append(el("span", { class: "koyomi-literal", "aria-hidden": "true" }, part.literal));
        continue;
      }
      const spec = this.options.specs[part.field];
      if (!spec) continue;
      const editable = !this.options.disabled && !this.options.readonly;
      const node = el("span", {
        class: "koyomi-segment",
        role: "spinbutton",
        "data-field": spec.field,
        tabindex: this.options.disabled ? "-1" : "0",
        contenteditable: editable ? "true" : "false",
        inputmode: spec.letter ? "text" : "numeric",
        spellcheck: "false",
        autocorrect: "off",
        autocapitalize: "off",
        enterkeyhint: "next",
        "aria-label": spec.label,
        "aria-valuemin": String(spec.min),
        "aria-valuemax": String(spec.max),
        "aria-disabled": this.options.disabled ? "true" : null,
        "aria-readonly": this.options.readonly ? "true" : null,
      });
      const segment: Segment = { spec, node, value: null, typed: "" };
      this.segments.push(segment);
      node.addEventListener("keydown", (event) => this.onKeydown(segment, event));
      node.addEventListener("beforeinput", (event) => this.onBeforeInput(segment, event));
      node.addEventListener("focus", () => this.onFocus(segment));
      node.addEventListener("blur", () => this.onBlur(segment));
      node.addEventListener("paste", (event) => {
        event.preventDefault();
        const text = event.clipboardData?.getData("text") ?? "";
        if (text.trim()) this.options.onPaste?.(text.trim());
      });
      // A click selects the segment rather than placing a caret in it.
      node.addEventListener("pointerdown", (event) => {
        if (document.activeElement !== node) {
          event.preventDefault();
          node.focus();
        }
      });
      this.root.append(node);
      this.paint(segment);
    }
  }

  /** The fields before and after this one, which the focus flows into. */
  link(before: Segments | null, after: Segments | null): void {
    this.before = before;
    this.after = after;
  }

  get values(): Values {
    const values: Values = {};
    for (const segment of this.segments) values[segment.spec.field] = segment.value;
    return values;
  }

  /** Sets every segment (a field left out, or null, is cleared). */
  setValues(values: Values): void {
    for (const segment of this.segments) {
      segment.value = values[segment.spec.field] ?? null;
      segment.typed = "";
      this.paint(segment);
    }
  }

  /** Every segment has a value, and no year is half typed (27 of 2027). */
  get complete(): boolean {
    return this.segments.every(
      (segment) => segment.value !== null && !(segment.spec.field === "year" && segment.typed !== "" && segment.typed.length < segment.spec.digits),
    );
  }

  get empty(): boolean {
    return this.segments.every((segment) => segment.value === null);
  }

  focus(which: "first" | "last" | SegmentField = "first"): void {
    const segment =
      which === "first" ? this.segments[0] : which === "last" ? this.segments[this.segments.length - 1] : this.segments.find((s) => s.spec.field === which);
    segment?.node.focus();
  }

  contains(node: Node | null): boolean {
    return node !== null && this.root.contains(node);
  }

  setAria(name: string, value: string | null): void {
    if (value === null) this.root.removeAttribute(name);
    else this.root.setAttribute(name, value);
  }

  setInvalid(invalid: boolean): void {
    for (const segment of this.segments) {
      if (invalid) segment.node.setAttribute("aria-invalid", "true");
      else segment.node.removeAttribute("aria-invalid");
    }
  }

  setDescribedBy(ids: string | null): void {
    for (const segment of this.segments) {
      if (ids) segment.node.setAttribute("aria-describedby", ids);
      else segment.node.removeAttribute("aria-describedby");
    }
  }

  private maxOf(segment: Segment): number {
    return this.options.max?.(segment.spec.field, this.values) ?? segment.spec.max;
  }

  private paint(segment: Segment): void {
    const { spec, node, value } = segment;
    const { locale } = this.options;
    if (value === null && segment.typed === "") {
      node.textContent = spec.placeholder;
      node.classList.add("koyomi-placeholder");
      node.removeAttribute("aria-valuenow");
      node.setAttribute("aria-valuetext", "");
    } else {
      const shown = segment.typed !== "" && value === null ? Number(segment.typed) : value!;
      const text = spec.text ? spec.text(shown) : formatNumber(shown, locale, segment.typed !== "" ? segment.typed.length : spec.pad);
      node.textContent = text;
      node.classList.remove("koyomi-placeholder");
      node.setAttribute("aria-valuenow", String(shown));
      node.setAttribute("aria-valuetext", spec.text ? text : String(shown));
    }
    node.setAttribute("aria-valuemax", String(this.maxOf(segment)));
  }

  private set(segment: Segment, value: number | null): void {
    segment.value = value;
    this.paint(segment);
    // A later segment's own maximum may have changed (31 March to February).
    for (const other of this.segments) {
      if (other !== segment && other.value !== null && other.value > this.maxOf(other) && other.spec.field === "day") {
        other.value = this.maxOf(other);
        this.paint(other);
      }
    }
    this.options.onChange(this.values, segment.spec.field);
  }

  private next(segment: Segment): void {
    const index = this.segments.indexOf(segment);
    const next = this.segments[index + 1];
    if (next) next.node.focus();
    else this.after?.focus("first");
  }

  private previous(segment: Segment): void {
    const index = this.segments.indexOf(segment);
    const previous = this.segments[index - 1];
    if (previous) previous.node.focus();
    else this.before?.focus("last");
  }

  private onFocus(segment: Segment): void {
    segment.typed = "";
    const selection = window.getSelection();
    if (selection) {
      const range = document.createRange();
      range.selectNodeContents(segment.node);
      selection.removeAllRanges();
      selection.addRange(range);
    }
  }

  private onBlur(segment: Segment): void {
    if (segment.spec.field === "year" && segment.typed.length > 0 && segment.typed.length <= 2 && segment.value !== null && this.options.expandYear) {
      segment.typed = "";
      this.set(segment, this.options.expandYear(segment.value));
      return;
    }
    if (segment.typed !== "") {
      segment.typed = "";
      if (segment.value !== null && segment.value < segment.spec.min) this.set(segment, null);
      else if (segment.spec.field === "year") this.set(segment, segment.value);
      else this.paint(segment);
    }
  }

  private onBeforeInput(segment: Segment, event: InputEvent): void {
    event.preventDefault();
    if (this.options.disabled || this.options.readonly) return;
    if (event.inputType.startsWith("delete")) {
      this.backspace(segment);
      return;
    }
    const data = event.data ?? "";
    for (const char of data) this.type(segment, char);
  }

  private onKeydown(segment: Segment, event: KeyboardEvent): void {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    const rtl = getComputedStyle(this.root).direction === "rtl";
    switch (event.key) {
      case "ArrowUp":
      case "ArrowDown":
        event.preventDefault();
        if (!this.options.readonly && !this.options.disabled) this.step(segment, event.key === "ArrowUp" ? 1 : -1);
        return;
      case "PageUp":
      case "PageDown":
        event.preventDefault();
        if (!this.options.readonly && !this.options.disabled) this.step(segment, event.key === "PageUp" ? bigStep(segment.spec) : -bigStep(segment.spec));
        return;
      case "Home":
      case "End":
        event.preventDefault();
        if (!this.options.readonly && !this.options.disabled) this.set(segment, event.key === "Home" ? segment.spec.min : this.maxOf(segment));
        return;
      case "ArrowLeft":
        event.preventDefault();
        if (rtl) this.next(segment);
        else this.previous(segment);
        return;
      case "ArrowRight":
        event.preventDefault();
        if (rtl) this.previous(segment);
        else this.next(segment);
        return;
      case "Backspace":
      case "Delete":
        event.preventDefault();
        if (!this.options.readonly && !this.options.disabled) this.backspace(segment);
        return;
      case "Enter":
        event.preventDefault();
        this.options.onEnter?.();
        return;
      case "Tab":
        return;
    }
    if (event.key.length === 1) {
      event.preventDefault();
      if (!this.options.readonly && !this.options.disabled) this.type(segment, event.key);
    }
  }

  private type(segment: Segment, char: string): void {
    const digit = parseDigits(char);
    if (/^[0-9]$/.test(digit) && !segment.spec.letter) {
      this.typeDigit(segment, digit);
      return;
    }
    if (segment.spec.letter) {
      const value = segment.spec.letter(char);
      if (value !== null) {
        this.set(segment, value);
        this.next(segment);
      }
      return;
    }
    // A separator moves on; a letter is the start of a date in words.
    if (/[\s/.\-:,]/.test(char)) {
      if (segment.typed !== "") this.next(segment);
      return;
    }
    if (/\p{L}/u.test(char)) this.options.onLetter?.(char);
  }

  private typeDigit(segment: Segment, digit: string): void {
    const { spec } = segment;
    const max = this.maxOf(segment);
    let typed = segment.typed + digit;
    // A full segment starts again with the new digit.
    if (typed.length > Math.max(spec.digits, String(max).length)) typed = digit;
    let value = Number(typed);
    if (value > max) {
      typed = digit;
      value = Number(digit);
    }
    segment.typed = typed;
    if (value >= spec.min || spec.field === "year") {
      this.set(segment, value);
    } else {
      // 0 typed into a day: wait for the next digit.
      segment.value = null;
      this.paint(segment);
    }
    const full = typed.length >= spec.digits || value * 10 > max;
    if (full && segment.value !== null) {
      segment.typed = "";
      this.next(segment);
    }
  }

  private backspace(segment: Segment): void {
    if (segment.value === null && segment.typed === "") {
      this.previous(segment);
      return;
    }
    if (segment.typed.length > 1) {
      segment.typed = segment.typed.slice(0, -1);
      this.set(segment, Number(segment.typed));
    } else {
      segment.typed = "";
      this.set(segment, null);
    }
  }

  private step(segment: Segment, delta: number): void {
    const min = segment.spec.min;
    const max = this.maxOf(segment);
    segment.typed = "";
    if (segment.value === null) {
      this.set(segment, segment.spec.start?.() ?? min);
      return;
    }
    const span = max - min + 1;
    const value = segment.spec.field === "year" ? segment.value + delta : ((((segment.value - min + delta) % span) + span) % span) + min;
    this.set(segment, value);
  }
}

function bigStep(spec: SegmentSpec): number {
  switch (spec.field) {
    case "year":
      return 10;
    case "minute":
    case "second":
      return 10;
    case "day":
      return 7;
    case "hour":
      return 6;
    default:
      return 3;
  }
}
