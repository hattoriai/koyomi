import { test } from "node:test";
import assert from "node:assert/strict";

import * as iso from "../src/iso";
import { checkRule, describeLanguage, describeRule, emptyRule, formatRule, occurrences, parseRule, type Rule } from "../src/rrule";
import fixture from "../../test/fixtures/recurrence.json";

const LANGS = ["en", "pt", "es", "fr", "de", "it", "nl", "ja"] as const;

function parsed(text: string): Rule {
  const result = parseRule(text);
  if (!result.ok) throw new Error(`${text}: ${result.error}`);
  return result.rule;
}

for (const [index, c] of fixture.valid.entries()) {
  test(`fixture ${index}: ${c.input}`, () => {
    const rule = parsed(c.input);
    assert.deepEqual(rule, c.rule);
    assert.equal(formatRule(rule), c.canonical);
    assert.deepEqual(parsed(c.canonical), rule);
    assert.equal(checkRule(rule), null);

    const start = iso.parseISO(c.start)!;
    assert.deepEqual(occurrences(rule, start, c.limit).map(iso.formatISO), c.occurrences);

    for (const lang of LANGS) {
      assert.equal(describeRule(rule, lang), c.describe[lang], lang);
      const fromStart = (c as { describeFromStart?: Record<string, string> }).describeFromStart;
      if (fromStart) assert.equal(describeRule(rule, lang, start), fromStart[lang], `${lang} from start`);
    }
  });
}

for (const [index, c] of fixture.invalid.entries()) {
  test(`fixture invalid ${index}: ${JSON.stringify(c.input)}`, () => {
    assert.deepEqual(parseRule(c.input), { ok: false, error: c.error });
  });
}

test("occurrences stop at an extra end day", () => {
  const rule = parsed("FREQ=DAILY");
  const start = iso.parseISO("2027-01-01")!;
  assert.deepEqual(occurrences(rule, start, 100, start + 2).map(iso.formatISO), ["2027-01-01", "2027-01-02", "2027-01-03"]);
  assert.deepEqual(occurrences(rule, start, 0), []);
});

test("a rule that never produces gives the start only", () => {
  const rule = parsed("FREQ=DAILY;BYMONTH=2;BYMONTHDAY=30");
  assert.deepEqual(occurrences(rule, iso.parseISO("2027-01-01")!, 5).map(iso.formatISO), ["2027-01-01"]);
});

test("occurrences end at the year 9999", () => {
  const rule = parsed("FREQ=YEARLY;INTERVAL=1000");
  const days = occurrences(rule, iso.parseISO("2027-01-01")!, 100);
  assert.equal(iso.formatISO(days[days.length - 1]!), "9027-01-01");
});

test("checkRule finds what parseRule would refuse", () => {
  assert.equal(checkRule({ ...emptyRule("weekly"), byMonthDay: [1] }), "BYMONTHDAY cannot be used with FREQ=WEEKLY");
  assert.equal(checkRule({ ...emptyRule("daily"), interval: 0 }), "INTERVAL must be a positive whole number");
  assert.equal(checkRule({ ...emptyRule("daily"), until: "2027-02-30" }), "UNTIL must be a date (20271231) or a UTC date and time (20271231T235959Z)");
  assert.equal(checkRule({ ...emptyRule("monthly"), byDay: [{ ordinal: 6, weekday: 1 }] }), "BYDAY has an invalid day: 6MO");
});

test("formatRule writes UNTIL as the RFC does", () => {
  assert.equal(formatRule({ ...emptyRule("daily"), until: "2027-12-31T23:59:59Z" }), "FREQ=DAILY;UNTIL=20271231T235959Z");
});

test("a region variant takes its language, an unknown one English", () => {
  assert.equal(describeLanguage("pt-BR"), "pt");
  assert.equal(describeLanguage("en_GB"), "en");
  assert.equal(describeLanguage("ko"), "en");
  assert.equal(describeRule(parsed("FREQ=MONTHLY;BYDAY=-1FR"), "ko"), "Monthly on the last Friday");
});
