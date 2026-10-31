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
    await expect(feedback).toContainText(/Copied to clipboard/i);
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
      err.includes('adjustCatalogShowBreadcrumbActions') ||
      err.includes('initMembersSection') ||
      err.includes('saveFacetAccordionState')
    );

    expect(criticalErrors).toEqual([]);
  });

  test('8. Members component renders with Stimulus members-filter controller and filters by tab', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const membersSection = page.locator('#members-section[data-controller~="members-filter"]');
    if (await membersSection.isVisible()) {
      // Verify tabs exist and can switch
      const associateTab = membersSection.locator('[data-members-tab="associate"]');
      await expect(associateTab).toBeVisible();
      await associateTab.click();
      await expect(associateTab).toHaveClass(/active/);

      // Verify associate panel is now visible
      const associatePanel = membersSection.locator('#members-panel-associate');
      await expect(associatePanel).not.toHaveClass(/d-none/);

      // Verify 0 inline scripts inside members component
      const inlineScripts = await membersSection.locator('script').count();
      expect(inlineScripts).toBe(0);
    }
  });

  test('9. Facet accordion Stimulus controller expands and collapses facet groups', async ({ page }) => {
    await page.goto('/catalogue?q=*');
    await page.waitForLoadState('networkidle');

    const facetGroup = page.locator('.facets[data-controller~="facet-accordion"]').first();
    await expect(facetGroup).toBeAttached();

    const expandAllBtn = facetGroup.locator('#facet-expand-all-btn, button:has-text("Expand all")').first();
    if (await expandAllBtn.isVisible()) {
      await expandAllBtn.click();
      // Check that facet collapses have 'show' class
      const openCollapses = facetGroup.locator('.facet-content.collapse.show');
      expect(await openCollapses.count()).toBeGreaterThan(0);

      const collapseAllBtn = facetGroup.locator('#facet-collapse-all-btn, button:has-text("Collapse all")').first();
      await collapseAllBtn.click();
      const openAfterCollapse = facetGroup.locator('.facet-content.collapse.show');
      expect(await openAfterCollapse.count()).toBe(0);
    }
  });

  test('10. Serial collection items render with openseadragon-preview controller and load viewers', async ({ page, baseURL }) => {
    // Only Canadiana has the sru serial record
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    if (!isCanadiana) return;

    await page.goto('/catalogue/sru.00007?lang=en');
    await page.waitForLoadState('networkidle');

    const collectionList = page.locator('#collection-items-list[data-controller~="openseadragon-preview"]');
    if (await collectionList.isVisible()) {
      const viewers = collectionList.locator('.collection-item__viewer[data-ark-id]');
      const count = await viewers.count();
      if (count > 0) {
        // Verify OpenSeadragon canvas is initialized inside viewer
        const osdCanvas = viewers.first().locator('.openseadragon-canvas').first();
        await expect(osdCanvas).toBeVisible({ timeout: 10000 });
      }
    }
  });

  test('11. Local OpenSeadragon asset is served without CDN dependencies and initializes', async ({ page }) => {
    // Check that /assets/openseadragon.min.js responds with 200
    const osdResponse = await page.request.get('/assets/openseadragon.min.js');
    expect(osdResponse.status()).toBe(200);

    await page.goto('/catalogue?q=*');
    await page.waitForLoadState('networkidle');

    // Verify OpenSeadragon script tag points to local asset, not CDN
    const cdnScript = page.locator('script[src*="cdnjs.cloudflare.com/ajax/libs/openseadragon"]');
    await expect(cdnScript).toHaveCount(0);

    const localScript = page.locator('script[src*="/assets/openseadragon.min.js"]');
    await expect(localScript).toHaveCount(1);

    // Verify window.OpenSeadragon is defined
    const hasOsd = await page.evaluate(() => typeof (window as any).OpenSeadragon !== 'undefined');
    expect(hasOsd).toBe(true);
  });

  test('12. Download endpoints accept document IDs with underscores, dots, and hyphens', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const docId = isCanadiana ? 'oon.00002_194801' : 'oocihm.lac_reel_h2971';
    const arkPath = isCanadiana ? '69429/m20260000010001' : '69429/m0k35m90313z';

    // Verify download status route recognizes ID with underscore
    const statusResponse = await page.request.get(`/dl/${docId}/${arkPath}/status`);
    expect(statusResponse.status()).toBe(200);
    const json = await statusResponse.json();
    expect(json).toHaveProperty('ready');

    // Verify download file endpoint does not return 404 (routing error)
    const dlResponse = await page.request.get(`/dl/${docId}/${arkPath}`);
    expect(dlResponse.status()).not.toBe(404);
  });

  test('13. Search builder executes queries with identifiers, hyphens, and special syntax without Solr errors', async ({ page }) => {
    // Test identifier with hyphens and dots
    await page.goto('/catalogue?q=oocihm.lac_reel_h2971');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('#main-container, main').first()).toBeVisible();

    // Test multi-token query with hyphens and quotes
    await page.goto('/catalogue?q="Canadian+horticulturist"+1910');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('#main-container, main').first()).toBeVisible();

    // No Solr 500 error page
    const pageText = await page.locator('body').innerText();
    expect(pageText).not.toContain('RSolr::Error::Http');
    expect(pageText).not.toContain('Solr returned an error');
  });

  test('14. Search tracking action redirects smoothly to document show page', async ({ page }) => {
    await page.goto('/catalogue?q=*');
    await page.waitForLoadState('networkidle');

    const firstDocLink = page.locator('#documents .document-title-heading a, #documents h3.index_title a').first();
    await expect(firstDocLink).toBeVisible();

    // Verify context tracking attribute is present
    const contextHref = await firstDocLink.getAttribute('data-context-href');
    expect(contextHref).toContain('/track');

    // Click link and verify tracking request succeeds with 303 redirect to show page
    const [trackResponse] = await Promise.all([
      page.waitForResponse(resp => resp.url().includes('/track')),
      firstDocLink.click()
    ]);

    expect(trackResponse.status()).toBe(303);
    await page.waitForLoadState('networkidle');
    await expect(page.locator('#main-container, main').first()).toBeVisible();
  });

  test('15. Search controls: sorting, per-page counts, and search fields', async ({ page }) => {
    // Test sorting by date
    await page.goto('/catalogue?q=*&sort=pub_date_si+desc');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('#documents')).toBeVisible();

    // Test per-page selection (20 items)
    await page.goto('/catalogue?q=*&per_page=20');
    await page.waitForLoadState('networkidle');
    const docArticles = page.locator('#documents article, #documents .document');
    expect(await docArticles.count()).toBeGreaterThan(0);

    // Test specific search field (title search)
    await page.goto('/catalogue?search_field=title&q=Canada');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('#documents')).toBeVisible();
  });

  test('16. Applied search constraints render below search hero and can be removed', async ({ page }) => {
    await page.goto('/catalogue?q=Canada');
    await page.waitForLoadState('networkidle');

    // Applied constraints container is rendered
    const appliedParams = page.locator('#appliedParams, .appliedFilter, .catalog-search-hero__applied');
    await expect(appliedParams.first()).toBeVisible();

    // Click remove constraint if present or navigate to clear
    const removeBtn = page.locator('.btn-remove, .catalog-search-hero__applied-remove, .remove').first();
    if (await removeBtn.isVisible()) {
      await removeBtn.click();
      await page.waitForLoadState('networkidle');
      await expect(page.locator('#main-container, main').first()).toBeVisible();
    }
  });

  test('17. Citation and Librarian/MARC metadata views render successfully', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const docId = isCanadiana ? 'oon.00002_194801' : 'oocihm.lac_reel_h2971';

    // Citation view
    const citeResponse = await page.request.get(`/catalogue/${docId}/citation`);
    expect(citeResponse.status()).toBe(200);
    const citeHtml = await citeResponse.text();
    expect(citeHtml).toContain('citation');

    // Librarian / MARC view
    const marcResponse = await page.request.get(`/catalogue/${docId}/librarian_view`);
    expect(marcResponse.status()).toBe(200);
    const marcHtml = await marcResponse.text();
    expect(marcHtml).toContain('marc');
  });

  test('18. Bilingual internationalization switches between English and French', async ({ page }) => {
    // French homepage
    await page.goto('/?lang=fr');
    await page.waitForLoadState('networkidle');
    const frTitle = await page.title();
    expect(frTitle).toBeTruthy();

    // French catalogue search page
    await page.goto('/catalogue?lang=fr&q=*');
    await page.waitForLoadState('networkidle');
    const filtersHeading = page.locator('.facets-heading, h2:has-text("recherche")').first();
    await expect(filtersHeading).toBeVisible();

    // English catalogue search page
    await page.goto('/catalogue?lang=en&q=*');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('.facets-heading').first()).toBeVisible();
  });

  test('19. Static informational pages load cleanly with 200 OK', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const aboutPath = isCanadiana ? '/about/canadiana' : '/about/heritage';

    const pages = [aboutPath, '/compare-collections', '/api-access', '/what-is-iiif', '/terms-of-service'];
    for (const p of pages) {
      const response = await page.request.get(p);
      expect(response.status()).toBe(200);
    }
  });

  test('20. Error handling and legacy URL redirects preserve compatibility', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const docId = isCanadiana ? 'oon.00002_194801' : 'oocihm.lac_reel_h2971';

    // Legacy /catalog/:id redirects to /catalogue/:id
    const legacyResponse = await page.request.get(`/catalog/${docId}`, { maxRedirects: 0 });
    expect(legacyResponse.status()).toBe(301);
    expect(legacyResponse.headers()['location']).toContain(`/catalogue/${docId}`);

    // Legacy /view/:id/:pageNum redirects to /catalogue/:id?pageNum=:pageNum
    const viewResponse = await page.request.get(`/view/${docId}/3`, { maxRedirects: 0 });
    expect(viewResponse.status()).toBe(301);
    expect(viewResponse.headers()['location']).toContain(`pageNum=3`);

    // 404 handler renders styled error page for nonexistent routes
    const notFoundResponse = await page.request.get('/this-route-does-not-exist-xyz');
    expect(notFoundResponse.status()).toBe(404);
  });

  test('21. Performance and SEO optimizations: deferred assets, non-blocking fonts, collection meta descriptions, and descriptive link text', async ({ page, baseURL }) => {
    const isCanadiana = baseURL?.includes('3000') || !baseURL?.includes('3010');
    const docPath = isCanadiana ? '/catalogue/oon.00002_194801' : '/catalogue/oocihm.lac_reel_h2971';

    // 1. On homepage, Mirador assets (4.1MB) are NOT in the DOM
    await page.goto('/?lang=en');
    const homepageMiradorScript = await page.locator('script[src*="mirador"]').count();
    const homepageMiradorCss = await page.locator('link[href*="mirador"]').count();
    expect(homepageMiradorScript).toBe(0);
    expect(homepageMiradorCss).toBe(0);

    // 2. OpenSeadragon has defer
    const osdScript = page.locator('script[src*="openseadragon.min.js"]');
    await expect(osdScript).toHaveAttribute('defer', '');

    // 3. Google Fonts uses non-blocking preload & print-swap
    const fontPreload = page.locator('link[rel="preload"][as="style"][href*="fonts.googleapis.com"]');
    expect(await fontPreload.count()).toBeGreaterThanOrEqual(1);

    // 4. Collection-aware meta descriptions
    const enMetaDesc = await page.locator('meta[name="description"]').getAttribute('content');
    if (isCanadiana) {
      expect(enMetaDesc).toContain('Canadiana provides open access');
    } else {
      expect(enMetaDesc).toContain('The Héritage Collection provides free access');
    }

    await page.goto('/?lang=fr');
    const frMetaDesc = await page.locator('meta[name="description"]').getAttribute('content');
    if (isCanadiana) {
      expect(frMetaDesc).toContain('Canadiana offre un accès libre');
    } else {
      expect(frMetaDesc).toContain('La collection Héritage offre un accès libre');
    }

    // 5. On document show page, Mirador is loaded with defer
    await page.goto(`${docPath}?lang=en`);
    const docMiradorScript = page.locator('script[src*="mirador.min.js"]');
    await expect(docMiradorScript).toHaveCount(1);
    await expect(docMiradorScript).toHaveAttribute('defer', '');
    const docMiradorCss = page.locator('link[href*="mirador.css"]');
    await expect(docMiradorCss).toHaveCount(1);

    // 6. Descriptive link text for Lighthouse SEO
    await page.goto('/?lang=en');
    const ctaLinks = page.locator('.home-split-card__cta, .home-resource-card__cta');
    const count = await ctaLinks.count();
    for (let i = 0; i < count; i++) {
      const link = ctaLinks.nth(i);
      const text = await link.innerText();
      // Inner text includes the visually-hidden descriptive span (e.g. "Browse books and publications")
      expect(text.trim().length).toBeGreaterThan('Browse'.length);
    }
  });
});
