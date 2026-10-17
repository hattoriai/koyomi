import { expect, test } from "@playwright/test";

import { addDays, dayButton, expectPosted, openPage, openPopover, picker, today } from "./support";

// A filter bar: a relative day and a relative range (keys "start" and
// "end"), kept in the URL.
test.describe("relative pickers in a filter bar", () => {
  test.beforeEach(async ({ page }) => openPage(page, "/filters"));

  test("a key from the URL shows as its preset and the days it covers today", async ({ page }) => {
    const period = picker(page, "filter_period__picker").locator(".koyomi-relative");
    await expect(period).toBeVisible();
    await expect(period.locator(".koyomi-relative-name")).toHaveText("Last 7 days");
    await expect(picker(page, "filter_period__picker").locator(".koyomi-segments").first()).toBeHidden();
    await expect(picker(page, "filter_day__picker").locator(".koyomi-relative-name")).toHaveText("Today");
  });

  test("a preset posts its key, and stays pressed", async ({ page }) => {
    const popover = await openPopover(page, "filter_period__picker");
    await popover.locator(".koyomi-preset", { hasText: "This month" }).click();
    await expect(popover).toBeHidden();
    await expectPosted(page, "period", "this_month");
    await expect(page).toHaveURL(/filter(\[|%5B)period(\]|%5D)=this_month/);
    await expect(picker(page, "filter_period__picker").locator(".koyomi-relative-name")).toHaveText("This month");

    const again = await openPopover(page, "filter_period__picker");
    await expect(again.locator(".koyomi-preset", { hasText: "This month" })).toHaveAttribute("aria-pressed", "true");
  });

  test("days picked in the calendar post the range with its own keys", async ({ page }) => {
    const popover = await openPopover(page, "filter_period__picker");
    const now = await today(page);
    // Two days in the months the calendar shows: those of the last 7 days.
    const first = addDays(now, -3);
    const last = addDays(now, -1);
    await dayButton(popover, first).first().click();
    await dayButton(popover, last).first().click();
    await expectPosted(page, "period", { start: first, end: last });
    await expect(picker(page, "filter_period__picker").locator(".koyomi-relative")).toBeHidden();
  });

  test("words that a preset gives choose that preset", async ({ page }) => {
    const popover = await openPopover(page, "filter_period__picker");
    const box = popover.locator(".koyomi-typing input");
    await box.fill("last 30 days");
    await box.press("Enter");
    await expectPosted(page, "period", "last_30_days");
  });

  test("Backspace on a preset clears it", async ({ page }) => {
    const day = picker(page, "filter_day__picker").locator(".koyomi-relative");
    await day.focus();
    await page.keyboard.press("Backspace");
    await expectPosted(page, "day", "");
    await expect(day).toBeHidden();
  });

  test("a day picked in a relative date picker posts the day", async ({ page }) => {
    const popover = await openPopover(page, "filter_day__picker");
    const day = addDays(await today(page), -3);
    await dayButton(popover, day).first().click();
    await expectPosted(page, "day", day);
  });
});
