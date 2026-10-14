import { test } from "node:test";
import assert from "node:assert/strict";

import * as iso from "../src/iso";

test("days round-trip through year, month and day", () => {
  for (let value = -800_000; value < 800_000; value += 997) {
    const { year, month, day } = iso.toYMD(value);
    assert.equal(iso.fromYMD(year, month, day), value);
  }
  assert.equal(iso.fromYMD(1970, 1, 1), 0);
  assert.equal(iso.formatISO(iso.fromYMD(2000, 2, 29)), "2000-02-29");
});

test("weekday is ISO", () => {
  assert.equal(iso.weekday(iso.parseISO("2027-03-15")!), 1);
  assert.equal(iso.weekday(iso.parseISO("2026-10-11")!), 7);
});

test("parseISO refuses dates that do not exist", () => {
  assert.equal(iso.parseISO("2027-02-29"), null);
  assert.equal(iso.parseISO("2027-04-31"), null);
  assert.equal(iso.parseISO("2027-3-1"), null);
  assert.notEqual(iso.parseISO("2028-02-29"), null);
});

test("addMonths keeps the day or takes the month's last", () => {
  const jan31 = iso.parseISO("2027-01-31")!;
  assert.equal(iso.formatISO(iso.addMonths(jan31, 1)), "2027-02-28");
  assert.equal(iso.formatISO(iso.addMonths(jan31, -2)), "2026-11-30");
  assert.equal(iso.formatISO(iso.addYears(iso.parseISO("2028-02-29")!, 1)), "2029-02-28");
});

test("ISO weeks", () => {
  assert.deepEqual(iso.isoWeek(iso.parseISO("2027-01-01")!), { year: 2026, week: 53 });
  assert.deepEqual(iso.isoWeek(iso.parseISO("2024-12-30")!), { year: 2025, week: 1 });
  assert.equal(iso.formatISO(iso.parseISOWeek("2026-W53")!), "2026-12-28");
  assert.equal(iso.parseISOWeek("2027-W53"), null);
  assert.equal(iso.formatISOWeek(iso.parseISO("2027-03-15")!), "2027-W11");
});

test("start of week for any first day", () => {
  const wed = iso.parseISO("2027-03-17")!;
  assert.equal(iso.formatISO(iso.startOfWeek(wed, 1)), "2027-03-15");
  assert.equal(iso.formatISO(iso.startOfWeek(wed, 7)), "2027-03-14");
  assert.equal(iso.formatISO(iso.startOfWeek(wed, 6)), "2027-03-13");
});

test("times", () => {
  assert.equal(iso.parseTime("14:30"), 52_200);
  assert.equal(iso.formatTime(52_200), "14:30");
  assert.equal(iso.formatTime(52_201, true), "14:30:01");
  assert.equal(iso.parseTime("24:00"), null);
});

test("local times resolve in a zone, with gaps and repeats", () => {
  const march28 = iso.parseISO("2027-03-28")!;
  const ok = iso.localToInstant(march28, iso.timeOf(12, 0), "Europe/Lisbon");
  assert.equal(ok.status, "ok");
  assert.equal(ok.offset, 60);

  // Lisbon springs forward at 01:00 to 02:00 on the last Sunday of March.
  const gap = iso.localToInstant(march28, iso.timeOf(1, 30), "Europe/Lisbon");
  assert.equal(gap.status, "gap");
  assert.deepEqual(iso.instantToLocal(gap.epochMs!, "Europe/Lisbon").time, iso.timeOf(2, 30));
  assert.equal(iso.localToInstant(march28, iso.timeOf(1, 30), "Europe/Lisbon", "reject").epochMs, null);

  // New York falls back at 02:00 to 01:00 on the first Sunday of November.
  const nov7 = iso.parseISO("2027-11-07")!;
  const earlier = iso.localToInstant(nov7, iso.timeOf(1, 30), "America/New_York");
  const later = iso.localToInstant(nov7, iso.timeOf(1, 30), "America/New_York", "later");
  assert.equal(earlier.status, "ambiguous");
  assert.equal(earlier.offset, -240);
  assert.equal(later.offset, -300);
  assert.equal(later.epochMs! - earlier.epochMs!, 3_600_000);
});

test("date times with offsets", () => {
  const parsed = iso.parseDateTime("2027-03-15T14:30:00+01:00")!;
  assert.equal(parsed.offset, 60);
  assert.equal(iso.formatDateTime(parsed.day, parsed.time, parsed.offset), "2027-03-15T14:30:00+01:00");
  assert.equal(iso.parseDateTime("2027-03-15T14:30Z")!.offset, 0);
  assert.equal(iso.parseDateTime("2027-03-15T14:30")!.offset, null);
  assert.equal(iso.formatOffset(-570), "-09:30");
});

test("today in a zone", () => {
  const instant = Date.UTC(2027, 2, 15, 23, 30);
  assert.equal(iso.formatISO(iso.today("UTC", instant)), "2027-03-15");
  assert.equal(iso.formatISO(iso.today("Asia/Tokyo", instant)), "2027-03-16");
});
