// The list of times in the popover of a time picker: every `step` minutes
// between the rules' bounds, or the slots that the LiveView gives for a
// day. A listbox: the arrow keys move, Enter or a click picks.

import { el } from "./dom";
import { type Seconds, formatTime, parseTime } from "./iso";
import type { Rules } from "./rules";
import type { Slot } from "./config";

export interface TimeOption {
  time: Seconds;
  label: string;
  disabled: boolean;
}

export interface TimeListOptions {
  id: string;
  label: string;
  format: (time: Seconds) => string;
  rules: Rules;
  step: number;
  onPick: (time: Seconds) => void;
}

export class TimeList {
  readonly root: HTMLElement;
  private options: TimeOption[] = [];
  private selected: Seconds | null = null;
  private active = 0;
  private empty: string | null = null;

  constructor(private config: TimeListOptions) {
    this.root = el("div", { class: "koyomi-times", role: "listbox", id: config.id, "aria-label": config.label, tabindex: "0" });
    this.root.addEventListener("click", (event) => {
      const option = (event.target as HTMLElement).closest<HTMLElement>("[role=option]");
      if (option && option.getAttribute("aria-disabled") !== "true") this.config.onPick(Number(option.dataset.time));
    });
    this.root.addEventListener("keydown", (event) => this.onKeydown(event));
    this.setSlots(null);
  }

  /** The slots of a day, or null for every step of the rules. `empty` is shown when there is none. */
  setSlots(slots: Slot[] | null, empty: string | null = null): void {
    this.empty = empty;
    if (slots) {
      this.options = slots
        .map((slot) => ({ time: parseTime(slot.time), label: slot.label, disabled: slot.disabled === true }))
        .filter((slot): slot is { time: Seconds; label: string | undefined; disabled: boolean } => slot.time !== null)
        .map((slot) => ({ time: slot.time, label: slot.label ?? this.config.format(slot.time), disabled: slot.disabled || this.config.rules.checkTime(slot.time)?.code === "timeBeforeMin" || this.config.rules.checkTime(slot.time)?.code === "timeAfterMax" }));
    } else {
      const { rules } = this.config;
      const step = Math.max(1, this.config.step) * 60;
      const first = rules.minTime !== null ? Math.ceil(rules.minTime / step) * step : 0;
      const last = rules.maxTime ?? 86_399;
      this.options = [];
      for (let time = first; time <= last; time += step) this.options.push({ time, label: this.config.format(time), disabled: false });
    }
    this.render();
  }

  setSelected(time: Seconds | null): void {
    this.selected = time;
    const index = this.options.findIndex((option) => option.time === time);
    if (index >= 0) this.active = index;
    else if (time !== null) this.active = this.nearest(time);
    this.render();
  }

  focus(): void {
    this.root.focus();
    this.scrollToActive();
  }

  private nearest(time: Seconds): number {
    let best = 0;
    this.options.forEach((option, index) => {
      if (Math.abs(option.time - time) < Math.abs(this.options[best]!.time - time)) best = index;
    });
    return best;
  }

  private render(): void {
    this.root.replaceChildren();
    if (this.options.length === 0) {
      this.root.append(el("div", { class: "koyomi-times-empty" }, this.empty ?? ""));
      this.root.removeAttribute("aria-activedescendant");
      return;
    }
    this.active = Math.min(this.active, this.options.length - 1);
    this.options.forEach((option, index) => {
      const id = `${this.config.id}-${formatTime(option.time, true).replace(/:/g, "")}`;
      this.root.append(
        el(
          "div",
          {
            role: "option",
            id,
            class: "koyomi-time",
            "data-time": String(option.time),
            "aria-selected": option.time === this.selected ? "true" : "false",
            "aria-disabled": option.disabled ? "true" : null,
            "data-active": index === this.active ? "" : null,
          },
          option.label,
        ),
      );
      if (index === this.active) this.root.setAttribute("aria-activedescendant", id);
    });
    requestAnimationFrame(() => this.scrollToActive());
  }

  private scrollToActive(): void {
    const node = this.root.querySelector<HTMLElement>("[data-active]");
    if (node && typeof node.scrollIntoView === "function") node.scrollIntoView({ block: "nearest" });
  }

  private onKeydown(event: KeyboardEvent): void {
    const moves: Record<string, number> = { ArrowDown: 1, ArrowUp: -1, PageDown: 4, PageUp: -4, Home: -Infinity, End: Infinity };
    if (event.key in moves) {
      event.preventDefault();
      const next = this.active + moves[event.key]!;
      this.active = Math.max(0, Math.min(this.options.length - 1, Number.isFinite(next) ? next : next > 0 ? this.options.length - 1 : 0));
      this.render();
    } else if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      const option = this.options[this.active];
      if (option && !option.disabled) this.config.onPick(option.time);
    }
  }
}
