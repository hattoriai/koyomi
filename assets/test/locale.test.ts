import { test } from "node:test";
import assert from "node:assert/strict";

import * as iso from "../src/iso";
import * as L from "../src/locale";

const ymd = iso.fromYMD;

test("weekInfo: first day, weekend, minimal days", () => {
  assert.equal(L.weekInfo("en-US").firstDay, 7);
  assert.equal(L.weekInfo("en-GB").firstDay, 1);
  assert.equal(L.weekInfo("en-GB").minimalDays, 4);
  assert.equal(L.weekInfo("pt-BR").firstDay, 7);
  // CLDR (since v42) gives Portugal Sunday; Intl is followed here.
  assert.equal(L.weekInfo("pt-PT").firstDay, (new Intl.Locale("pt-PT") as Intl.Locale & { weekInfo?: L.WeekInfo }).weekInfo?.firstDay ?? 7);
  assert.equal(L.weekInfo("ar-EG").firstDay, 6);
  assert.deepEqual(L.weekInfo("ar-EG").weekend, [5, 6]);
  assert.equal(L.weekInfo("fr-FR").firstDay, 1);
  assert.equal(L.weekInfo("en-US-u-fw-mon").firstDay, 1);
  assert.equal(L.weekInfo("fr-FR-u-fw-sun").firstDay, 7);
  assert.equal(L.weekInfo("en-GB-u-ca-gregory-fw-wed").firstDay, 3);
  assert.equal(L.weekInfo("de").firstDay, 1);
});

test("weekdayNames in display order", () => {
  assert.deepEqual(L.weekdayNames("en-US", "short", 7), ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]);
  assert.deepEqual(L.weekdayNames("en-GB", "long", 1)[0], "Monday");
  assert.equal(L.weekdayNames("en-US", "narrow", 6)[0], "S");
  assert.equal(L.weekdayNames("fr-FR", "long")[0], "lundi");
  assert.equal(L.weekdayNames("en-US", "short").length, 7);
});

test("hourCycle", () => {
  assert.equal(L.hourCycle("en-US"), "h12");
  assert.equal(L.hourCycle("en-GB"), "h23");
  assert.equal(L.hourCycle("ja"), "h23");
  assert.equal(L.hourCycle("en-US-u-hc-h23"), "h23");
  assert.equal(L.hourCycle("en-GB-u-hc-h12"), "h12");
});

// ICU writes narrow and thin no-break spaces; compare them as spaces.
const spaces = (text: string) => text.replace(/[\u00a0\u2009\u202f]/g, " ");
const order = (parts: L.FieldPart<string>[]) => spaces(parts.map((p) => ("field" in p ? p.field : p.literal)).join("|"));

test("dateFieldOrder", () => {
  assert.equal(order(L.dateFieldOrder("en-US")), "month|/|day|/|year");
  assert.equal(order(L.dateFieldOrder("en-GB")), "day|/|month|/|year");
  assert.equal(order(L.dateFieldOrder("de")), "day|.|month|.|year");
  assert.equal(order(L.dateFieldOrder("ja")), "year|/|month|/|day");
  assert.equal(order(L.dateFieldOrder("ko")), "year|. |month|. |day|.");
  // Persian locales default to another calendar; the order is still the Gregorian input's.
  assert.equal(L.dateFieldOrder("fa").filter((p) => "field" in p).length, 3);
});

test("timeFieldOrder", () => {
  assert.equal(order(L.timeFieldOrder("en-US")), "hour|:|minute| |dayPeriod");
  assert.equal(order(L.timeFieldOrder("en-US", { seconds: true, hourCycle: "h23" })), "hour|:|minute|:|second");
  assert.equal(order(L.timeFieldOrder("en-GB")), "hour|:|minute");
  assert.match(order(L.timeFieldOrder("ko")), /^dayPeriod\| \|hour/);
});

test("fieldPlaceholders, fieldNames, dayPeriods", () => {
  assert.deepEqual(
    [L.fieldPlaceholders("en").day, L.fieldPlaceholders("en").month, L.fieldPlaceholders("en").year],
    ["dd", "mm", "yyyy"],
  );
  assert.equal(L.fieldPlaceholders("pt-PT").year, "aaaa");
  assert.equal(L.fieldPlaceholders("fr").day, "jj");
  assert.equal(L.fieldPlaceholders("de-AT").year, "JJJJ");
  assert.equal(L.fieldPlaceholders("it").day, "gg");
  assert.equal(L.fieldPlaceholders("nl").year, "jjjj");
  assert.equal(L.fieldPlaceholders("ja").year, "年");
  assert.equal(L.fieldPlaceholders("sw").day, "––");
  assert.equal(L.fieldPlaceholders("en-US").dayPeriod, "AM");
  assert.equal(L.fieldNames("pt").day, "dia");
  assert.equal(L.fieldNames("en").month, "month");
  assert.equal(L.fieldNames("ja").year, "年");
  assert.deepEqual(L.dayPeriods("en-US"), { am: "AM", pm: "PM" });
  assert.deepEqual(L.dayPeriods("ja"), { am: "午前", pm: "午後" });
});

test("numbers and digits", () => {
  assert.equal(L.formatNumber(15, "ar-EG"), "١٥");
  assert.equal(L.formatNumber(5, "ar-EG", 2), "٠٥");
  assert.equal(L.formatNumber(2027, "en-US"), "2027");
  assert.equal(L.formatNumber(7, "en-u-nu-deva", 2), "०७");
  assert.equal(L.formatNumber(15, "fa"), "۱۵");
  assert.equal(L.parseDigits("٢٠٢٧-٠٣-١٥"), "2027-03-15");
  assert.equal(L.parseDigits("۱۴۰۶/۰۱/۰۱"), "1406/01/01");
  assert.equal(L.parseDigits("２０２７年３月"), "2027年3月");
  assert.equal(L.parseDigits("१२:३०"), "12:30");
  assert.equal(L.parseDigits("𝟐𝟎𝟗"), "209");
  assert.equal(L.parseDigits("abc 123"), "abc 123");
});

test("rtl", () => {
  for (const locale of ["ar", "ar-EG", "he", "fa", "ur", "ps", "yi", "dv", "ckb"]) assert.equal(L.rtl(locale), true, locale);
  for (const locale of ["en", "ja", "pt-PT", "ru", "hi"]) assert.equal(L.rtl(locale), false, locale);
});

test("relativeLabel", () => {
  assert.equal(L.relativeLabel("en", 0, "day"), "today");
  assert.equal(L.relativeLabel("en", 1, "day"), "tomorrow");
  assert.equal(L.relativeLabel("en", 30, "day"), "in 30 days");
  assert.equal(L.relativeLabel("en", 1, "week"), "next week");
  assert.equal(L.relativeLabel("pt", -1, "day"), "ontem");
});

test("calendarSystem picks the calendar", () => {
  assert.equal(L.calendarSystem("en").id, "gregory");
  assert.equal(L.calendarSystem("fa").id, "gregory");
  assert.equal(L.calendarSystem("fa-u-ca-persian").id, "persian");
  assert.equal(L.calendarSystem("ja-JP-u-ca-japanese").id, "japanese");
  assert.equal(L.calendarSystem("en", "hebrew").id, "hebrew");
  assert.equal(L.calendarSystem("en", "nonsense").id, "gregory");
  assert.equal(L.calendarSystem("en", "buddhist").isGregorianLike, true);
  assert.equal(L.calendarSystem("en", "hebrew").isGregorianLike, false);
});

test("gregorian months and labels", () => {
  const cal = L.calendarSystem("en-US");
  const march = cal.monthOf(ymd(2027, 3, 15));
  assert.equal(march.start, ymd(2027, 3, 1));
  assert.equal(march.length, 31);
  assert.equal(march.label, "March 2027");
  assert.equal(march.monthLabel, "March");
  assert.equal(march.yearLabel, "2027");
  assert.equal(cal.monthOf(ymd(2028, 2, 3)).length, 29);
  assert.equal(cal.addMonths(ymd(2027, 1, 31), 1), ymd(2027, 2, 28));
  assert.equal(cal.dayNumber(ymd(2027, 3, 15)), "15");
  assert.equal(L.calendarSystem("ar-EG").dayNumber(ymd(2027, 3, 15)), "١٥");
  assert.equal(cal.format(ymd(2027, 3, 15), "long"), "March 15, 2027");
  assert.equal(cal.format(ymd(2027, 3, 15), "short"), "3/15/27");
  assert.equal(spaces(cal.formatRange(ymd(2027, 3, 15), ymd(2027, 3, 20), "medium")), "Mar 15 – 20, 2027");
  assert.deepEqual(cal.weekNumber(ymd(2027, 1, 1)), { year: 2026, week: 53 });
  const year = cal.yearOf(ymd(2027, 6, 1));
  assert.equal(year.months.length, 12);
  assert.equal(year.end - year.start + 1, 365);
});

test("buddhist, roc and japanese years", () => {
  const buddhist = L.calendarSystem("en", "buddhist");
  assert.equal(buddhist.fields(ymd(2027, 3, 15)).year, 2570);
  assert.equal(buddhist.fromFields({ year: 2570, month: 3, day: 15 }), ymd(2027, 3, 15));
  assert.match(buddhist.monthOf(ymd(2027, 3, 15)).label, /2570/);

  const roc = L.calendarSystem("zh-TW", "roc");
  assert.deepEqual(roc.fields(ymd(2027, 3, 15)), { era: "roc", year: 116, month: 3, monthCode: "M03", day: 15 });
  assert.equal(roc.fromFields({ era: "roc", year: 116, month: 3, day: 15 }), ymd(2027, 3, 15));
  assert.equal(roc.fromFields({ era: "broc", year: 12, month: 1, day: 1 }), ymd(1900, 1, 1));
  assert.match(roc.monthOf(ymd(2027, 3, 15)).label, /116/);

  const japanese = L.calendarSystem("ja-JP-u-ca-japanese");
  assert.deepEqual(japanese.fields(ymd(2019, 5, 1)), { era: "reiwa", year: 1, month: 5, monthCode: "M05", day: 1 });
  assert.deepEqual(japanese.fields(ymd(2019, 4, 30)), { era: "heisei", year: 31, month: 4, monthCode: "M04", day: 30 });
  assert.equal(japanese.fields(ymd(1989, 1, 7)).era, "showa");
  assert.equal(japanese.fields(ymd(1989, 1, 8)).era, "heisei");
  assert.equal(japanese.fromFields({ era: "reiwa", year: 1, month: 5, day: 1 }), ymd(2019, 5, 1));
  assert.equal(japanese.fromFields({ era: "reiwa", year: 1, month: 4, day: 30 }), null);
  assert.equal(japanese.fromFields({ era: "heisei", year: 31, month: 4, day: 30 }), ymd(2019, 4, 30));
  assert.equal(japanese.fromFields({ era: "meiji", year: 6, month: 1, day: 1 }), ymd(1873, 1, 1));
  assert.equal(japanese.monthOf(ymd(2027, 3, 15)).label, "令和9年3月");
  assert.equal(japanese.monthOf(ymd(2019, 5, 15)).label, "令和元年5月");
  // The era in the labels agrees with Intl.
  const intl = new Intl.DateTimeFormat("en-u-ca-japanese", { timeZone: "UTC", era: "short", year: "numeric" });
  assert.match(intl.format(new Date(ymd(2019, 4, 30) * 86_400_000)), /31 Heisei/);
});

test("Hebrew 5787 is a leap year with Adar I and Adar II", () => {
  const cal = L.calendarSystem("en", "hebrew");
  const year = cal.yearOf(ymd(2027, 1, 1));
  assert.equal(year.start, ymd(2026, 9, 12)); // Rosh Hashanah 5787
  assert.equal(year.months.length, 13);
  const total = year.months.reduce((sum, m) => sum + m.length, 0);
  assert.equal(total, year.end - year.start + 1);
  assert.equal(total, 385);
  assert.deepEqual(
    year.months.map((m) => m.monthLabel).slice(5, 7),
    ["Adar I", "Adar II"],
  );
  assert.equal(year.months[6]!.label, "Adar II 5787");
  for (const m of year.months) assert.ok(m.length === 29 || m.length === 30);
  const adar2 = cal.fields(ymd(2027, 3, 15));
  assert.deepEqual(adar2, { year: 5787, month: 7, monthCode: "M06", day: 6 });
  assert.equal(cal.fields(year.months[5]!.start).monthCode, "M05L");
  assert.equal(cal.fromFields({ year: 5787, monthCode: "M05L", day: 1 }), year.months[5]!.start);
  assert.equal(cal.fromFields({ year: 5787, monthCode: "M06", day: 6 }), ymd(2027, 3, 15));
  // 5786 is not a leap year: 12 months, no Adar I.
  const common = cal.yearOf(ymd(2026, 3, 1));
  assert.equal(common.months.length, 12);
  assert.equal(cal.fromFields({ year: 5786, monthCode: "M05L", day: 1 }), null);
  assert.equal(cal.fromFields({ year: 5786, month: 13, day: 1 }), null);
  assert.equal(cal.fromFields({ year: 5787, month: 13, day: 1 }), year.months[12]!.start);
});

test("Islamic Umm al-Qura 1448: structure", () => {
  const cal = L.calendarSystem("ar-SA", "islamic-umalqura");
  const ramadan = cal.fromFields({ year: 1448, month: 9, day: 1 });
  assert.notEqual(ramadan, null);
  assert.equal(cal.fields(ramadan!).month, 9);
  assert.equal(cal.fields(ramadan! - 1).month, 8);
  const year = cal.yearOf(ramadan!);
  assert.equal(year.months.length, 12);
  for (let i = 0; i < year.months.length; i++) {
    const m = year.months[i]!;
    assert.ok(m.length === 29 || m.length === 30, `${m.key} has ${m.length} days`);
    if (i > 0) assert.equal(m.start, year.months[i - 1]!.start + year.months[i - 1]!.length);
  }
  assert.ok(year.end - year.start + 1 >= 354 && year.end - year.start + 1 <= 355);
  assert.equal(cal.dayNumber(ramadan! + 14), "١٥");
  assert.equal(cal.fromFields({ year: 1448, month: 9, day: 31 }), null);
  assert.equal(cal.fromFields({ year: 1448, month: 13, day: 1 }), null);
});

test("Persian Nowruz 1406 is 2027-03-21", () => {
  // Intl in Node 22 agrees with the expected date.
  const cal = L.calendarSystem("fa-u-ca-persian");
  assert.equal(cal.fromFields({ year: 1406, month: 1, day: 1 }), ymd(2027, 3, 21));
  assert.deepEqual(cal.fields(ymd(2027, 3, 21)), { year: 1406, month: 1, monthCode: "M01", day: 1 });
  assert.equal(cal.yearOf(ymd(2027, 3, 21)).start, ymd(2027, 3, 21));
  assert.equal(cal.dayNumber(ymd(2027, 3, 21)), "۱");
});

test("Chinese leap month", () => {
  const cal = L.calendarSystem("zh", "chinese");
  const year = cal.yearOf(ymd(2025, 8, 1)); // 2025 has a leap sixth month
  assert.equal(year.months.length, 13);
  const leap = year.months[6]!;
  assert.equal(cal.fields(leap.start).monthCode, "M06L");
  assert.equal(cal.fields(leap.start).month, 7);
  assert.equal(cal.fromFields({ year: 2025, monthCode: "M06L", day: 1 }), leap.start);
  assert.equal(cal.fromFields({ year: 2026, monthCode: "M06L", day: 1 }), null);
  assert.equal(cal.yearOf(ymd(2026, 8, 1)).months.length, 12);
});

test("Ethiopic and Coptic have a thirteenth month of 5 or 6 days", () => {
  for (const id of ["ethiopic", "coptic"] as const) {
    const cal = L.calendarSystem("en", id);
    const year = cal.yearOf(ymd(2027, 3, 1));
    assert.equal(year.months.length, 13);
    assert.ok([5, 6].includes(year.months[12]!.length));
    assert.equal(year.months.slice(0, 12).every((m) => m.length === 30), true);
    assert.equal(cal.fromFields({ year: cal.fields(year.start).year, month: 13, day: 7 }), null);
  }
});

const ALL = L.CALENDAR_IDS;

function random(seed: number) {
  let state = seed;
  return () => {
    state = (state * 1_103_515_245 + 12_345) % 2_147_483_648;
    return state / 2_147_483_648;
  };
}

test("monthOf, nextMonth, prevMonth are contiguous for 24 months in every calendar", () => {
  for (const id of ALL) {
    const cal = L.calendarSystem("en", id, { temporal: false });
    let month = cal.monthOf(ymd(2026, 10, 13));
    assert.ok(month.start <= ymd(2026, 10, 13) && ymd(2026, 10, 13) < month.start + month.length, id);
    for (let i = 0; i < 24; i++) {
      const next = cal.nextMonth(month);
      assert.equal(next.start, month.start + month.length, `${id} ${month.key}`);
      assert.notEqual(next.key, month.key, id);
      assert.equal(cal.prevMonth(next).start, month.start, id);
      assert.ok(month.length >= 5 && month.length <= 31, `${id} ${month.key} ${month.length}`);
      for (const d of [month.start, month.start + month.length - 1]) assert.equal(cal.monthOf(d).start, month.start, id);
      month = next;
    }
  }
});

test("yearOf: months fill the year in every calendar", () => {
  for (const id of ALL) {
    const cal = L.calendarSystem("en", id, { temporal: false });
    for (const day of [ymd(2026, 1, 1), ymd(2027, 7, 4), ymd(1999, 12, 31)]) {
      const year = cal.yearOf(day);
      assert.ok(year.start <= day && day <= year.end, id);
      assert.ok(year.months.length >= 12 && year.months.length <= 13, `${id} ${year.months.length}`);
      assert.equal(year.months[0]!.start, year.start, id);
      const total = year.months.reduce((sum, m) => sum + m.length, 0);
      assert.equal(total, year.end - year.start + 1, id);
      assert.equal(cal.fields(year.start).month, 1, id);
      assert.equal(cal.fields(year.start).day, 1, id);
    }
  }
});

test("fields and fromFields round-trip across all calendars (Intl search)", () => {
  const next = random(42);
  for (const id of ALL) {
    const cal = L.calendarSystem("en", id, { temporal: false });
    assert.equal(cal.usesTemporal, false);
    for (let i = 0; i < 60; i++) {
      const day = ymd(1800, 1, 1) + Math.floor(next() * 120_000); // 1800 to about 2128
      const fields = cal.fields(day);
      assert.equal(cal.fromFields(fields), day, `${id} ${iso.formatISO(day)} ${JSON.stringify(fields)}`);
      assert.equal(cal.fromFields({ ...fields, month: undefined }), day, `${id} by monthCode`);
      assert.equal(cal.addMonths(cal.addMonths(day, 1), -1) <= day, true, id);
    }
  }
});

test("addMonths keeps the day of the month, clamped", () => {
  const hebrew = L.calendarSystem("en", "hebrew");
  const from = hebrew.fromFields({ year: 5787, month: 1, day: 30 })!; // 30 Tishri
  const added = hebrew.addMonths(from, 3); // Tevet has 29 days
  assert.deepEqual(hebrew.fields(added), { year: 5787, month: 4, monthCode: "M04", day: 29 });
  const islamic = L.calendarSystem("en", "islamic-civil");
  const day = islamic.fromFields({ year: 1448, month: 1, day: 10 })!;
  assert.equal(islamic.fields(islamic.addMonths(day, 14)).month, 3);
  assert.equal(islamic.fields(islamic.addMonths(day, -1)).year, 1447);
});

test("fields and fromFields through Temporal when it exists", () => {
  // A stand-in Temporal backed by the Intl search, to check the wiring.
  const make = (day: number, calendar: string): Record<string, unknown> => {
    const base =
      calendar === "iso8601"
        ? { ...iso.toYMD(day), monthCode: "M" + String(iso.toYMD(day).month).padStart(2, "0") }
        : L.calendarSystem("en", calendar, { temporal: false }).fields(day);
    return { ...base, eraYear: calendar === "iso8601" ? undefined : base.year, withCalendar: (c: string) => make(day, c) };
  };
  const stub = {
    PlainDate: {
      from(item: string | Record<string, unknown>) {
        if (typeof item === "string") return make(iso.parseISO(item)!, "iso8601");
        const day = L.calendarSystem("en", item.calendar as string, { temporal: false }).fromFields(item as unknown as L.FieldsInput);
        if (day === null) throw new RangeError("no such date");
        return make(day, item.calendar as string);
      },
    },
  };
  const global = globalThis as { Temporal?: unknown };
  const saved = global.Temporal;
  global.Temporal = stub;
  try {
    const cal = L.calendarSystem("en-GB", "hebrew");
    assert.equal(cal.usesTemporal, true);
    assert.deepEqual(cal.fields(ymd(2027, 3, 15)), { year: 5787, month: 7, monthCode: "M06", day: 6 });
    assert.equal(cal.fromFields({ year: 5787, monthCode: "M06", day: 6 }), ymd(2027, 3, 15));
    assert.equal(cal.fromFields({ year: 5786, monthCode: "M05L", day: 1 }), null);
    assert.equal(L.calendarSystem("en-GB", "gregory").usesTemporal, false);
  } finally {
    if (saved === undefined) delete global.Temporal;
    else global.Temporal = saved;
  }
});

test("laying out 12 months is fast", () => {
  const time = (id: L.CalendarId) => {
    const cal = L.calendarSystem("de", id);
    cal.monthOf(ymd(2030, 1, 1)); // build the formatters
    const start = performance.now();
    let month = cal.monthOf(ymd(2031, 5, 15));
    for (let i = 0; i < 12; i++) {
      for (let d = month.start; d < month.start + month.length; d++) cal.dayNumber(d);
      month = cal.nextMonth(month);
    }
    return performance.now() - start;
  };
  assert.ok(time("gregory") < 10, "gregory");
  for (const id of ["hebrew", "islamic-umalqura", "persian", "chinese"] as const) assert.ok(time(id) < 50, id);
});
