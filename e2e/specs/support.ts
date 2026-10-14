// Helpers for the browser tests.

import { expect, type Locator, type Page } from "@playwright/test";

/** Opens a page and waits for the LiveView to connect and the pickers to mount. */
export async function openPage(page: Page, path = "/"): Promise<void> {
  await page.goto(path);
  if (path !== "/plain" && !path.startsWith("/plain?")) await expect(page.locator("[data-phx-main].phx-connected")).toBeVisible();
  await expect(page.locator(".koyomi.koyomi-ready").first()).toBeAttached();
}

/** A picker by its id. */
export function picker(page: Page, id: string): Locator {
  return page.locator(`#${id}`);
}

/** The params that the form posted last (the dev page writes them as JSON). */
export async function posted(page: Page): Promise<Record<string, unknown>> {
  const json = await page.locator("#posted").getAttribute("data-json");
  return JSON.parse(json ?? "{}") as Record<string, unknown>;
}

/** Waits until the posted params have `key` with `value`. */
export async function expectPosted(page: Page, key: string, value: unknown): Promise<void> {
  await expect.poll(async () => (await posted(page))[key]).toEqual(value);
}

/** Opens a picker's popover with its button. */
export async function openPopover(page: Page, id: string): Promise<Locator> {
  await picker(page, id).locator(".koyomi-trigger").click();
  const popover = picker(page, id).locator(".koyomi-popover");
  await expect(popover).toBeVisible();
  return popover;
}

/** The day button of a popover or calendar with the ISO date `iso`. */
export function dayButton(scope: Locator, iso: string): Locator {
  const [year, month, day] = iso.split("-").map(Number) as [number, number, number];
  const n = Math.round(Date.UTC(year, month - 1, day) / 86_400_000);
  return scope.locator(`.koyomi-day[data-day="${n}"]`);
}

/** Today in the browser's time zone, as YYYY-MM-DD. */
export async function today(page: Page): Promise<string> {
  return page.evaluate(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  });
}

/** Adds days to an ISO date. */
export function addDays(iso: string, days: number): string {
  const [year, month, day] = iso.split("-").map(Number) as [number, number, number];
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}
