import { expect, test } from "@playwright/test";

import { addDays, dayButton, openPage, openPopover, picker, posted, today } from "./support";

test.describe("day content from the LiveView", () => {
  test.beforeEach(async ({ page }) => openPage(page, "/days"));

  test("labels, disabled days and descriptions", async ({ page }) => {
    const popover = await openPopover(page, "booking_room_picker");
    await expect(popover.locator(".koyomi-day-label").first()).toBeVisible();
    // Wednesdays are full.
    const full = popover.locator(".koyomi-day", { hasText: "Full" }).first();
    await expect(full).toHaveAttribute("aria-disabled", "true");
    await expect(full).toHaveAttribute("aria-label", /No rooms left/);
  });

  test("a slow server: the days come later", async ({ page }) => {
    const popover = await openPopover(page, "booking_slow_picker");
    await expect(popover.locator(".koyomi-calendar")).toHaveAttribute("aria-busy", "true");
    await expect(popover.locator(".koyomi-day-label").first()).toBeVisible({ timeout: 5000 });
    await expect(popover.locator(".koyomi-calendar")).not.toHaveAttribute("aria-busy", "true");
  });

  test("slots of a day", async ({ page }) => {
    const popover = await openPopover(page, "booking_slot_picker");
    let day = addDays(await today(page), 1);
    while ((await dayButton(popover, day).count()) === 0 || [0, 6].includes(new Date(day).getUTCDay())) day = addDays(day, 1);
    if ((await dayButton(popover, day).count()) === 0) await page.keyboard.press("PageDown");
    await dayButton(popover, day).click();
    const list = popover.getByRole("listbox");
    await expect(list.getByRole("option")).toHaveCount(16);
    const free = list.locator("[role=option]:not([aria-disabled=true])").first();
    const label = (await free.textContent())!;
    await free.click();
    await expect.poll(async () => (await posted(page)).slot).toMatch(new RegExp(`^${day}T${label}:00[+-Z]`));
  });

  test("a value pushed by the server, and the popover opened by it", async ({ page }) => {
    await page.getByRole("button", { name: "Set the room to next weekend" }).click();
    await expect.poll(async () => ((await posted(page)).room as { from: string } | undefined)?.from).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    await page.getByRole("button", { name: "Open the slot picker" }).click();
    await expect(picker(page, "booking_slot_picker").locator(".koyomi-popover")).toBeVisible();
  });

  test("a calendar on the page, with holidays of two countries", async ({ page }) => {
    const calendar = picker(page, "bookings");
    await expect(calendar.locator(".koyomi-grid")).toHaveCount(2);
    await expect(calendar.locator(".koyomi-day-label").first()).toBeVisible();
  });
});
