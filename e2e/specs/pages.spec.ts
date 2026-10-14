import { expect, test } from "@playwright/test";

import { openPage, openPopover, picker } from "./support";

test("a page without LiveView: the pickers mount and post with a plain form", async ({ page }) => {
  await openPage(page, "/plain");
  await picker(page, "due_picker").locator(".koyomi-segment").first().click();
  await page.keyboard.type("15032027");
  await page.getByRole("button", { name: "Send" }).click();
  await expect(page).toHaveURL(/due=2027-03-15/);
  await expect(picker(page, "due_picker").locator(".koyomi-segment").first()).toHaveText("15");
});

test("calendar systems: Persian digits, right to left", async ({ page }) => {
  await openPage(page, "/calendars");
  const persian = picker(page, "persian-picker");
  await expect(persian).toHaveAttribute("dir", "rtl");
  await expect(persian.locator(".koyomi-segment").first()).toHaveText(/^[۰-۹]+$/);
  const popover = await openPopover(page, "persian-picker");
  await expect(popover.locator(".koyomi-caption").first()).toHaveText(/[۰-۹]{4}/);
});

test("calendar systems: Hebrew months", async ({ page }) => {
  await openPage(page, "/calendars");
  const popover = await openPopover(page, "hebrew-picker");
  await expect(popover.locator(".koyomi-caption").first()).toHaveText(/\d{4}|[֐-׿]/);
});

test("another locale: words, first day of the week and digits", async ({ page }) => {
  await openPage(page, "/?locale=pt-PT");
  const popover = await openPopover(page, "event_due_picker");
  await expect(popover.getByRole("button", { name: "Hoje" }).first()).toBeVisible();
  await expect(popover.locator("thead th").first()).toHaveAttribute("abbr", /domingo|segunda-feira/);
});
