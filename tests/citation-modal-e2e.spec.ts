import { test, expect } from '@playwright/test';

/**
 * End-to-End Test: Citation Modal ("Cite: MLA / APA / Chicago")
 *
 * Ensures clicking the sidebar citation button on an item page returns HTTP 200
 * from /catalogue/:id/citation, opens #blacklight-modal with MLA, APA, and
 * Chicago citations (plus the persistent ARK link), and closes cleanly.
 */

test.describe('Citation Modal E2E', () => {
  test('Clicking Cite: MLA / APA / Chicago opens modal with formatted citations', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('3010') || baseURL?.includes('heritage');
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oon.00002_194801';
    const docPath = `/catalogue/${docId}`;

    await page.goto(docPath, { waitUntil: 'load' });

    const citeBtn = page.locator('.sidebar-cite-btn').first();
    await expect(citeBtn).toBeVisible();
    await expect(citeBtn).toHaveAttribute('href', `/catalogue/${docId}/citation`);

    const [citationResponse] = await Promise.all([
      page.waitForResponse((res) => res.url().includes(`/catalogue/${docId}/citation`)),
      citeBtn.click(),
    ]);

    expect(citationResponse.status()).toBe(200);

    const modal = page.locator('#blacklight-modal');
    await expect(modal).toBeVisible({ timeout: 10000 });
    await expect(modal).not.toContainText(/There was a problem with your request/i);

    // Verify all three citation formats and persistent ARK link render
    await expect(modal).toContainText(/MLA/i);
    await expect(modal).toContainText(/APA/i);
    await expect(modal).toContainText(/Chicago/i);
    await expect(modal.locator('a[href*="ark:/69429/"]').first()).toBeVisible();

    // Verify modal dismisses cleanly
    const closeBtn = modal.locator('[data-bl-dismiss="modal"], .btn-close').first();
    await expect(closeBtn).toBeVisible();
    await closeBtn.click();
    await expect(modal).toBeHidden({ timeout: 5000 });
  });
});
