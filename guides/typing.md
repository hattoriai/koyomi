# Typing dates

A person can type a date in two ways: digit by digit in the segments of
the field, or in plain words ("next friday", "15 mar", "tomorrow 9am") in
the box at the top of the popover.

## Segments

The field of a picker has one segment for each part of the value: day,
month and year in the order of the locale (`15/03/2027` in `en-GB`,
`03/15/2027` in `en-US`, `2027/03/15` in `ja`), hour and minute (and
second, and AM/PM in a 12-hour clock). Each segment is a spinbutton that
takes the focus on its own. An empty segment shows a placeholder in the
locale's language (`dd/mm/yyyy`, `jj/mm/aaaa`, `TT.MM.JJJJ`).

### Digits

Type the digits of a segment. The focus moves on to the next segment as
soon as no other digit fits: `4` in a month moves on (no month is 40 or
more), `1` waits for a second digit, which can make 10, 11 or 12. A
segment that is full starts again with the next digit. A `0` typed first
waits for the next digit.

The year takes four digits. A year of one or two digits becomes a full
year when the year segment loses the focus: the year within fifty years
of the current one, so `27` is 2027 and `80` is 1980 (in 2027). Until
then the date is not whole, and the picker does not post it.

A separator (`/`, `.`, `-`, `:`, `,` or a space) typed after some digits
moves to the next segment, so `15/3/2027` can be typed as it reads.

Digits of any script count: Arabic-Indic, Persian, Devanagari and
full-width digits are read as 0 to 9.

In the Gregorian calendar, the day cannot pass the length of its month:
a day of 31 becomes 30 when the month changes to April, and 28 or 29 in
February.

### Keys

| Key | In a segment |
|---|---|
| Up, Down | the next or the previous value; an empty segment starts at today's part (or 9 for the hour, 0 for the minutes). Values wrap, except the year |
| Page Up, Page Down | a bigger step: 10 years, 10 minutes or seconds, 7 days, 6 hours, 3 months |
| Home, End | the smallest and the largest value |
| Left, Right | the previous or the next segment, and across to the other field: from the first day of a range to the last, from the date to the time. In a right-to-left locale, the other way |
| Backspace, Delete | clears the last digit, then the segment; in an empty segment, Backspace goes to the previous segment |
| Enter | opens or closes the popover |
| A letter | in a date field, opens the popover with the letter in the typing box (see below) |
| `a` or `p` | in the AM/PM segment, AM or PM; also the first letters of the locale's own words |

The segments are `contenteditable` with `inputmode="numeric"`, so a phone
shows its number keyboard. The picker writes every change itself.

### Paste

Text pasted into a segment is read as a whole, as in the typing box: an
ISO date (`2027-03-15`), a date in the locale's numeric order
(`15/03/2027`), or plain words. A text that is not a date changes nothing.

### When the date is posted

In the date, month and date and time pickers, the value is posted when
every segment has a value, or when every segment is cleared. In a
calendar other than the Gregorian (see
[Locales and calendars](calendars.md)), a day past the length of its
month is not a date: the picker posts the field as empty. The year picker
posts the year at each digit.

## Plain words

The popover of the date, range, several days, month, week, year and date
and time pickers starts with a box: "Type a date, like next Friday". As
the person types, a line under the box says what it reads ("Friday,
26 March 2027", or "Friday 26 March – Sunday 28 March 2027, 3 days"), or
"Not a date I can read",
and the calendar shows that month. Enter takes it; Down moves the focus to
the calendar. The line is a polite live region.

`typing={false}` leaves the box out. The time picker, the recurrence
picker and the calendar have no box, nor has a picker that is read-only or
disabled.

A date typed in words is taken even when the rules refuse it: the picker
posts it and shows why it is refused, and the changeset refuses it. See
the [Rules](rules.md) guide.

### What it reads

The examples below were read on Wednesday 17 March 2027, with weeks from
Monday.

| Text | Date picker | Range picker |
|---|---|---|
| `today`, `tomorrow`, `yesterday` | 17, 18, 16 March | one day, as the start of the range |
| `day after tomorrow` | 19 March | |
| `in 3 weeks`, `2 days ago`, `+3 days` | 7 April, 15 March, 20 March | |
| `friday`, `this friday` | 19 March | |
| `next friday` | 26 March | |
| `last friday` | 12 March | |
| `the 20th`, `20th` | 20 March | |
| `15 mar`, `march 15`, `15/03` | 15 March 2028 | |
| `15/03/27`, `2027-03-15` | 15 March 2027 | |
| `march` | 1 March 2027 | 1 to 31 March 2027 |
| `next week` | 22 March | 22 to 28 March |
| `next month`, `start of next month` | 1 April | |
| `end of month`, `eom` | 31 March | |
| `Q2` | 1 April | 1 April to 30 June |
| `2027` | 1 January 2027 | the year 2027 |
| `week 12`, `2027-W12` | 22 March | 22 to 28 March |
| `this weekend`, `weekend` | 20 March | 20 and 21 March |
| `next 7 days` | | 17 to 23 March |
| `last 30 days` | | 16 February to 17 March |
| `15-20 mar`, `mar 15–20` | | 15 to 20 March 2028 |
| `dec 20 - jan 5` | | 20 December 2027 to 5 January 2028 |
| `mon to fri` | | 22 to 26 March |
| `from 3 april to 10 april`, `between 3 apr and 10 apr` | | 3 to 10 April |

A date and time picker also reads a time, with the date or alone:

| Text | Date and time picker |
|---|---|
| `tomorrow 9am`, `9am tomorrow`, `tomorrow at 9` | 18 March, 09:00 |
| `fri at 14:30` | 19 March, 14:30 |
| `noon`, `midnight` | today at 12:00, or 00:00 |
| `21:30`, `21.30`, `21h30`, `9.30pm` | today at 21:30 |
| `in 2 hours`, `now` | from the time now in the picker's zone, across midnight |

A bare hour (`9`) is a time only after a word such as "at". A date alone
keeps the picker's time. In the other pickers, a time typed with a date is
dropped.

### How a text is resolved

* A date without a year (`15 mar`), a month, a quarter, a day of the
  month or a weekday is the first one that ends on or after today. Today
  and the current month count: on 17 March, `march` is this March, and
  `15 mar` is next year's.
* `this friday`, `next friday` and `last friday` are the Friday of this
  week, of next week and of last week. The week starts on the picker's
  first day of the week (the locale's, or `first_day`). So on a Wednesday,
  `next friday` is nine days on, not two; `friday` alone is the coming
  one. `this/next/last week`, `month`, `quarter` and `year` work the same
  way, and `this/next/last march` is March of this, next or last year.
* `weekend` and `this weekend` are the coming Saturday and Sunday, or the
  current ones on a Saturday or a Sunday.
* `next 7 days` is today and the six after; `last 30 days` is today and
  the 29 before.
* A number has its meaning from the locale's numeric order: `3/4` is
  3 April in `en-GB` and 4 March in `en-US`. A first number of four digits
  makes it year, month, day.
* In a range, the end is read from the start: `dec 20 - jan 5` ends in
  the next year, and `mon to fri` ends on the Friday after that Monday.
  When one side gives the other its month (`15-20 mar`), both are in the
  same month and year, so `15-2 mar` is not a range. A range that ends
  before it starts is not read.
* A text that is both a date and a range is a date: in `en-US`, `3-4` is
  4 March, not the 3rd to the 4th.
* A word that is both a month and a weekday (`mar` in Spanish and
  French) is the month when a day is given, else the weekday.
* A weekday given with a date must match it: `Friday 19 March` is read,
  `Thursday 19 March` is not.

### Languages

The words of English, Portuguese, Spanish, French, German, Italian, Dutch
and Japanese are built in. The picker tries the words of its locale's
language first, then English, which every picker reads. Month and weekday
names, full and short, come from the browser (`Intl`) for the locale and
for English, so `15 mars` reads in Swedish too, but `imorgon` does not.

Letters are compared without case and accents (`marco` is `março`), and
ordinal endings are dropped (`15th`, `1er`, `3.`).

| Language | Examples |
|---|---|
| Portuguese | `amanhã`, `próxima sexta`, `sexta-feira que vem`, `daqui a 3 semanas`, `15 de março`, `fim do mês`, `de 3 a 10 de abril`, `amanhã às 9h` |
| Spanish | `pasado mañana`, `el próximo viernes`, `dentro de 2 semanas`, `del 3 al 10 de abril`, `mañana a las 9` |
| French | `vendredi prochain`, `dans 3 jours`, `15 mars`, `fin du mois`, `du 3 au 10 avril`, `demain à 14h30` |
| German | `nächsten Freitag`, `übermorgen`, `in 2 Wochen`, `15. März`, `15.03.2027`, `Monatsende`, `KW 12`, `vom 3. bis 10. April`, `morgen um 9 Uhr` |
| Italian | `venerdì prossimo`, `tra 3 giorni`, `dal 3 al 10 aprile`, `domani alle 9` |
| Dutch | `volgende vrijdag`, `over 3 dagen`, `van 3 t/m 10 april`, `morgen om 9` |
| Japanese | `明日`, `来週の金曜日`, `3日後`, `2027年3月15日`, `来月`, `3月3日から3月10日まで`, `明日 午後3時`, `明日の15時30分` |

Full-width digits (`２０２７年３月１５日`) are read. Other digits, such as
Arabic-Indic, are read in the segments but not in the typing box: see
[Known limits](limits.md).
