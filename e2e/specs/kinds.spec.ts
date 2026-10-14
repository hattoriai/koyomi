import { expect, test } from "@playwright/test";

import { addDays, dayButton, expectPosted, openPage, openPopover, picker, posted, today } from "./support";

test.describe("several days, months, weeks and years", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("days added and removed, listed as chips", async ({ page }) => {
    const popover = await openPopover(page, "event_days_picker");
    const now = await today(page);
    const days = [addDays(now, 1), addDays(now, 3), addDays(now, 5)];
    for (const day of days) await dayButton(popover, day).click();
    await expect.poll(async () => ((await posted(page)).days as string[]).filter(Boolean)).toEqual(days);
    await dayButton(popover, days[1]!).click();
    await expect.poll(async () => ((await posted(page)).days as string[]).filter(Boolean)).toEqual([days[0], days[2]]);
    await popover.getByRole("button", { name: "Done" }).click();
    const chips = picker(page, "event_days_picker").locator(".koyomi-chip");
    await expect(chips).toHaveCount(2);
    await chips.first().getByRole("button").click();
    await expect.poll(async () => ((await posted(page)).days as string[]).filter(Boolean)).toEqual([days[2]]);
  });

  test("a month from the grid of months", async ({ page }) => {
    const popover = await openPopover(page, "event_month_picker");
    await expect(popover.locator(".koyomi-cell")).toHaveCount(12);
    await popover.getByRole("button", { name: /^March \d{4}$/ }).click();
    await expect.poll(async () => (await posted(page)).month).toMatch(/^\d{4}-03$/);
  });

  test("a week: the whole row", async ({ page }) => {
    await picker(page, "event_week_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("112027");
    await expectPosted(page, "week", "2027-W11");
    const popover = await openPopover(page, "event_week_picker");
    await expect(popover.locator(".koyomi-week-selected")).toHaveCount(1);
  });

  test("a year from the grid of years", async ({ page }) => {
    const popover = await openPopover(page, "event_year_picker");
    await expect(popover.locator(".koyomi-cell")).toHaveCount(12);
    await popover.locator(".koyomi-cell").first().click();
    await expect.poll(async () => (await posted(page)).year).toMatch(/^\d{4}$/);
  });

  test("a calendar outside the form pushes its event", async ({ page }) => {
    const calendar = picker(page, "outside");
    const now = await today(page);
    await dayButton(calendar, now).click();
    await dayButton(calendar, addDays(now, 2)).click();
    await expect
      .poll(async () => JSON.parse((await page.locator("#picked").getAttribute("data-json")) ?? "null"))
      .toEqual({ from: now, to: addDays(now, 2) });
  });
});

test.describe("the recurrence picker", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("weekly on two days, ending after a count", async ({ page }) => {
    const popover = await openPopover(page, "event_repeat_picker");
    await popover.getByLabel("Repeat").selectOption("weekly");
    await expect.poll(async () => (await posted(page)).repeat).toMatch(/^FREQ=WEEKLY;BYDAY=\w\w$/);
    const pressed = popover.locator(".koyomi-weekday[aria-pressed=true]");
    await expect(pressed).toHaveCount(1);
    const other = popover.locator(".koyomi-weekday[aria-pressed=false]").first();
    await other.click();
    await expect(popover.locator(".koyomi-weekday[aria-pressed=true]")).toHaveCount(2);
    await popover.getByLabel("After").check();
    await expect.poll(async () => (await posted(page)).repeat).toMatch(/BYDAY=\w\w,\w\w;COUNT=10$/);
    await expect(popover.locator(".koyomi-recurrence-summary")).toContainText("10 times");
    await expect(popover.locator(".koyomi-occurrences li")).toHaveCount(5);
    await page.keyboard.press("Escape");
    await expect(picker(page, "event_repeat_picker").locator(".koyomi-summary")).toContainText("Weekly");
  });

  test("does not repeat", async ({ page }) => {
    const popover = await openPopover(page, "event_repeat_picker");
    await popover.getByLabel("Repeat").selectOption("daily");
    await expectPosted(page, "repeat", "FREQ=DAILY");
    await popover.getByLabel("Repeat").selectOption("");
    await expectPosted(page, "repeat", "");
  });
});
