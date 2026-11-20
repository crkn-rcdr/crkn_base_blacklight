import { test, expect } from '@playwright/test';

/**
 * End-to-End Test: Search Sort Loading Feedback & Optimized PageSearchComponent
 *
 * Validates:
 * 1. Clicking a sort option in #sort-dropdown immediately displays an accessible
 *    native <progress> loading spinner inside the toggle button and a polite
 *    live status banner above #documents while dimming results.
 * 2. After navigation completes, the sorted results load cleanly with no stuck
 *    loading state and server-rendered .page-chip links intact (Canadiana).
 */

test.describe('Search Sort Loading UX & Performance E2E', () => {
  test('Clicking a sort option shows immediate loading feedback and navigates cleanly', async ({ page }) => {
    const pageErrors: string[] = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));

    await page.goto('/catalogue?q=canada', { waitUntil: 'load' });

    const sortToggle = page.locator('#sort-dropdown .dropdown-toggle');
    await expect(sortToggle).toBeVisible();

    const initialized = await page.evaluate(() => Boolean((window as any).__searchNavLoadingInitialized));
    expect(initialized).toBe(true);

    // Phase 1: Prevent default navigation once at bubble phase (after our capture-phase
    // handler runs) so we can deterministically verify the in-flight loading UI & ARIA states.
    await page.evaluate(() => {
      const preventOnce = (e: MouseEvent) => {
        const a = (e.target as HTMLElement | null)?.closest('a');
        if (a && a.href.includes('sort=year-desc')) {
          e.preventDefault();
          document.removeEventListener('click', preventOnce);
        }
      };
      document.addEventListener('click', preventOnce);
    });

    await sortToggle.click();
    const yearDescLink = page.locator('#sort-dropdown .dropdown-item[href*="sort=year-desc"]').first();
    await expect(yearDescLink).toBeVisible();
    await yearDescLink.click();

    // Immediate button feedback with native indeterminate <progress> spinner
    await expect(sortToggle).toHaveClass(/is-search-loading/);
    await expect(sortToggle).toHaveAttribute('aria-disabled', 'true');
    await expect(sortToggle.locator('progress.search-loading-spinner')).toBeVisible();

    // Immediate results dimming + polite live status banner above #documents
    const documents = page.locator('#documents');
    await expect(documents).toHaveClass(/is-search-loading/);

    const statusBanner = page.locator('#search-loading-status[role="status"][aria-live="polite"]');
    await expect(statusBanner).toBeVisible();
    await expect(statusBanner.locator('progress.search-loading-spinner')).toBeVisible();
    await expect(statusBanner).toContainText(/Sorting results|Tri des résultats/i);

    // Phase 2: Verify bfcache pageshow cleanup restores the UI cleanly
    await page.evaluate(() => window.dispatchEvent(new Event('pageshow')));
    await expect(sortToggle).not.toHaveClass(/is-search-loading/);
    await expect(documents).not.toHaveClass(/is-search-loading/);
    await expect(statusBanner).toBeHidden();

    // Phase 3: Perform a real unintercepted sort navigation and confirm clean completion
    await sortToggle.click();
    await expect(yearDescLink).toBeVisible();
    await yearDescLink.click();
    await page.waitForURL(/sort=year-desc/, { timeout: 15000 });
    await page.waitForLoadState('domcontentloaded');

    await expect(page.locator('#documents')).not.toHaveClass(/is-search-loading/);
    await expect(page.locator('#sort-dropdown .dropdown-toggle')).not.toHaveClass(/is-search-loading/);
    expect(pageErrors).toEqual([]);
  });

  test('Switching between date sorts and relevance renders results cleanly with zero console errors', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('3010') || baseURL?.includes('heritage');
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.goto('/catalogue?q=canada&sort=date-added-desc', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('#documents')).toBeVisible();

    // On Canadiana, verify optimized PageSearchComponent still renders page chips server-side
    if (!isHeritage) {
      const chips = page.locator('.page-chip');
      expect(await chips.count()).toBeGreaterThan(0);
      const href = await chips.first().getAttribute('href');
      expect(href).toMatch(/pageNum=\d+/i);
      expect(href).toMatch(/q=canada/i);
    }

    // Switch back to Relevance via the sort dropdown
    const sortToggle = page.locator('#sort-dropdown .dropdown-toggle');
    await sortToggle.click();
    const relevanceLink = page.locator('#sort-dropdown .dropdown-item[href*="sort=relevance"]').first();
    await expect(relevanceLink).toBeVisible();
    await relevanceLink.click();

    await page.waitForURL(/sort=relevance/, { timeout: 15000 });
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('#documents')).toBeVisible();

    expect(consoleErrors).toEqual([]);
  });
});
