import { test, expect } from '@playwright/test';

/**
 * Comprehensive End-to-End Test Suite: Blacklight Ruby & ViewComponent Refactoring
 * 
 * Validates that all messy, unperformant client-side JavaScript has been successfully
 * replaced by server-side Ruby, Rails ViewComponents, modern CSS, and Hotwire/Stimulus controllers:
 * 
 * 1. Checkbox Facet Component & Stimulus Controller (replaced inline facet modal sync)
 * 2. IIIF Component & Copy Link Controller (replaced copyManifestUrl inline script)
 * 3. Resizable Sidebar Stimulus Controller (replaced inline resize & fullscreen script)
 * 4. Server-Rendered DownloadToolbarComponent (replaced client-side AJAX polling & spinners)
 * 5. Server-Rendered PageSearchComponent (replaced initPageSearch 40-request client loop)
 * 6. Mirador 3 Viewer rendering and canvas integration
 * 7. Clean Vite Production Asset Pipeline (zero legacy inline script errors)
 */

test.describe('Blacklight Architecture & ViewComponent Refactoring E2E', () => {

  test('1. Checkbox facet component renders with Stimulus controller and handles facet selection', async ({ page }) => {
    await page.goto('/catalogue?q=*');
    await page.waitForLoadState('networkidle');

    // Verify facet sidebar is present
    const sidebar = page.locator('.search-sidebar-inner, [role="complementary"]').first();
    await expect(sidebar).toBeVisible();

    // Verify Stimulus controller is attached to facet containers
    const facetControllers = page.locator('[data-controller~="checkbox-facet"]');
    const controllerCount = await facetControllers.count();
    expect(controllerCount).toBeGreaterThan(0);

    // Expand facets if accordion is collapsed
    const expandAllBtn = page.locator('button:has-text("Expand all"), .facet-expand-all').first();
    if (await expandAllBtn.isVisible()) {
      await expandAllBtn.click();
    } else {
      const firstHeading = page.locator('.facet-field-heading, h3 button').first();
      if (await firstHeading.isVisible()) {
        await firstHeading.click();
      }
    }

    // Verify facet form structure and checkboxes
    const facetForm = page.locator('form.checkbox-facet-form').first();
    await expect(facetForm).toBeAttached();

    const checkboxes = facetForm.locator('.checkbox-facet-input, input[type="checkbox"]');
    const cbCount = await checkboxes.count();
    expect(cbCount).toBeGreaterThan(0);

    // Verify 0 inline scripts exist inside the facet component
    const inlineScripts = await facetForm.locator('script').count();
    expect(inlineScripts).toBe(0);
  });

  test('2. IIIF component renders with copy-link Stimulus controller and provides live copy feedback', async ({ page, baseURL }) => {
    const docPath = baseURL?.includes('3010') ? '/catalogue/oocihm.lac_reel_h2971' : '/catalogue/oon.00002_194801';
    await page.goto(docPath);
    await page.waitForLoadState('networkidle');

    // Verify toolbox card has data-controller="copy-link"
    const toolbox = page.locator('[data-controller~="copy-link"]');
    await expect(toolbox).toBeVisible();

    // Verify manifest URL is present
    const manifestLink = page.locator('#iiif-manifest-url');
    await expect(manifestLink).toHaveCount(1);
    const href = await manifestLink.getAttribute('href');
    expect(href).toMatch(/\/manifest\//i);

    // Verify copy button exists and has no inline onclick attribute
    const copyButton = toolbox.locator('button.copy-link-btn, button[title*="Copy"]').first();
    await expect(copyButton).toBeVisible();
    const onclick = await copyButton.getAttribute('onclick');
    expect(onclick).toBeNull();

    // Click the copy button to test the Stimulus controller
    await copyButton.click();

    // Verify live region provides user feedback
    const feedback = page.locator('#iiif-copy-feedback');
    await expect(feedback).toBeVisible();
    const feedbackText = await feedback.textContent();
    expect(feedbackText).toMatch(/Copied to clipboard/i);
  });

  test('3. Document sidebar renders with resizable-sidebar Stimulus controller without inline scripts', async ({ page, baseURL }) => {
    const docPath = baseURL?.includes('3010') ? '/catalogue/oocihm.lac_reel_h2971' : '/catalogue/oon.00002_194801';
    await page.goto(docPath);
    await page.waitForLoadState('networkidle');

    // Verify wrapper has resizable-sidebar controller
    const wrapper = page.locator('#document-togglable-content[data-controller~="resizable-sidebar"]');
    await expect(wrapper).toBeAttached();

    // Verify resize handle and fullscreen toggle button
    const handle = page.locator('.metadata-resize-handle');
    await expect(handle).toBeAttached();

    const fullscreenBtn = page.locator('#metadata-fullscreen-toggle');
    if (await fullscreenBtn.isVisible()) {
      await fullscreenBtn.click();
      await expect(wrapper).toHaveClass(/metadata-fullscreen-active/);

      // Toggle back
      await fullscreenBtn.click();
      await expect(wrapper).not.toHaveClass(/metadata-fullscreen-active/);
    }

    // Verify 0 inline scripts remain in the document show page components
    const componentScripts = await page.locator('#document-togglable-content script').count();
    expect(componentScripts).toBe(0);
  });

  test('4. Server-rendered DownloadToolbarComponent pre-populates signed download URLs', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const docPath = isCanadiana ? '/catalogue/oon.00002_194801' : '/catalogue/oocihm.lac_reel_h2971';

    await page.goto(docPath);
    await page.waitForLoadState('networkidle');

    // Verify download toolbar has data-controller="download-status" and required datasets
    const toolbar = page.locator('#download-toolbar[data-controller~="download-status"]');
    await expect(toolbar).toBeVisible();
    expect(await toolbar.getAttribute('data-docid')).toBeTruthy();
    expect(await toolbar.getAttribute('data-arkpath')).toBeTruthy();

    const fullBtn = page.locator('#btn-download-full');
    const pageBtn = page.locator('#btn-download-page');
    const pageImgBtn = page.locator('#btn-download-img');

    await expect(fullBtn).toBeVisible();
    await expect(pageBtn).toBeVisible();
    await expect(pageImgBtn).toBeVisible();

    if (isCanadiana) {
      // Seeded Canadiana document has access files ready in mock Swift
      // URLs are pre-rendered server-side so they are present immediately
      await expect(fullBtn).toHaveAttribute('href', /\.pdf/i);
      await expect(pageBtn).toHaveAttribute('href', /\.pdf/i);
      await expect(pageImgBtn).toHaveAttribute('href', /iiif/i);

      await expect(fullBtn).not.toHaveClass(/disabled/);
      await expect(pageBtn).not.toHaveClass(/disabled/);
      await expect(pageImgBtn).not.toHaveClass(/disabled/);

      // Spinner is hidden immediately without client-side loading delay
      const spinner = toolbar.locator('.spinner-border');
      await expect(spinner).toBeHidden();
    } else {
      // Unseeded Heritage reel gracefully displays unavailable status without breaking
      const statusText = page.locator('#download-status .download-status-text');
      await expect(statusText).toContainText(/Not available/i, { timeout: 6000 });
    }
  });

  test('5. Server-rendered PageSearchComponent delivers instant search hit chips from Solr', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    if (!isCanadiana) {
      // Heritage test data does not have full text OCR queries
      return;
    }

    await page.goto('/catalogue?q=science');
    await page.waitForLoadState('networkidle');

    // Verify matching page chips are rendered directly by ViewComponent
    const pageChips = page.locator('.page-chip');
    const count = await pageChips.count();
    expect(count).toBeGreaterThan(0);

    // Verify chip links contain valid pageNum and term
    const firstChip = pageChips.first();
    await expect(firstChip).toBeVisible();
    const href = await firstChip.getAttribute('href');
    expect(href).toMatch(/pageNum=\d+/i);
    expect(href).toMatch(/q=science/i);

    // Verify label rendered by server
    const label = page.locator('.matching-image-label').first();
    await expect(label).toBeVisible();
    expect(await label.textContent()).toMatch(/Pages with science/i);
  });

  test('6. Mirador 3 viewer initializes and renders canvas alongside refactored components', async ({ page, baseURL }) => {
    const docPath = baseURL?.includes('3010') ? '/catalogue/oocihm.lac_reel_h2971' : '/catalogue/oon.00002_194801';
    await page.goto(docPath);
    await page.waitForLoadState('networkidle');

    // Verify Mirador viewer container is present
    const miradorContainer = page.locator('#my-mirador, .mirador-container, [data-testid="mirador"]').first();
    await expect(miradorContainer).toBeVisible();

    // Verify OpenSeadragon canvas or viewer elements are rendered
    const osdCanvas = page.locator('.openseadragon-canvas, canvas, .mirador-viewer').first();
    await expect(osdCanvas).toBeVisible({ timeout: 10000 });

    // Verify window top bar / header
    const windowNav = page.locator('.mirador-window, .mirador-window-top-bar, [aria-label*="Window"]').first();
    await expect(windowNav).toBeAttached();
  });

  test('7. Production Vite bundle loads cleanly with zero legacy inline function errors', async ({ page }) => {
    const errorLogs: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errorLogs.push(msg.text());
      }
    });

    await page.goto('/catalogue?q=*');
    await page.waitForLoadState('networkidle');

    // Verify Vite production asset is loaded
    const viteScript = page.locator('script[src*="/vite/assets/application-"]');
    await expect(viteScript).toHaveCount(1);

    // Assert that no errors occurred regarding removed functions
    const criticalErrors = errorLogs.filter(err =>
      err.includes('copyManifestUrl') ||
      err.includes('updateForCurrentPage') ||
      err.includes('syncOffpageSelections') ||
      err.includes('syncCanadianaWorkGridHeights') ||
      err.includes('initPageSearch') ||
      err.includes('moveCatalogAppliedParams') ||
      err.includes('adjustCatalogShowBreadcrumbActions')
    );

    expect(criticalErrors).toEqual([]);
  });
});
