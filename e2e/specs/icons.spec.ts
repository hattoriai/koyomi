import { expect, test } from "@playwright/test";

import { openPage, openPopover, picker } from "./support";

test("Koyomi's icons: Lucide, named by data-icon", async ({ page }) => {
  await openPage(page);
  const calendar = picker(page, "event_due_picker").locator(".koyomi-trigger .koyomi-icon");
  await expect(calendar).toHaveAttribute("data-icon", "calendar");
  await expect(calendar).toHaveAttribute("aria-hidden", "true");
  await expect(calendar).not.toHaveAttribute("data-custom", "");
  await expect(calendar.locator("rect")).toHaveCount(1);
  await expect(picker(page, "event_at_picker").locator(".koyomi-trigger .koyomi-icon")).toHaveAttribute("data-icon", "clock");
  await expect(picker(page, "event_repeat_picker").locator(".koyomi-trigger .koyomi-icon")).toHaveAttribute("data-icon", "repeat");
});

test("setIcons: the app's icons, and Koyomi's for the others", async ({ page }) => {
  await openPage(page, "/?icons=custom");

  const calendar = picker(page, "event_due_picker").locator(".koyomi-trigger .koyomi-icon");
  await expect(calendar).toHaveClass(/\bapp-icon\b/);
  await expect(calendar).toHaveAttribute("data-icon", "calendar");
  await expect(calendar).toHaveAttribute("data-custom", "");
  await expect(calendar).toHaveAttribute("aria-hidden", "true");
  // A custom icon keeps its own fill.
  expect(await calendar.evaluate((icon) => getComputedStyle(icon).fill)).not.toBe("none");

  // The clock is not replaced.
  const clock = picker(page, "event_at_picker").locator(".koyomi-trigger .koyomi-icon");
  await expect(clock).not.toHaveAttribute("data-custom", "");
  await expect(clock.locator("circle")).toHaveCount(1);

  // A function's element, one for each button.
  const clears = page.locator(".koyomi-clear .koyomi-icon");
  await expect(clears.first()).toHaveClass(/\bapp-close\b/);
  await expect(page.locator(".koyomi-clear span.app-close")).toHaveCount(await clears.count());

  // One chevron, mirrored for the previous month.
  const popover = await openPopover(page, "event_due_picker");
  const previous = popover.locator('.koyomi-nav[data-nav="prev"] .koyomi-icon');
  const next = popover.locator('.koyomi-nav[data-nav="next"] .koyomi-icon');
  await expect(previous).toHaveAttribute("data-custom", "");
  await expect(previous).toHaveClass(/\bkoyomi-icon-mirrored\b/);
  await expect(next).not.toHaveClass(/\bkoyomi-icon-mirrored\b/);
});
