// Small DOM helpers: elements from attributes and children, and the icons.

type Attrs = Record<string, string | null | undefined>;

/** An element with attributes (null and undefined are left out) and children. */
export function el<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Attrs = {}, ...children: (Node | string)[]): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  for (const [name, value] of Object.entries(attrs)) {
    if (value !== null && value !== undefined) node.setAttribute(name, value);
  }
  node.append(...children);
  return node;
}

const SVG = "http://www.w3.org/2000/svg";

// The icons are Lucide's (https://lucide.dev, ISC licence, see NOTICE):
// the SVG shapes of each, copied from the lucide-static package, 24 × 24
// and stroke only. The bundle does not import Lucide.

type Shape = readonly [tag: "path" | "rect" | "circle", attributes: Readonly<Record<string, string>>];

/** The icons that an app may replace with `setIcons`. */
export type IconName = "chevron" | "calendar" | "clock" | "repeat" | "close";

/** An icon of the app: the markup of one element, or a function that makes one. */
export type IconSource = string | (() => Element);

const ICONS: Readonly<Record<IconName, readonly Shape[]>> = {
  /** Lucide `chevron-right`; mirrored for the other way. */
  chevron: [["path", { d: "m9 18 6-6-6-6" }]],
  /** Lucide `calendar`. */
  calendar: [
    ["path", { d: "M8 2v3" }],
    ["path", { d: "M16 2v3" }],
    ["rect", { x: "3", y: "3", width: "18", height: "18", rx: "2" }],
    ["path", { d: "M3 9h18" }],
  ],
  /** Lucide `clock`. */
  clock: [
    ["circle", { cx: "12", cy: "12", r: "10" }],
    ["path", { d: "M12 6v6l4 2" }],
  ],
  /** Lucide `repeat`. */
  repeat: [
    ["path", { d: "m17 2 4 4-4 4" }],
    ["path", { d: "M3 11v-1a4 4 0 0 1 4-4h14" }],
    ["path", { d: "m7 22-4-4 4-4" }],
    ["path", { d: "M21 13v1a4 4 0 0 1-4 4H3" }],
  ],
  /** Lucide `x`. */
  close: [
    ["path", { d: "M18 6 6 18" }],
    ["path", { d: "m6 6 12 12" }],
  ],
};

const custom = new Map<IconName, () => Element>();

/**
 * Replaces the icons of the pickers with the app's own, for the pickers
 * mounted after the call: call it before `liveSocket.connect()` or
 * `mountKoyomi()`. Each value is the markup of one element (an `<svg>`,
 * or an element whose class draws the icon) or a function that returns a
 * new element; `null` brings back Koyomi's icon. The `chevron` points to
 * the right, to the next month, and is mirrored for the previous one.
 */
export function setIcons(icons: Partial<Record<IconName, IconSource | null>>): void {
  for (const [name, source] of Object.entries(icons) as [string, IconSource | null | undefined][]) {
    if (!Object.prototype.hasOwnProperty.call(ICONS, name)) {
      console.warn(`Koyomi: no icon is named "${name}"`);
    } else if (source === null || source === undefined) {
      custom.delete(name as IconName);
    } else if (typeof source === "function") {
      custom.set(name as IconName, source);
    } else {
      const template = document.createElement("template");
      template.innerHTML = source.trim();
      const element = template.content.firstElementChild;
      if (element && template.content.childElementCount === 1) custom.set(name as IconName, () => element.cloneNode(true) as Element);
      else console.warn(`Koyomi: the "${name}" icon must be the markup of one element`);
    }
  }
}

function icon(name: IconName, mirrored = false): Element {
  const make = custom.get(name);
  const node = make ? make() : builtIn(name);
  node.classList.add("koyomi-icon");
  if (mirrored) node.classList.add("koyomi-icon-mirrored");
  node.setAttribute("data-icon", name);
  node.setAttribute("aria-hidden", "true");
  if (make) node.setAttribute("data-custom", "");
  if (node instanceof SVGElement) node.setAttribute("focusable", "false");
  return node;
}

function builtIn(name: IconName): SVGSVGElement {
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  for (const [tag, attributes] of ICONS[name]) {
    const shape = document.createElementNS(SVG, tag);
    for (const [attribute, value] of Object.entries(attributes)) shape.setAttribute(attribute, value);
    svg.append(shape);
  }
  return svg;
}

export function chevron(direction: "left" | "right"): Element {
  return icon("chevron", direction === "left");
}

export function calendarIcon(): Element {
  return icon("calendar");
}

export function clockIcon(): Element {
  return icon("clock");
}

export function repeatIcon(): Element {
  return icon("repeat");
}

export function closeIcon(): Element {
  return icon("close");
}

/** Visually hidden text for screen readers. */
export function srOnly(text: string): HTMLElement {
  return el("span", { class: "koyomi-sr-only" }, text);
}
