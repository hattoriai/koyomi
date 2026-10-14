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

function icon(paths: string[], className = "koyomi-icon"): SVGSVGElement {
  const svg = document.createElementNS(SVG, "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("focusable", "false");
  svg.setAttribute("class", className);
  for (const d of paths) {
    const path = document.createElementNS(SVG, "path");
    path.setAttribute("d", d);
    svg.append(path);
  }
  return svg;
}

export function chevron(direction: "left" | "right" | "down"): SVGSVGElement {
  const paths = { left: "M14.5 6 8.5 12l6 6", right: "M9.5 6l6 6-6 6", down: "M6 9.5l6 6 6-6" };
  return icon([paths[direction]]);
}

export function calendarIcon(): SVGSVGElement {
  return icon(["M7 3v3M17 3v3", "M4.5 6.5h15v13h-15z", "M4.5 10.5h15"]);
}

export function clockIcon(): SVGSVGElement {
  return icon(["M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17z", "M12 7.5V12l3 2"]);
}

export function repeatIcon(): SVGSVGElement {
  return icon(["M17 3.5l3 3-3 3", "M4 11.5v-1a4 4 0 0 1 4-4h12", "M7 20.5l-3-3 3-3", "M20 12.5v1a4 4 0 0 1-4 4H4"]);
}

export function closeIcon(): SVGSVGElement {
  return icon(["M6.5 6.5l11 11M17.5 6.5l-11 11"]);
}

/** Visually hidden text for screen readers. */
export function srOnly(text: string): HTMLElement {
  return el("span", { class: "koyomi-sr-only" }, text);
}
