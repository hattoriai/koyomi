// The popover of a picker: a dialog next to the field, in the top layer
// when the browser has the popover attribute (so that no overflow: hidden
// of the page clips it), placed below the field or above it when there is
// no room, and a sheet at the bottom of the screen on a narrow screen.
//
// It closes on Escape, on a press outside it and the field, and when the
// picker asks; it gives the focus back to the field when it closed from
// inside. Tab stays in it while it is open.

import { el } from "./dom";

const NARROW = "(max-width: 40rem)";

export interface PopoverOptions {
  anchor: HTMLElement;
  /** Elements whose presses do not close the popover (the field). */
  inside: () => HTMLElement[];
  label: string;
  onClose: (reason: "escape" | "outside" | "api") => void;
  /** Gives the focus back to the field, when the popover closed from inside. */
  returnFocus: () => void;
  /** The element to focus when the popover opens. */
  initialFocus: () => HTMLElement | null;
}

const supportsPopover = typeof HTMLElement !== "undefined" && "popover" in HTMLElement.prototype;

export class Popover {
  readonly root: HTMLElement;
  readonly body: HTMLElement;
  private backdrop: HTMLElement;
  private openState = false;
  private cleanup: (() => void)[] = [];

  constructor(private options: PopoverOptions) {
    this.body = el("div", { class: "koyomi-popover-body" });
    this.root = el("div", { class: "koyomi-popover", role: "dialog", "aria-label": options.label, hidden: "" }, this.body);
    this.backdrop = el("div", { class: "koyomi-backdrop", hidden: "" });
    if (supportsPopover) this.root.setAttribute("popover", "manual");
  }

  get isOpen(): boolean {
    return this.openState;
  }

  setLabel(label: string): void {
    this.root.setAttribute("aria-label", label);
  }

  /** Puts the popover in the page, after the anchor's container. */
  mount(parent: HTMLElement): void {
    parent.append(this.backdrop, this.root);
  }

  open(focus = true): void {
    if (this.openState) return;
    this.openState = true;
    const sheet = window.matchMedia(NARROW).matches;
    this.root.classList.toggle("koyomi-sheet", sheet);
    this.backdrop.hidden = !sheet;
    this.root.hidden = false;
    if (supportsPopover) {
      try {
        this.root.showPopover();
      } catch {
        // Not connected yet, or already shown.
      }
    }
    this.place();

    const onPointer = (event: PointerEvent) => {
      const target = event.target as Node;
      if (this.root.contains(target)) return;
      if (this.options.inside().some((node) => node.contains(target))) return;
      this.close("outside");
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !event.defaultPrevented) {
        event.preventDefault();
        event.stopPropagation();
        this.close("escape");
      } else if (event.key === "Tab") {
        this.trapTab(event);
      }
    };
    const onMove = () => this.place();
    document.addEventListener("pointerdown", onPointer, true);
    this.root.addEventListener("keydown", onKey);
    window.addEventListener("resize", onMove);
    window.addEventListener("scroll", onMove, true);
    this.cleanup = [
      () => document.removeEventListener("pointerdown", onPointer, true),
      () => this.root.removeEventListener("keydown", onKey),
      () => window.removeEventListener("resize", onMove),
      () => window.removeEventListener("scroll", onMove, true),
    ];
    if (focus) requestAnimationFrame(() => this.options.initialFocus()?.focus());
  }

  close(reason: "escape" | "outside" | "api" = "api"): void {
    if (!this.openState) return;
    this.openState = false;
    const hadFocus = this.root.contains(document.activeElement);
    for (const undo of this.cleanup) undo();
    this.cleanup = [];
    if (supportsPopover) {
      try {
        this.root.hidePopover();
      } catch {
        // Already hidden.
      }
    }
    this.root.hidden = true;
    this.backdrop.hidden = true;
    this.options.onClose(reason);
    if (hadFocus && reason !== "outside") this.options.returnFocus();
  }

  /** Places the popover below the anchor, or above it when it does not fit below. */
  place(): void {
    if (!this.openState || this.root.classList.contains("koyomi-sheet")) return;
    const anchor = this.options.anchor.getBoundingClientRect();
    const width = this.root.offsetWidth;
    const height = this.root.offsetHeight;
    const gap = 4;
    const viewport = { width: document.documentElement.clientWidth, height: window.innerHeight };
    const rtl = getComputedStyle(this.options.anchor).direction === "rtl";

    // Below the anchor; above it when it fits there and not below; else on
    // the side with more room, moved up as far as it must to be seen.
    let top = anchor.bottom + gap;
    if (top + height > viewport.height) {
      const above = anchor.top - gap - height;
      if (above >= 0) top = above;
      else if (anchor.top > viewport.height - anchor.bottom) top = 8;
      else top = Math.max(8, viewport.height - height - 8);
    }
    let left = rtl ? anchor.right - width : anchor.left;
    left = Math.max(8, Math.min(left, viewport.width - width - 8));

    // In the top layer the popover is fixed to the viewport; otherwise it
    // is absolute in the picker, which is the containing block.
    if (supportsPopover) {
      this.root.style.position = "fixed";
      this.root.style.top = `${Math.max(8, top)}px`;
      this.root.style.left = `${left}px`;
    } else {
      const parent = (this.root.offsetParent ?? document.body).getBoundingClientRect();
      this.root.style.position = "absolute";
      this.root.style.top = `${top - parent.top}px`;
      this.root.style.left = `${left - parent.left}px`;
    }
    this.root.dataset.side = top < anchor.top ? "top" : "bottom";
  }

  private trapTab(event: KeyboardEvent): void {
    const focusable = [...this.root.querySelectorAll<HTMLElement>("button, input, select, [tabindex='0'], [contenteditable='true']")].filter(
      (node) => !node.hasAttribute("disabled") && node.offsetParent !== null && node.tabIndex >= 0,
    );
    if (focusable.length === 0) return;
    const first = focusable[0]!;
    const last = focusable[focusable.length - 1]!;
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  destroy(): void {
    this.close("api");
    this.root.remove();
    this.backdrop.remove();
  }
}
