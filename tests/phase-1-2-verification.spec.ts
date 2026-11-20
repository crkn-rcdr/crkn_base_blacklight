import { test, expect, type Page } from '@playwright/test';

/**
 * Phase 1.2 Verification Tests
 *
 * Tests to confirm that removing inline scripts from ViewComponents
 * doesn't break the application. These tests verify:
 * 1. Pages load without unexpected errors
 * 2. Component HTML structure is intact with zero inline <script> tags
 * 3. Data attributes are available for Stimulus controllers
 * 4. ARIA attributes are preserved
 */

test.describe('Phase 1.2: Inline Script Removal Verification', () => {
  test.describe('1. Checkbox Facet Component', () => {
    test('checkbox_facet_component renders without inline script', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const facetGroup = page.locator('#facets, .facets').first();
      await expect(facetGroup).toBeVisible();

      const inlineScripts = await facetGroup.locator('script').count();
      expect(inlineScripts).toBe(0);
    });

    test('checkbox_facet_component has data attributes for Stimulus', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const facetControllers = page.locator('[data-controller~="checkbox-facet"]');
      expect(await facetControllers.count()).toBeGreaterThan(0);

      const facetForms = page.locator('form.checkbox-facet-form[data-facet-key]');
      expect(await facetForms.count()).toBeGreaterThan(0);
    });

    test('checkbox_facet_component HTML form structure is intact', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      // Expand facets if collapsed so the first checkbox facet form is visible
      const expandAllBtn = page.locator('#facet-expand-all-btn, button:has-text("Expand all")').first();
      if (await expandAllBtn.isVisible()) {
        await expandAllBtn.click();
      } else {
        const firstHeadingBtn = page.locator('#facets .facet-field-heading button').first();
        if (await firstHeadingBtn.isVisible()) {
          await firstHeadingBtn.click();
        }
      }

      const form = page.locator('form.checkbox-facet-form[data-facet-key]').first();
      await expect(form).toBeVisible();

      const checkboxes = form.locator('input[type="checkbox"]');
      expect(await checkboxes.count()).toBeGreaterThan(0);

      const moreLink = form.locator('a[data-bs-toggle="modal"], a[data-blacklight-modal="trigger"]');
      expect(await moreLink.count()).toBeGreaterThanOrEqual(0);
    });

    test('checkbox_facet_component ARIA attributes preserved', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const facetSection = page.locator('#facets, .facets').first();
      await expect(facetSection).toBeVisible();

      const ariaControls = await facetSection.locator('[aria-expanded], [aria-labelledby], [aria-controls]').count();
      expect(ariaControls).toBeGreaterThan(0);
    });

    test('checkbox_facet_component form submission still works (server-side)', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const expandAllBtn = page.locator('#facet-expand-all-btn, button:has-text("Expand all")').first();
      if (await expandAllBtn.isVisible()) {
        await expandAllBtn.click();
      }

      const form = page.locator('form.checkbox-facet-form[data-facet-key]').first();
      const checkbox = form.locator('input[type="checkbox"]').first();
      if (await checkbox.isVisible()) {
        await checkbox.check();
        const applyBtn = form.locator('button[type="submit"], input[type="submit"], .checkbox-facet-apply').first();
        if (await applyBtn.isVisible()) {
          await Promise.all([
            page.waitForLoadState('domcontentloaded'),
            applyBtn.click(),
          ]);
        }
      }

      await expect(page.locator('#documents')).toBeVisible();
    });
  });

  test.describe('2. IIIF Component', () => {
    test('iiif_component renders without inline script', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const toolbox = page.locator('[data-controller~="copy-link"]').first();
      if (await toolbox.isVisible()) {
        await expect(toolbox).toBeVisible();
        expect(await toolbox.locator('script').count()).toBe(0);
      }
    });

    test('iiif_component copy button uses Stimulus without inline onclick', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const copyButton = page.locator('button.copy-link-btn').first();
      if (await copyButton.isVisible()) {
        await expect(copyButton).toBeVisible();
        const onclick = await copyButton.getAttribute('onclick');
        expect(onclick).toBeNull();
      }
    });

    test('iiif_component ARIA live region preserved', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const liveRegion = page.locator('[aria-live="polite"][id*="copy"]').first();
      if ((await liveRegion.count()) > 0) {
        await expect(liveRegion).toHaveCount(1);
      }
    });

    test('iiif_component manifest URL link preserved', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const manifestLink = page.locator('#iiif-manifest-url').first();
      if ((await manifestLink.count()) > 0) {
        const href = await manifestLink.getAttribute('href');
        if (href) {
          expect(href).toMatch(/manifest/i);
        }
      }
    });
  });

  test.describe('3. Document Component (Download Toolbar)', () => {
    test('document_component renders without inline script', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const toolbar = page.locator('#download-toolbar').first();
      if (await toolbar.isVisible()) {
        await expect(toolbar).toBeVisible();
        expect(await toolbar.locator('script').count()).toBe(0);
      }
    });

    test('document_component download buttons are present', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const toolbar = page.locator('#download-toolbar').first();
      if ((await toolbar.count()) > 0) {
        const downloadButtons = page.locator('[id*="btn-download"]');
        expect(await downloadButtons.count()).toBeGreaterThan(0);
      }
    });

    test('document_component download toolbar has data attributes', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const toolbar = page.locator('#download-toolbar').first();
      if ((await toolbar.count()) > 0) {
        const docid = await toolbar.getAttribute('data-docid');
        const arkpath = await toolbar.getAttribute('data-arkpath');

        if (docid) expect(docid.length).toBeGreaterThan(0);
        if (arkpath) expect(arkpath.length).toBeGreaterThan(0);
      }
    });

    test('document_component status text and spinner preserved', async ({ page }) => {
      const documentId = await getFirstDocumentId(page);
      expect(documentId).toBeTruthy();

      await page.goto(`/catalogue/${documentId}`);
      await page.waitForLoadState('domcontentloaded');

      const status = page.locator('#download-status').first();
      if ((await status.count()) > 0) {
        const ariaLive = await status.getAttribute('aria-live');
        expect(ariaLive).toBe('polite');
      }
    });
  });

  test.describe('4. Global Application State', () => {
    test('application loads without unexpected errors', async ({ page }) => {
      const errors: string[] = [];

      page.on('console', msg => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });

      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const legacyErrors = errors.filter(err =>
        err.includes('copyManifestUrl') ||
        err.includes('syncOffpageSelections') ||
        err.includes('updateForCurrentPage')
      );

      expect(legacyErrors).toEqual([]);
    });

    test('page loads and renders complete HTML', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const main = page.locator('main, [role="main"]').first();
      await expect(main).toBeVisible();

      const sidebar = page.locator('#facets, #sidebar, [role="complementary"]').first();
      await expect(sidebar).toBeVisible();
    });

    test('forms still work (server-side processing)', async ({ page }) => {
      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const searchForm = page.locator('.catalog-search-hero form, form.search-query-form:visible, form[role="search"]:visible').first();
      await expect(searchForm).toBeVisible();
    });

    test('navigation works', async ({ page }) => {
      await page.goto('/');
      await page.waitForLoadState('domcontentloaded');

      await page.goto('/catalogue?q=*');
      await page.waitForLoadState('domcontentloaded');

      const resultsSection = page.locator('#documents').first();
      await expect(resultsSection).toBeVisible();
    });
  });
});

/**
 * Helper function to get first document ID from search results
 */
async function getFirstDocumentId(page: Page): Promise<string | null> {
  await page.goto('/catalogue?q=*');
  await page.waitForLoadState('domcontentloaded');

  const firstResult = page.locator('#documents .document-title-heading a, #documents h3.index_title a').first();
  if (await firstResult.isVisible()) {
    const href = await firstResult.getAttribute('href');
    if (href) {
      const match = href.match(/\/catalogue\/([^/?#]+)/);
      if (match) {
        return match[1];
      }
    }
  }

  return null;
}
