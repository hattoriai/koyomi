# Accessibility

A person can pick every value of a picker with the keyboard, and each
part of a picker gives its role, name and state to assistive technology.

## The name of a picker

Give the picker a visible label, and its id as `label_id`:

```heex
<label id="due-label">Due</label>
<.date_picker field={@form[:due]} label_id="due-label" />
```

The field then has `aria-labelledby="due-label"`. Without `label_id`, it
has an `aria-label`: the `label` attribute, or the field name in words
("Due"). A `<label for>` does not name a picker, because the inputs that
it would point to are hidden once the hook mounts: use `label_id`.

`aria-describedby` and `aria-invalid` given to the picker go to its
segments (see the [Forms](forms.md) guide). When the browser refuses a
value by the rules, the message under the field is in a polite live
region, and the segments name it in `aria-describedby`.

## The field

The names below are the English words; each locale has its own, and the
`messages` attribute replaces them (see `Koyomi.Messages`).


The field (`.koyomi-control`) has `role="group"` and the picker's name.
Inside it:

* Each part of a date or a time is a segment with `role="spinbutton"`:
  day, month and year in the order of the locale, the week and the year
  of a week picker, and hour, minute, second and AM/PM of a time. Its
  `aria-label` is the name of the part in the locale's language ("day",
  "month"), with "Start date, " or "End date, " before it in a range.
  It has `aria-valuemin`, `aria-valuemax`, `aria-valuenow` and
  `aria-valuetext` (the AM/PM segment reads "AM" or "PM"); an empty
  segment has no `aria-valuenow` and an empty `aria-valuetext`.
* The segments of each date or time are a `group` with the picker's
  name.
* The separators of the date are `aria-hidden`.
* The calendar button has `aria-haspopup="dialog"`, `aria-expanded`
  (`true` while the popover is open) and the name "Show calendar", or
  "Show times" for a time picker.
* The clear button, with `clearable`, is named "Clear".
* In the several days picker, each day is a chip with a remove button
  named "Remove" and the day ("Remove 15 Mar 2027").

A disabled picker has `aria-disabled="true"` on its segments, which
leave the tab order; a read-only one has `aria-readonly="true"`.

The browser's own inputs that the form posts are hidden and
`aria-hidden` once the hook mounts.

## The popover

The popover has `role="dialog"` and the picker's label as its name. When
it opens, the focus goes to the day with the tab stop (the chosen day,
else today or the first day that the rules allow), the time list of a
time picker, or the first control of the recurrence editor.

* Tab and Shift+Tab move between the controls of the popover and stay in
  it: from the last control, Tab goes back to the first.
* Escape closes it. The focus goes back to the field: to its first
  segment, or to its first button when it has no segments.
* Done, a picked value and `Koyomi.Live.close/2` close it, and the focus
  goes back to the field when it was in the popover.
* A press outside the popover and the field closes it, and leaves the
  focus where the press put it.

On a screen narrower than `40rem` the popover is a sheet at the bottom
of the screen, with a backdrop. It behaves the same way.

## The calendar

Each month is a table with `role="grid"`, labelled by its caption ("March
2027"). The column headers are the weekdays: each shows a short name and
has the full name for screen readers. With `week_numbers`, each row
starts with a row header named "Week 11".

Each day is a button in a `gridcell`:

* The cell has `aria-selected`, `true` for the chosen days.
* The button's name is the full date, then the holiday, the day's
  content (its `title`, else its label) and "Unavailable" when it may not
  be chosen: "Monday, 15 March 2027, Full, Unavailable".
* Today has `aria-current="date"`.
* A day that may not be chosen has `aria-disabled="true"`: it keeps its
  place in the arrow key order, and Enter does nothing on it.

The calendar is one tab stop: one day has `tabindex="0"` and the others
`-1`. With several months, only one month has the tab stop.

| Key | Action |
|---|---|
| Left, Right | the day before or after (reversed in a right-to-left locale) |
| Up, Down | the same weekday a week before or after |
| Home, End | the first or the last day of the week |
| Page Up, Page Down | the same day a month before or after |
| Shift+Page Up, Shift+Page Down | the same day a year before or after |
| Enter, Space | pick the day |

Moving past the months shown shows the next or the previous month. In a
range picker, the range is drawn to the day with the focus while the
second end is chosen, as it is drawn under the pointer.

The previous and next buttons are named "Previous month" and "Next
month". In a day calendar, the caption of a month is a button named
"March 2027, Choose a month", which shows the months of the year.

### Months and years

The months of a year and the years of a page are each a grid
(`role="grid"`, with `row` and `gridcell` elements), labelled by the year
or the span of years. A month or a year is a button in a gridcell with
`aria-selected`, `aria-current="date"` for this month or year, and
`aria-disabled="true"` when it is wholly before `:min` or after `:max`.
The previous and next buttons are named "Previous year" and "Next year",
or "Earlier years" and "Later years". The grid is one tab stop.

| Key | Action |
|---|---|
| Left, Right | the month or year before or after (reversed in a right-to-left locale) |
| Up, Down | three before or after: the cell above or below |
| Home, End | the first or the last cell |
| Page Up, Page Down | the year before or after, or the page of years |
| Enter, Space | pick it: in a day calendar, show its days, or its months |

A month picker starts on the months, and a year picker on the years.

## The time list

The times of a time picker, or of a date and time picker, are a listbox
(`role="listbox"`, named "Show times", or "Times on 15 March 2027" when
it shows a day's slots). The list itself has the focus, and
`aria-activedescendant` names the active time; each time is an `option`
with `aria-selected`, and `aria-disabled="true"` when it may not be
chosen.

| Key | Action |
|---|---|
| Up, Down | the time before or after |
| Page Up, Page Down | four times before or after |
| Home, End | the first or the last time |
| Enter, Space | pick the time |

## The segments

| Key | Action |
|---|---|
| a digit | type the part; the focus moves on when the part is full |
| Up, Down | add or take one; an empty part starts from today's (9 for the hour, 0 for the minutes) |
| Page Up, Page Down | a bigger step: 7 days, 3 months or weeks, 10 years, 6 hours, 10 minutes or seconds |
| Home, End | the smallest or the largest value of the part |
| Left, Right | the part before or after (reversed in a right-to-left locale), on into the other date of a range or the time of a date and time |
| Backspace, Delete | remove the last digit typed, or empty the part; in an empty part, go back to the part before |
| `/`, `.`, `-`, `:`, `,` or a space | move to the next part |
| a letter | open the typing box with the letter (a date); `a` or `p` sets AM or PM in the AM/PM part |
| Enter | open or close the popover |
| Tab | the next control of the page |

Days, months, hours and minutes wrap around; the year does not. A key
with Ctrl, Cmd or Alt is left to the browser. A paste in a segment reads
the text as the typing box does. The [Typing dates](typing.md) guide has
the details.

## The typing box

The typing box in the popover is a text input named "Type a date", with
a preview of what it reads in a polite live region, named by its
`aria-describedby`. Enter takes the value, and Down moves the focus to
the calendar.

## Live regions

The calendar has a polite live region, visually hidden, that says the
months shown when they change. The picker has another, outside the
popover, so that it is read after the popover closes, that says:

* the day picked ("Monday, 15 March 2027");
* in a range, the first day and how to end the range, then the whole
  range and its length;
* in the several days picker, how many days are chosen;
* in a time picker or a date and time picker, the time picked.

The message under the field (a value that the rules refuse) and the
preview of the typing box are polite live regions too.

## The recurrence editor

The editor is made of labelled native controls: a select for how often,
a number for every how many, radio buttons for the day of the month and
for the end, and a date input. The weekdays of a weekly rule are buttons
with `aria-pressed`. The rule in words and the next dates follow.

## Touch targets

On a touch screen (`pointer: coarse`), a day and the field are 44px high
(`--koyomi-day-size` and `--koyomi-field-height` are `2.75rem`), and so
are the calendar, clear, previous and next buttons, the presets, the
times, the weekdays of the recurrence editor and the chips' remove
buttons. Months and years are at least 44px high everywhere.

## Forced colours and motion

In forced colours mode, the selected days, the ends of a range, a
selected time, month, year or weekday are drawn in the system's
`Highlight` colours, the middle of a range has `Highlight` lines, a day
that may not be chosen is in `GrayText`, and a focused day or segment has
a `Highlight` outline. With `prefers-reduced-motion: reduce`, the popover
has no animation and the transitions are off. See the
[Theming](theming.md) guide.
