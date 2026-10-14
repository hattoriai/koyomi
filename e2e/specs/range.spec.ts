import { expect, test } from "@playwright/test";

import { addDays, dayButton, expectPosted, openPage, openPopover, picker, today } from "./support";

test.describe("the range picker", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("two clicks make a range, drawn while the pointer moves", async ({ page }) => {
    const popover = await openPopover(page, "event_stay_picker");
    const from = addDays(await today(page), 1);
    const to = addDays(from, 4);
    await dayButton(popover, from).click();
    await dayButton(popover, to).hover();
    await expect(popover.locator(".koyomi-range-preview")).toHaveCount(5);
    await expect(popover.locator(".koyomi-type-preview")).toContainText("4 nights");
    await dayButton(popover, to).click();
    await expect(popover).toBeHidden();
    await expectPosted(page, "stay", { from, to });
  });

  test("days that the rules put out of reach are disabled while the end is chosen", async ({ page }) => {
    const popover = await openPopover(page, "event_stay_picker");
    const from = addDays(await today(page), 1);
    await dayButton(popover, from).click();
    // max_days is 14: the 15th day cannot end the range.
    await expect(dayButton(popover, addDays(from, 13))).not.toHaveAttribute("aria-disabled", "true");
    await expect(dayButton(popover, addDays(from, 14))).toHaveAttribute("aria-disabled", "true");
  });

  test("a range typed in words", async ({ page }) => {
    const popover = await openPopover(page, "event_stay_picker");
    await popover.locator(".koyomi-type").fill("next 7 days");
    await page.keyboard.press("Enter");
    const now = await today(page);
    await expectPosted(page, "stay", { from: now, to: addDays(now, 6) });
  });

  test("the two fields take typed dates, and the focus flows from one to the other", async ({ page }) => {
    await picker(page, "event_stay_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("0104202705042027");
    await expectPosted(page, "stay", { from: "2027-04-01", to: "2027-04-05" });
  });

  test("a preset", async ({ page }) => {
    const popover = await openPopover(page, "event_stay_picker");
    await popover.getByRole("button", { name: "Next 7 days" }).click();
    const now = await today(page);
    await expectPosted(page, "stay", { from: now, to: addDays(now, 6) });
  });
});
