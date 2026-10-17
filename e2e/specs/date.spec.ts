import { expect, test } from "@playwright/test";

import { addDays, dayButton, expectPosted, openPage, openPopover, picker, today } from "./support";

test.describe("the date picker", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("a day picked in the calendar is posted and shown in the field", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    await expect(popover).toHaveAttribute("role", "dialog");
    const now = await today(page);
    // The calendar opens on today, with the tab stop on it.
    await expect(dayButton(popover, now)).toBeFocused();

    const day = addDays(now, 1);
    const target = (await dayButton(popover, day).getAttribute("aria-disabled")) ? addDays(now, 2) : day;
    await dayButton(popover, target).click();
    await expect(popover).toBeHidden();
    await expectPosted(page, "due", target);

    const [year, month, d] = target.split("-");
    const segments = picker(page, "event_due_picker").locator(".koyomi-segment");
    await expect(segments).toHaveText([d!, month!, year!]);
  });

  test("the arrow keys move in the grid, and Enter picks", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    const now = await today(page);
    await page.keyboard.press("ArrowDown");
    await expect(dayButton(popover, addDays(now, 7))).toBeFocused();
    await page.keyboard.press("ArrowUp");
    await page.keyboard.press("ArrowUp");
    await expect(dayButton(popover, addDays(now, -7))).toBeFocused();
    // A day that the rules disable cannot be picked.
    let day = addDays(now, -7);
    while ((await dayButton(popover, day).getAttribute("aria-disabled")) === "true") {
      await page.keyboard.press("ArrowRight");
      day = addDays(day, 1);
    }
    await page.keyboard.press("Enter");
    await expectPosted(page, "due", day);
  });

  test("Page Down shows the next month, and Escape gives the focus back", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    const caption = popover.locator(".koyomi-caption").first();
    const before = await caption.textContent();
    await page.keyboard.press("PageDown");
    await expect(caption).not.toHaveText(before!);
    await page.keyboard.press("Escape");
    await expect(popover).toBeHidden();
    await expect(picker(page, "event_due_picker").locator(".koyomi-segment").first()).toBeFocused();
  });

  test("the segments take typed digits, in the locale's order", async ({ page }) => {
    const first = picker(page, "event_due_picker").locator(".koyomi-segment").first();
    await first.click();
    await page.keyboard.type("15032027");
    await expectPosted(page, "due", "2027-03-15");
    await expect(first).toHaveAttribute("aria-valuenow", "15");

    // The arrow keys change a segment; the day follows the month's length.
    await first.focus();
    await page.keyboard.press("ArrowUp");
    await expectPosted(page, "due", "2027-03-16");
  });

  test("a day that does not exist is not posted", async ({ page }) => {
    const first = picker(page, "event_due_picker").locator(".koyomi-segment").first();
    await first.click();
    await page.keyboard.type("31042027");
    // The day is clamped to the month's last day.
    await expectPosted(page, "due", "2027-04-30");
  });

  test("a date typed in words", async ({ page }) => {
    const first = picker(page, "event_due_picker").locator(".koyomi-segment").first();
    await first.click();
    await page.keyboard.type("tomorrow");
    const box = picker(page, "event_due_picker").locator(".koyomi-type");
    await expect(box).toBeFocused();
    await expect(box).toHaveValue("tomorrow");
    await expect(picker(page, "event_due_picker").locator(".koyomi-type-preview")).not.toBeEmpty();
    await page.keyboard.press("Enter");
    await expectPosted(page, "due", addDays(await today(page), 1));
  });

  test("a preset, and the clear button", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    // The page's rules disable Sundays: on a Saturday, "Tomorrow" is one.
    const tomorrow = popover.getByRole("button", { name: "Tomorrow" });
    const sunday = (await tomorrow.getAttribute("aria-disabled")) === "true";
    await (sunday ? popover.locator('[data-preset="in-1-week"]') : tomorrow).click();
    await expectPosted(page, "due", addDays(await today(page), sunday ? 7 : 1));
    await picker(page, "event_due_picker").locator(".koyomi-clear").click();
    await expectPosted(page, "due", "");
  });

  test("holidays are marked and named", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    for (let i = 0; i < 13; i++) {
      const holiday = popover.locator(".koyomi-holiday .koyomi-day").first();
      if (await holiday.count()) {
        await expect(holiday).toHaveAttribute("title", /.+/);
        return;
      }
      await page.keyboard.press("PageDown");
    }
    throw new Error("no holiday in a year");
  });
});
