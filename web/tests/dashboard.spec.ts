import { test, expect } from "@playwright/test";

const SECTIONS = [
  { id: "live", name: "01-hero" },
  { id: "map", name: "02-map" },
  { id: "forecast", name: "03-forecast" },
  { id: "health", name: "04-health" },
  { id: "routes", name: "05-routes" },
  { id: "widgets", name: "06-widgets" },
];

test.describe("AirWay dashboard · visual capture", () => {
  test("Full page renders without console errors", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (err) => errors.push(`[pageerror] ${err.message}`));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(`[console] ${msg.text()}`);
    });

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Confirm the hero text is there
    await expect(page.getByText("Respira con")).toBeVisible();

    // Full page screenshot
    await page.screenshot({
      path: "screenshots/00-full.png",
      fullPage: true,
      type: "png",
    });

    // Filter out expected backend/map/geoloc errors — these happen in local dev without a backend
    const IGNORED = [
      "mapbox",
      "localhost:8000",
      "GeolocationPositionError",
      "Failed to fetch",
      "ERR_CONNECTION_REFUSED",
      "Failed to load resource",
      "NetworkError",
      "a style property during rerender", // React warning on background/backgroundClip
      "conflicting property is set",
      "Updating background backgroundClip",
    ];
    const unexpected = errors.filter(
      (e) => !IGNORED.some((pat) => e.includes(pat)),
    );
    expect(unexpected).toEqual([]);
  });

  for (const section of SECTIONS) {
    test(`Section · ${section.name}`, async ({ page }) => {
      await page.goto(`/#${section.id}`);
      await page.waitForLoadState("networkidle");
      // Give animations time to settle
      await page.waitForTimeout(1200);

      const locator = page.locator(`#${section.id}`);
      await expect(locator).toBeVisible();
      await locator.screenshot({
        path: `screenshots/${section.name}.png`,
        type: "png",
      });
    });
  }

  test("Dark mode toggle works", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");

    // Flip to dark
    await page.getByRole("button", { name: /oscuro/i }).click();
    await page.waitForTimeout(500);

    const theme = await page.evaluate(() =>
      document.documentElement.dataset.theme,
    );
    expect(theme).toBe("dark");

    await page.screenshot({
      path: "screenshots/07-dark-mode.png",
      fullPage: true,
      type: "png",
    });
  });
});
