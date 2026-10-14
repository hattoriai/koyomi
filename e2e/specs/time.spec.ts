import { expect, test } from "@playwright/test";

import { expectPosted, openPage, openPopover, picker } from "./support";

test.describe("time pickers", () => {
  test.beforeEach(async ({ page }) => openPage(page));

  test("a time from the list, in steps of the rules", async ({ page }) => {
    const popover = await openPopover(page, "event_at_picker");
    const list = popover.getByRole("listbox");
    await expect(list).toBeFocused();
    // 08:00 to 18:00 in steps of 15 minutes.
    await expect(list.getByRole("option")).toHaveCount(41);
    await list.getByRole("option", { name: "09:15" }).click();
    await expectPosted(page, "at", "09:15:00");
  });

  test("typed segments", async ({ page }) => {
    await picker(page, "event_at_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("1430");
    await expectPosted(page, "at", "14:30:00");
  });

  test("a date and time in a zone is posted with the zone's offset", async ({ page }) => {
    await picker(page, "event_starts_at_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("150720271430");
    await expectPosted(page, "starts_at", "2027-07-15T14:30:00+01:00");
  });

  test("a time that the clocks skip moves forward, with a notice", async ({ page }) => {
    await picker(page, "event_starts_at_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("280320270130");
    await expectPosted(page, "starts_at", "2027-03-28T02:30:00+01:00");
    await picker(page, "event_starts_at_picker").locator(".koyomi-trigger").click();
    await expect(picker(page, "event_starts_at_picker").locator(".koyomi-notice")).toContainText("skipped");
  });

  test("a time that happens twice takes the first, or the second when asked", async ({ page }) => {
    await picker(page, "event_starts_at_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("311020270130");
    await expectPosted(page, "starts_at", "2027-10-31T01:30:00+01:00");
    await picker(page, "event_starts_at_picker").locator(".koyomi-trigger").click();
    const notice = picker(page, "event_starts_at_picker").locator(".koyomi-notice");
    await expect(notice).toContainText("twice");
    await notice.getByRole("button", { name: /second/i }).click();
    await expectPosted(page, "starts_at", "2027-10-31T01:30:00Z");
  });

  test("a local date and time has no offset", async ({ page }) => {
    await picker(page, "event_local_at_picker").locator(".koyomi-segment").first().click();
    await page.keyboard.type("150720270905");
    await expectPosted(page, "local_at", "2027-07-15T09:05:00");
  });
});
