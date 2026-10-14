import { expect, test } from "@playwright/test";

import { openPage, openPopover, picker } from "./support";

test.describe("roles and names", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("the field is a group of spinbuttons named by the label", async ({ page }) => {
    const control = picker(page, "event_due_picker").locator(".koyomi-control");
    await expect(control).toHaveAttribute("role", "group");
    await expect(control).toHaveAttribute("aria-labelledby", "due-label");
    const segments = picker(page, "event_due_picker").getByRole("spinbutton");
    await expect(segments).toHaveCount(3);
    await expect(segments.first()).toHaveAttribute("aria-label", /day/i);
    const trigger = picker(page, "event_due_picker").locator(".koyomi-trigger");
    await expect(trigger).toHaveAttribute("aria-haspopup", "dialog");
    await expect(trigger).toHaveAttribute("aria-expanded", "false");
  });

  test("the calendar is a grid with one tab stop", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    await expect(picker(page, "event_due_picker").locator(".koyomi-trigger")).toHaveAttribute("aria-expanded", "true");
    const grid = popover.getByRole("grid");
    await expect(grid).toHaveCount(1);
    await expect(grid).toHaveAttribute("aria-labelledby", /caption/);
    await expect(popover.locator(".koyomi-day[tabindex='0']")).toHaveCount(1);
    await expect(popover.locator(".koyomi-day[aria-current=date]")).toHaveCount(1);
    await expect(popover.locator(".koyomi-day").first()).toHaveAttribute("aria-label", /\d{4}/);
  });

  test("Tab stays in the popover", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    for (let i = 0; i < 20; i++) {
      await page.keyboard.press("Tab");
      expect(await popover.evaluate((node) => node.contains(document.activeElement))).toBe(true);
    }
  });

  test("the caption opens the months, and a month opens its days", async ({ page }) => {
    const popover = await openPopover(page, "event_due_picker");
    await popover.locator("button.koyomi-caption").click();
    await expect(popover.locator(".koyomi-calendar")).toHaveAttribute("data-view", "months");
    await expect(popover.locator(".koyomi-cell[tabindex='0']")).toBeFocused();
    await page.keyboard.press("ArrowRight");
    await page.keyboard.press("Enter");
    await expect(popover.locator(".koyomi-calendar")).toHaveAttribute("data-view", "days");
  });
});
