# Theming

Koyomi has two style sheets:

* `koyomi.css`: the structure of the pickers (the field, the popover, the
  calendar, the time list, the recurrence editor). Every colour, font,
  space and radius comes from a `--koyomi-*` custom property. The
  defaults are Kotoba's, so that a page with both looks like one thing.
* `koyomi-sumi.css`: the Sumi theme. Sumi is the design system of Hattori
  AI, the makers of Koyomi. The theme sets the `--koyomi-*` properties
  from the Sumi tokens, and it also works on a page that does not use
  Sumi.

```css
/* assets/css/app.css */
@import "../../deps/koyomi/priv/static/koyomi.css";
@import "../../deps/koyomi/priv/static/koyomi-sumi.css"; /* optional */
```

## The properties

The defaults of `koyomi.css` have no specificity (`:where(:root)`), so a
value that you set on `:root`, on an ancestor or on `.koyomi` wins:

```css
.koyomi {
  --koyomi-accent: #0f766e;
  --koyomi-radius: 0;
}
```

The popover is a child of the picker's element, also when the browser
shows it in the top layer, so it takes the properties set on `.koyomi`
or on an ancestor.

### Type

| Property | Default | Use |
|---|---|---|
| `--koyomi-font` | `system-ui, …` | the text of the field and the popover |
| `--koyomi-font-size` | `1rem` | the text size |
| `--koyomi-small` | `0.875em` | small text (the zone, chips, the message, presets, notices) |
| `--koyomi-line-height` | `1.4` | the line height |

### Colours

| Property | Default | Use |
|---|---|---|
| `--koyomi-text` | `#1f1f23` | the text colour |
| `--koyomi-muted` | `#6b6b76` | placeholders, weekday names, days outside the month |
| `--koyomi-background` | `#ffffff` | the field |
| `--koyomi-surface` | `#f6f6f7` | hovered days and buttons, a read-only field |
| `--koyomi-border` | `#d9d9de` | borders |
| `--koyomi-accent` | `#2f5bd3` | the selected day, the ends of a range, focus |
| `--koyomi-accent-text` | `#ffffff` | text on the accent |

### Range and states

| Property | Default | Use |
|---|---|---|
| `--koyomi-range` | the accent at 12% | the band behind the days of a range, and a selected week |
| `--koyomi-range-preview` | the accent at 8% | the range drawn while the pointer moves, a hovered week |
| `--koyomi-today` | the accent | today's number and the line under it |
| `--koyomi-holiday` | a red mixed with the text colour | a holiday (its number is also underlined with dots) |
| `--koyomi-weekend` | the muted colour | the days of the weekend |
| `--koyomi-disabled` | the muted colour at 55% | days, months, years and times that may not be chosen |
| `--koyomi-invalid` | a red mixed with the text colour | the border of an invalid field, the message under it |

### Tones

The tones of day content (`:tone` and `:marks` in `Koyomi.Live`):

| Property | Default |
|---|---|
| `--koyomi-tone-accent` | the accent |
| `--koyomi-tone-success` | a green mixed with the text colour |
| `--koyomi-tone-warning` | an orange mixed with the text colour |
| `--koyomi-tone-danger` | a red mixed with the text colour |
| `--koyomi-tone-muted` | the muted colour |

A day or a mark with a tone has `data-tone`, and sets `--koyomi-tone` to
the tone's property; the label and the marks read `--koyomi-tone`.

### Shape and space

| Property | Default | Use |
|---|---|---|
| `--koyomi-radius` | `6px` | corners |
| `--koyomi-space` | `0.5rem` | gaps |
| `--koyomi-field-height` | `2.5rem`, `2.75rem` on a touch screen | the height of the field |
| `--koyomi-field-padding` | `0 0.5rem 0 0.75rem` | the padding of the field |
| `--koyomi-day-size` | `2.25rem`, `2.75rem` on a touch screen | the width and height of a day |
| `--koyomi-icon-size` | `18px` | icons; `14px` in the clear button, `12px` in a chip's remove button |
| `--koyomi-focus-ring` | a 2px gap and a 2px accent ring | the `box-shadow` of focus |
| `--koyomi-transition` | `120ms ease-out` | hover and focus transitions, the popover's entrance |

"A touch screen" is `(pointer: coarse)`. The clear and chip buttons set
their own `--koyomi-icon-size`, so a value set on `.koyomi` does not
reach them: set it on `.koyomi-clear` or `.koyomi-chip-remove`.

### Popover

| Property | Default | Use |
|---|---|---|
| `--koyomi-floating-background` | the background | the popover |
| `--koyomi-floating-text` | the text colour | the text of the popover |
| `--koyomi-floating-border` | the border colour | its border |
| `--koyomi-floating-shadow` | `--koyomi-shadow` | its shadow |
| `--koyomi-floating-radius` | the radius plus `2px` | its corners (the top corners of a sheet) |
| `--koyomi-shadow` | a soft shadow | the default of the floating shadow |
| `--koyomi-backdrop` | black at 32% | the backdrop behind a sheet |

On a screen narrower than `40rem`, the popover is a sheet at the bottom
of the screen, with a backdrop.

## Dark mode without Sumi

`koyomi.css` has one light palette. For a dark theme, set the colour
properties in your own dark rule:

```css
[data-theme="dark"] .koyomi,
.dark .koyomi {
  --koyomi-text: #e7e5e4;
  --koyomi-muted: #a8a29e;
  --koyomi-background: #1c1917;
  --koyomi-surface: #292524;
  --koyomi-border: #44403c;
  --koyomi-range: rgba(129, 161, 255, 0.18);
  --koyomi-range-preview: rgba(129, 161, 255, 0.1);
}
```

The defaults of `--koyomi-range` and `--koyomi-range-preview` are fixed
colours, not mixed from the accent: set them again when you change the
accent.

## The Sumi theme

`koyomi-sumi.css` sets the properties on `:root` and on every element
with a `data-theme` attribute. For each colour it reads, in this order:

1. the Sumi tokens of the page: `--font-body`, `--color-sumi-blade`,
   `--color-sumi-ember`, `--color-sumi-ink`, `--sumi-text-muted`, and
   the colours of the Sumi daisyUI themes (`--color-base-100`,
   `--color-base-200`, `--color-base-300`, `--color-base-content`,
   `--color-primary-content`, `--color-success`, `--color-warning`,
   `--color-error`, `--radius-box`);
2. the short names `--sumi-font`, `--sumi-ink`, `--sumi-paper`,
   `--sumi-surface`, `--sumi-line`, `--sumi-muted`, `--sumi-accent`,
   `--sumi-accent-ink` and `--sumi-radius`, for a page that sets them
   itself;
3. a built-in Sumi palette (`--koyomi-sumi-*`), so that the pickers look
   like Sumi on a page with no Sumi tokens.

The main mappings:

| Property | Reads |
|---|---|
| `--koyomi-font` | `--font-body`, `--sumi-font`, then Outfit |
| `--koyomi-text`, `--koyomi-floating-text`, `--koyomi-today` | `--color-base-content`, `--sumi-ink` |
| `--koyomi-background`, `--koyomi-floating-background` | `--color-base-100`, `--sumi-paper` |
| `--koyomi-surface` | `--color-base-200`, `--sumi-surface` |
| `--koyomi-border`, `--koyomi-floating-border` | `--color-base-300`, `--sumi-line` |
| `--koyomi-muted`, `--koyomi-weekend`, `--koyomi-tone-muted` | `--sumi-text-muted`, `--sumi-muted` |
| `--koyomi-accent`, `--koyomi-tone-accent`, the focus ring | `--color-sumi-blade`, `--sumi-accent`, then `#e84a1c` |
| `--koyomi-accent-text` | `--color-primary-content`, `--sumi-accent-ink` |
| `--koyomi-range`, `--koyomi-range-preview` | the blade at 14% and 8% |
| `--koyomi-holiday` | `--color-sumi-ember` mixed with the text colour |
| `--koyomi-invalid`, `--koyomi-tone-danger` | `--color-error` |
| `--koyomi-tone-success` | `--color-success` |
| `--koyomi-tone-warning` | `--color-warning` |
| `--koyomi-shadow`, `--koyomi-floating-shadow`, `--koyomi-backdrop` | `--color-sumi-ink` |
| `--koyomi-radius`, `--koyomi-floating-radius` | `--radius-box`, `--sumi-radius`, then `0.25rem` |

Today is marked in ink, not in the blade: a Sumi page keeps the blade
for what needs attention, here the selection.

Sizes and spaces have no Sumi token, so the theme gives them the Sumi
values: `--koyomi-small` is `0.8125em` and `--koyomi-icon-size` is
`16px`. The field height, the day size, the field padding and the
transition keep the values of `koyomi.css`.

The theme sets the properties on `:root` with the weight of a class. To
change one, set it on `.koyomi` or on an element inside the root, or on
`:root` in a rule that comes after the theme.

### Dark and light

On a page with the Sumi daisyUI themes, the pickers follow them, because
their colours change with `data-theme`. Without them, the built-in
palette is chosen:

1. by the `data-theme` attribute: `"dark"` gives the dark palette, and
   any other value the light one;
2. else, on the root element, by `prefers-color-scheme`: a dark
   preference gives the dark palette, unless the root has
   `data-theme="light"`.

The palette and the mapping are resolved again on every element with a
`data-theme` attribute, so a part of the page with its own theme gets
it:

```heex
<section data-theme="dark">
  <.date_picker field={@form[:due]} />
</section>
```

In an app with daisyUI (a new Phoenix 1.8 app has it), the theme reads
the app's own daisyUI colours (`--color-base-*`), with the Sumi accent.
Koyomi does not load the Outfit font; load it yourself if you want it.

Import `koyomi-sumi.css` from `app.css`, after `koyomi.css`.

## Icons

The pickers draw five icons from [Lucide](https://lucide.dev): the
calendar button (`calendar`), the button of a time picker (`clock`) and
of a recurrence picker (`repeat`), the clear button and a chip's remove
button (`close`), and the previous and next buttons of the calendar
(`chevron`). Each is an element with the class `koyomi-icon` and a
`data-icon` attribute with its name, hidden from assistive technology;
the button around it has the label. The icons are drawn in
`currentColor` with a stroke of 2, at `--koyomi-icon-size`.

To use the icons of your app, call `setIcons` before the pickers mount,
that is before `liveSocket.connect()` or `mountKoyomi()`:

```js
import { Koyomi, setIcons } from "koyomi"

setIcons({
  // The markup of one element, an <svg> as a rule.
  calendar: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">…</svg>`,
  // Or a function that makes a new element: here a Heroicon of Phoenix.
  close: () => Object.assign(document.createElement("span"), { className: "hero-x-mark" })
})
```

The names are `chevron`, `calendar`, `clock`, `repeat` and `close`; a
name left out keeps Koyomi's icon, and `null` brings it back. The
`chevron` points to the right, to the next month: Koyomi mirrors it for
the previous month, and swaps the two in a right-to-left language.

Koyomi adds `koyomi-icon`, `data-icon`, `aria-hidden="true"` and a
`data-custom` attribute to the element, and keeps its own classes. The
size of `--koyomi-icon-size` applies to it, but not the fill and stroke
of Koyomi's icons, so a filled icon stays filled.

Without JavaScript, an icon can be replaced in CSS by its `data-icon`,
for instance with a mask:

```css
.koyomi-icon[data-icon="calendar"] {
  stroke: none;
  background-color: currentColor;
  mask: url("/images/calendar.svg") center / contain no-repeat;
}
.koyomi-icon[data-icon="calendar"] > * { display: none; }
```

## Classes

Every part of a picker has a `koyomi-*` class, for styles of your own.
Most rules of `koyomi.css` have the weight of one or two classes, so a
rule of your app with the same selector, loaded after it, replaces it.

The picker's element:

| Class | On |
|---|---|
| `koyomi` | every picker |
| `koyomi-date`, `koyomi-range`, `koyomi-dates`, `koyomi-month`, `koyomi-year`, `koyomi-week`, `koyomi-time`, `koyomi-datetime`, `koyomi-recurrence`, `koyomi-calendar` | the kind of picker |
| `koyomi-inline` | a picker shown on the page, with no popover (`calendar/1`, or `inline`) |
| `koyomi-ready` | once the hook has built the picker; the browser's own inputs are hidden |
| `koyomi-open` | while the popover is open |
| `koyomi-has-value` | while the picker has a value |
| `koyomi-is-disabled`, `koyomi-is-readonly` | a disabled or read-only picker |

The `class` attribute of a component adds classes to this element.

The parts:

| Class | Part |
|---|---|
| `koyomi-native` | the browser's own inputs, before the hook mounts |
| `koyomi-control` | the field; with `koyomi-invalid` when it is invalid |
| `koyomi-segments`, `koyomi-segment`, `koyomi-literal` | the segments, and the separators between them; an empty segment has `koyomi-placeholder` |
| `koyomi-range-dash`, `koyomi-zone` | the dash of a range, the time zone of a date and time |
| `koyomi-trigger`, `koyomi-clear` | the calendar button, the clear button |
| `koyomi-chips`, `koyomi-chip`, `koyomi-chip-remove` | the days of the several days picker |
| `koyomi-summary` | the rule of a recurrence picker, in words |
| `koyomi-message` | the message under the field (a value that the rules refuse) |
| `koyomi-popover`, `koyomi-sheet`, `koyomi-backdrop` | the popover, as a sheet, and the backdrop behind a sheet |
| `koyomi-panel`, `koyomi-panel-body`, `koyomi-footer` | the content of the popover, and its buttons (`koyomi-action`, `koyomi-done`) |
| `koyomi-typing`, `koyomi-type`, `koyomi-type-preview` | the typing box and its preview; `koyomi-no-match` when the text reads as no date |
| `koyomi-presets`, `koyomi-preset` | the presets |
| `koyomi-notice` | a notice in the popover, such as a time that happens twice |
| `koyomi-calendar`, `koyomi-header`, `koyomi-nav`, `koyomi-caption` | the calendar, its header, the previous and next buttons, a month's name |
| `koyomi-months`, `koyomi-month`, `koyomi-grid` | the months shown, one month, its table |
| `koyomi-day`, `koyomi-day-number`, `koyomi-day-label`, `koyomi-day-marks`, `koyomi-mark` | a day's button and its content |
| `koyomi-week-number` | a week number |
| `koyomi-month-grid`, `koyomi-year-grid`, `koyomi-cells-row`, `koyomi-cell` | the months of a year and the years of a page |
| `koyomi-times`, `koyomi-time`, `koyomi-times-empty` | the time list, a time, the text of a day with no times |
| `koyomi-recurrence`, `koyomi-weekdays`, `koyomi-weekday`, `koyomi-occurrences` | the recurrence editor, its weekday buttons, the next dates |

The calendar has `data-view` (`days`, `months` or `years`), and the
popover `data-side` (`top` or `bottom`).

### The states of a day

The states are classes of the day's cell (the `td`), and the day's
button is `.koyomi-day` inside it:

| Class | The day |
|---|---|
| `koyomi-today` | is today |
| `koyomi-selected` | is selected |
| `koyomi-range-start`, `koyomi-range-end` | is the first or the last day of a range (a range of one day has both) |
| `koyomi-range-middle` | is between the ends of a range |
| `koyomi-range-preview` | is in the range drawn while the pointer moves |
| `koyomi-unavailable` | may not be chosen |
| `koyomi-holiday` | is a holiday |
| `koyomi-weekend` | is a day of the weekend of the locale |
| `koyomi-outside` | belongs to the month before or after |
| `koyomi-blank` | is an empty cell (a day of another month, not shown) |

The button also has `aria-disabled="true"` when the day may not be
chosen, `aria-current="date"` on today, and `data-tone` with its content's
tone. In a week picker, a row has `koyomi-week-row`, and
`koyomi-week-selected` or `koyomi-week-hover`. A month or a year cell is
selected with `koyomi-selected` on its cell, and its button has
`aria-current="date"` and `aria-disabled="true"`. A time has
`aria-selected="true"` when it is chosen, `aria-disabled="true"` when it
may not be, and `data-active` when the arrow keys are on it.

For example, a day with a booked tone in green, and holidays in bold:

```css
.koyomi-holiday .koyomi-day-number {
  font-weight: 600;
  text-decoration: none;
}

.koyomi-day[data-tone="success"] {
  background: color-mix(in oklab, var(--koyomi-tone-success) 10%, transparent);
}
```

## Forced colours

In forced colours mode (Windows High Contrast), `koyomi.css` draws the
states with the system colours:

* a selected day, the ends of a range, a selected month or year, a
  selected time and a pressed weekday are drawn in `Highlight` and
  `HighlightText`;
* the days between the ends of a range, and a range drawn while the
  pointer moves, have a `Highlight` line above and below, with no fill;
* a day that may not be chosen is in `GrayText`, and keeps its line
  through;
* a focused day or segment has a 2px `Highlight` outline.

Other colours, the tones and the marks among them, are the system's in
that mode.

## Motion

When the person asks for reduced motion (`prefers-reduced-motion:
reduce`), the popover and the sheet appear with no animation, and the
transitions of the pickers and the popover are off.
