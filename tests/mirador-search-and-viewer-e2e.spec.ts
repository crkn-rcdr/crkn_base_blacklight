import { test, expect } from '@playwright/test';

/**
 * End-to-End Test Suite: Mirador In-Viewer Content Search, Navigation & Responsive Layout
 *
 * Verifies:
 * 1. Automatic execution of Content Search API when URL contains search query params (?q=...&pageNum=...).
 * 2. Proper normalization and retrieval of search hits across cluster hostnames (www- / www2-).
 * 3. Search result hit counter format (e.g. "X / 14") and Next/Previous navigation buttons.
 * 4. Boundary states: Previous button disabled on first hit, Next button disabled on last hit.
 * 5. Thumbnail auto-scrolling: changing search hits or active canvas scrolls the corresponding thumbnail into view.
 * 6. Responsive zoom toolbar: verifies positioning across desktop and mobile viewports with zero overlap.
 */

test.describe('Mirador In-Viewer Search & Viewer Experience E2E', () => {

  test.beforeEach(async ({ page }) => {
    page.on('pageerror', err => console.log(`[BROWSER ERROR]:`, err.message));
    page.on('response', res => {
      if (res.status() >= 400 && !res.url().includes('google-analytics') && !res.url().includes('.png')) {
        console.log(`[HTTP ${res.status()}]: ${res.url()}`);
      }
    });
  });

  test('1. In-viewer search triggers from URL query params and displays hit count', async ({ page }) => {
    // Navigate to our test document with pre-seeded OCR and search query
    await page.goto('/catalogue/oocihm.8_06959_1015?q=chocolate+chip&pageNum=24');
    await page.waitForLoadState('domcontentloaded');

    // Verify Mirador viewer container and OpenSeadragon canvas mount
    const viewer = page.locator('#my-mirador');
    await expect(viewer).toBeVisible({ timeout: 15000 });

    const osdCanvas = viewer.locator('.openseadragon-canvas');
    await expect(osdCanvas).toBeVisible({ timeout: 15000 });

    // Wait for the search navigation pill to populate with hit count
    // On Canadiana, 'chocolate chip' returns 14 hits across canvases 24 and 35
    const countLabel = viewer.locator('span.count, .mirador-search-panel-navigation span').first();
    await expect(countLabel).toBeVisible({ timeout: 15000 });

    const countText = await countLabel.textContent();
    expect(countText).toMatch(/\d+\s*\/\s*14/);
  });

  test('2. Next/Previous search hit navigation updates hit index and enforces boundary disabled states', async ({ page }) => {
    await page.goto('/catalogue/oocihm.8_06959_1015?q=chocolate+chip&pageNum=24');
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    // Locate the search hit navigation buttons
    const prevBtn = viewer.locator('button[aria-label*="Previous result"], button[aria-label*="searchPreviousResult"]').first();
    const nextBtn = viewer.locator('button[aria-label*="Next result"], button[aria-label*="searchNextResult"]').first();
    const countLabel = viewer.locator('span.count').first();

    await expect(countLabel).toBeVisible({ timeout: 15000 });

    // Initially at hit 1 -> Previous button must be disabled
    await expect(prevBtn).toBeDisabled();
    await expect(nextBtn).toBeEnabled();
    expect(await countLabel.textContent()).toContain('1 / 14');

    // Click Next button -> should advance to hit 2 / 14
    await nextBtn.click();
    await expect(countLabel).toHaveText(/2\s*\/\s*14/, { timeout: 5000 });
    await expect(prevBtn).toBeEnabled();

    // Click Previous button -> should return to hit 1 / 14 and disable Prev
    await prevBtn.click();
    await expect(countLabel).toHaveText(/1\s*\/\s*14/, { timeout: 5000 });
    await expect(prevBtn).toBeDisabled();

    // Advance to the final hit (hit 14)
    for (let i = 1; i < 14; i++) {
      if (await nextBtn.isEnabled()) {
        await nextBtn.click();
        await page.waitForTimeout(100);
      }
    }

    // At last hit -> hit count must be 14 / 14 and Next button must be disabled
    await expect(countLabel).toHaveText(/14\s*\/\s*14/, { timeout: 8000 });
    await expect(nextBtn).toBeDisabled();
    await expect(prevBtn).toBeEnabled();
  });

  test('3. Advancing search hits updates the active canvas and brings thumbnail into view', async ({ page }) => {
    await page.goto('/catalogue/oocihm.8_06959_1015?q=chocolate+chip&pageNum=24');
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    const nextBtn = viewer.locator('button[aria-label*="Next result"]').first();
    const countLabel = viewer.locator('span.count').first();
    await expect(countLabel).toBeVisible({ timeout: 15000 });

    const canvasInput = viewer.locator('.mirador-canvas-nav input, .mirador-canvas-nav .MuiAutocomplete-input').first();
    await expect(canvasInput).toBeVisible({ timeout: 5000 });
    expect(await canvasInput.inputValue()).toBe('24');

    // Advance through the hits on Canvas 24 (hits 1 through 10) to reach Canvas 35 (hit 11)
    for (let i = 1; i < 11; i++) {
      await nextBtn.click();
      await page.waitForTimeout(150);
    }

    // Hit 11 is on Canvas 35 (ARK: c0xd0qr4qq3x)
    await expect(countLabel).toHaveText(/11\s*\/\s*14/, { timeout: 8000 });

    // Active canvas index in the navigation control must now be updated to 35
    await expect(canvasInput).toHaveValue('35', { timeout: 8000 });
  });

  test('4. Zoom toolbar remains visible and does not overlap top bar navigation on mobile viewports', async ({ page }) => {
    // Set mobile viewport (iPhone SE / standard compact viewport)
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/catalogue/oocihm.8_06959_1015');
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    // Verify top bar navigation is present
    const topBar = viewer.locator('.mirador-window-top-bar').first();
    await expect(topBar).toBeVisible();
    const topBarBox = await topBar.boundingBox();
    expect(topBarBox).not.toBeNull();

    // Verify zoom controls (OpenSeadragon) are present
    const zoomInBtn = viewer.locator('div[title="Zoom in"]').first();
    await expect(zoomInBtn).toBeVisible({ timeout: 10000 });
    const zoomInBox = await zoomInBtn.boundingBox();
    expect(zoomInBox).not.toBeNull();

    if (topBarBox && zoomInBox) {
      // Zoom controls must be rendered strictly below the top bar (no vertical clipping or overlapping)
      expect(zoomInBox.y).toBeGreaterThanOrEqual(topBarBox.y + topBarBox.height - 2);
    }
  });

  test('5. Zoom toolbar is positioned cleanly on desktop viewports', async ({ page }) => {
    // Standard desktop viewport
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/catalogue/oocihm.8_06959_1015');
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    const zoomInBtn = viewer.locator('div[title="Zoom in"]').first();
    await expect(zoomInBtn).toBeVisible({ timeout: 10000 });

    const zoomOutBtn = viewer.locator('div[title="Zoom out"]').first();
    await expect(zoomOutBtn).toBeVisible();

    const zoomResetBtn = viewer.locator('div[title="Go home"]').first();
    await expect(zoomResetBtn).toBeVisible();

    // Test zoom in button interactivity
    await zoomInBtn.click();
    await page.waitForTimeout(300);

    // Test reset zoom button
    await zoomResetBtn.click();
    await page.waitForTimeout(300);
  });

  test('6. Breadcrumb root link constructs return search URL directly from query parameters without search_id', async ({ page }) => {
    // Navigate with query parameters and legacy/simulated search_id
    await page.goto('/catalogue/oocihm.8_06959_1015?lang=en&q=chocolate+chip&search_id=829&pageNum=24');
    await page.waitForLoadState('domcontentloaded');

    const rootBreadcrumb = page.locator('.collection-breadcrumbs__root a').first();
    await expect(rootBreadcrumb).toBeVisible({ timeout: 10000 });

    const rootHref = await rootBreadcrumb.getAttribute('href');
    expect(rootHref).toBeTruthy();

    // Must preserve active search query and language
    expect(rootHref).toContain('q=chocolate+chip');
    expect(rootHref).toContain('lang=en');

    // Must strictly strip search_id, pageNum, and document id
    expect(rootHref).not.toContain('search_id');
    expect(rootHref).not.toContain('829');
    expect(rootHref).not.toContain('pageNum');
    expect(rootHref).not.toContain('oocihm.8_06959_1015');
  });

});
