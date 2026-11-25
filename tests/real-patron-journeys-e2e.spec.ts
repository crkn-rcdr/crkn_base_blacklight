import { test, expect } from '@playwright/test';

/**
 * End-to-End Test Suite: Real-Patron Journeys (Canadiana & Heritage)
 *
 * Models real researcher workflows observed on Canadiana and Heritage beta:
 * 1. Bilingual EN <-> FR switching mid-session while preserving search query and pageNum.
 * 2. Newspaper/Serial drill-down (Canadiana): parent serial -> issue -> in-item OCR search.
 * 3. Archival Microfilm Reel journey (Heritage): fonds -> "Reels" labels -> high-index page jump
 *    via Autocomplete + Enter -> Gallery view page selection.
 * 4. Researcher Sidebar: Cite modal (MLA/APA/Chicago with canonical ARK), Download controls,
 *    and Stable Link.
 * 5. Legacy bookmark URL redirect: /view/:id/:pageNum -> /catalogue/:id?pageNum=:pageNum.
 * 6. Non-TOC sidebar suppression on desktop and mobile viewport containment.
 */

test.describe('Real-Patron Journeys E2E', () => {
  test.beforeEach(async ({ page }) => {
    page.on('pageerror', (err) => console.log('[BROWSER ERROR]:', err.message));
  });

  test('1. Bilingual EN <-> FR switching preserves active search query and item pageNum', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const query = isHeritage ? 'Van Horne' : 'chocolate';
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oocihm.8_06959_1015';

    // Start in English with an active search
    await page.goto(`/catalogue?q=${encodeURIComponent(query)}&search_field=all_fields&lang=en`);
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('html')).toHaveAttribute('lang', /^en/i);

    // Toggle to French
    const frLink = page.locator('a[lang="fr"]').first();
    await expect(frLink).toBeVisible({ timeout: 10000 });
    await frLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Language switches to French while preserving the exact query parameter
    await expect(page.locator('html')).toHaveAttribute('lang', /^fr/i);
    const parsedUrl = new URL(page.url());
    expect(parsedUrl.searchParams.get('lang')).toBe('fr');
    expect(parsedUrl.searchParams.get('q')).toBe(query);

    // Open an item directly in French on page 5 and verify Mirador respects lang=fr & pageNum=5
    await page.goto(`/catalogue/${docId}?lang=fr&pageNum=5`);
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('html')).toHaveAttribute('lang', /^fr/i);

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    const canvasInput = viewer.locator('.mirador-canvas-nav input, .mirador-canvas-nav .MuiAutocomplete-input').first();
    await expect(canvasInput).toHaveValue('5', { timeout: 10000 });
  });

  test('2. Serial/Periodical drill-down: parent serial -> issue -> in-item search (Canadiana)', async ({ page, baseURL }) => {
    test.skip(baseURL?.includes('heritage') ?? false, 'Serial issue drill-down with OCR search is Canadiana-specific');

    await page.setViewportSize({ width: 1280, height: 800 });
    // Navigate to serial parent (Royal Canadian Mounted Police quarterly)
    await page.goto('/catalogue/sru.00004?lang=en');
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('#document')).toContainText(/Royal Canadian Mounted Police/i);

    // Click through to a child issue
    const issueLink = page.locator('a[href*="/catalogue/sru.00004_196107"]').first();
    await expect(issueLink).toBeVisible({ timeout: 10000 });
    await issueLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Mirador mounts on the issue
    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    // Perform an in-item quoted phrase search right inside the issue viewer
    const searchInput = viewer.locator('form[aria-label="Search"] input, .SearchPanelControls-form input').first();
    await expect(searchInput).toBeVisible({ timeout: 10000 });
    await searchInput.fill('"ROYAL CANADIAN"');
    await searchInput.press('Enter');

    const countLabel = viewer.locator('span.count').first();
    await expect(countLabel).toBeVisible({ timeout: 15000 });
    await expect(countLabel).toHaveText(/\d+\s*\/\s*\d+/);
  });

  test('3. Heritage archival reel journey: fonds -> reel labels -> high-index page jump -> gallery selection', async ({ page, baseURL }) => {
    test.skip(!(baseURL?.includes('heritage') ?? false), 'Heritage microfilm reel test is Heritage-specific');

    await page.setViewportSize({ width: 1280, height: 800 });

    // Open Heritage fonds parent and verify Heritage-specific "Reels" terminology
    await page.goto('/catalogue/oocihm.lac_mikan_117878?lang=en');
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('body')).toContainText(/Reels/i);

    // Navigate into reel oocihm.lac_reel_h2971 (287 canvases)
    const reelLink = page.locator('a[href*="/catalogue/oocihm.lac_reel_h2971"]').first();
    await expect(reelLink).toBeVisible({ timeout: 10000 });
    await reelLink.click();
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    // Jump to a deep canvas index (page 150) using the page index Autocomplete + Enter
    const canvasInput = viewer.locator('.mirador-canvas-nav input, .mirador-canvas-nav .MuiAutocomplete-input').first();
    await expect(canvasInput).toBeVisible({ timeout: 10000 });
    await canvasInput.click();
    await canvasInput.fill('150');
    await canvasInput.press('Enter');

    await expect(canvasInput).toHaveValue('150', { timeout: 10000 });
    expect(page.url()).toContain('pageNum=150');

    // Switch to Gallery view and choose another page
    const galleryBtn = viewer.getByRole('button', { name: /Gallery view/i }).first();
    await expect(galleryBtn).toBeVisible({ timeout: 10000 });
    await galleryBtn.click();
    await expect(viewer.locator('.openseadragon-canvas')).toBeHidden({ timeout: 5000 });

    const targetThumb = viewer.locator('[role="button"]').filter({ hasText: /Image\s+148\b/i }).first();
    await expect(targetThumb).toBeVisible({ timeout: 10000 });
    await targetThumb.click();

    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });
    await expect(canvasInput).toHaveValue('148', { timeout: 8000 });
    expect(page.url()).toContain('pageNum=148');
  });

  test('4. Researcher sidebar: Citation modal (MLA/APA/Chicago + ARK), Downloads, and Stable Link', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oocihm.8_06959_1015';

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto(`/catalogue/${docId}?lang=en`);
    await page.waitForLoadState('domcontentloaded');

    // Verify canonical ARK stable link is rendered
    const stableLink = page.locator('a[href*="n2t.net/ark:/69429/"]').first();
    await expect(stableLink).toBeVisible({ timeout: 10000 });

    // Verify Download controls exist in the About this Item sidebar
    await expect(page.getByText(/Download image/i).first()).toBeVisible({ timeout: 10000 });
    await expect(page.getByText(/Download page PDF/i).first()).toBeVisible({ timeout: 10000 });

    // Open Cite modal and confirm MLA, APA, and Chicago formats with ARK
    const citeBtn = page.locator('.sidebar-cite-btn').first();
    await expect(citeBtn).toBeVisible({ timeout: 10000 });
    await citeBtn.click();

    const dialog = page.locator('#blacklight-modal').first();
    await expect(dialog).toBeVisible({ timeout: 10000 });
    await expect(dialog).toContainText(/MLA/i);
    await expect(dialog).toContainText(/APA/i);
    await expect(dialog).toContainText(/Chicago/i);
    await expect(dialog.locator('a[href*="ark:/69429/"]').first()).toBeVisible();
  });

  test('5. Legacy bookmark /view/:id/:pageNum redirects cleanly to /catalogue/:id?pageNum=:pageNum', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oocihm.8_06959_1015';

    const response = await page.goto(`/view/${docId}/5`);
    expect(response?.status()).toBe(200);
    await page.waitForLoadState('domcontentloaded');

    expect(page.url()).toContain(`/catalogue/${docId}`);
    expect(page.url()).toContain('pageNum=5');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });
    const canvasInput = viewer.locator('.mirador-canvas-nav input, .mirador-canvas-nav .MuiAutocomplete-input').first();
    await expect(canvasInput).toHaveValue('5', { timeout: 10000 });
  });

  test('6. Non-TOC desktop sidebar suppression & mobile viewport containment', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oocihm.8_06959_1015';

    // Desktop: items without TOC should not open an empty TOC sidebar drawer
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto(`/catalogue/${docId}?lang=en`);
    await page.waitForLoadState('domcontentloaded');

    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });
    await expect(viewer.locator('.mirador-companion-area-left .MuiTreeView-root')).toHaveCount(0);

    // Mobile (375x667): viewer stays contained without hidden vertical overflow clipping controls
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto(`/catalogue/${docId}?lang=en`);
    await page.waitForLoadState('domcontentloaded');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    const overflowCheck = await viewer.evaluate((el) => ({
      scrollHeight: el.scrollHeight,
      clientHeight: el.clientHeight,
    }));
    expect(overflowCheck.scrollHeight).toBeLessThanOrEqual(overflowCheck.clientHeight + 2);
  });

  test('7. Real server-log filters: date range facet, real sorts (date-added-desc / year-asc), and facet modal', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const rangeUrl = isHeritage
      ? '/catalogue?lang=en&search_field=all_fields&range%5Bpub_date_ssim%5D%5Bbegin%5D=1850&range%5Bpub_date_ssim%5D%5Bend%5D=1950&sort=date-added-desc'
      : '/catalogue?lang=en&search_field=all_fields&range%5Bpub_date_ssim%5D%5Bbegin%5D=1900&range%5Bpub_date_ssim%5D%5Bend%5D=1990&sort=year-asc';

    const resp = await page.goto(rangeUrl);
    expect(resp?.status()).toBe(200);
    await page.waitForLoadState('domcontentloaded');
    await expect(page.locator('text=500 Internal Server Error')).not.toBeVisible();

    // Applied date range constraint pill is rendered cleanly
    await expect(page.locator('#appliedParams, .constraints-container').first()).toBeVisible({ timeout: 10000 });

    // Direct /catalogue/facet/:field modal endpoint (181 Canadiana / 77 Heritage reqs per 72h in prod logs)
    const facetField = isHeritage ? 'depositor_tsim_str' : 'subject_ssim_str';
    const facetResp = await page.request.get(`/catalogue/facet/${facetField}`);
    expect(facetResp.status()).toBe(200);
  });

  test('8. Real server-log API & page-turn flows: /catalogue.json (tx_gen) and /dl/ download refresh', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const docId = isHeritage ? 'oocihm.lac_reel_h2971' : 'oocihm.8_06959_1015';

    // 1. JSON API endpoint heavily used by researchers (/catalogue.json?search_field=tx_gen...)
    const apiUrl = isHeritage
      ? '/catalogue.json?lang=en&search_field=all_fields&q=Van+Horne&per_page=5'
      : '/catalogue.json?lang=en&search_field=tx_gen&q=%22ROYAL+CANADIAN%22&per_page=10';
    const apiResp = await page.request.get(apiUrl);
    expect(apiResp.status()).toBe(200);
    const json = await apiResp.json();
    expect(Array.isArray(json.data)).toBeTruthy();
    expect(json.data.length).toBeGreaterThan(0);

    // 2. Opening item and turning pages triggers /dl/ link refresh without 5xx errors
    const failedDlResponses: number[] = [];
    page.on('response', (res) => {
      if (res.url().includes('/dl/') && res.status() >= 500) {
        failedDlResponses.push(res.status());
      }
    });

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto(`/catalogue/${docId}?lang=en&pageNum=1`);
    await page.waitForLoadState('domcontentloaded');
    const viewer = page.locator('#my-mirador');
    await expect(viewer.locator('.openseadragon-canvas')).toBeVisible({ timeout: 15000 });

    const canvasInput = viewer.locator('.mirador-canvas-nav input, .mirador-canvas-nav .MuiAutocomplete-input').first();
    await expect(canvasInput).toBeVisible({ timeout: 10000 });
    await canvasInput.click();
    await canvasInput.fill('3');
    await canvasInput.press('Enter');
    await expect(canvasInput).toHaveValue('3', { timeout: 10000 });
    expect(failedDlResponses).toEqual([]);
  });

  test('9. Real server-log complex query shapes (multi-quoted, boolean AND, wildcard, hyphenated IDs, French accents)', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('heritage') ?? false;
    const queries = isHeritage
      ? ['"Van Horne"', 'Van AND Horne', 'Horne*', 'c-11009', 'T-17556']
      : ['"ROYAL CANADIAN" "POLICE"', 'ROYAL AND CANADIAN', 'canad*', 'Joseph Édouard Bibaud', '8_06959_1015'];

    for (const q of queries) {
      const resp = await page.goto(`/catalogue?lang=en&search_field=all_fields&q=${encodeURIComponent(q)}`);
      expect(resp?.status(), `Query "${q}" should return HTTP 200`).toBe(200);
      await expect(page.locator('text=500 Internal Server Error')).not.toBeVisible();
    }
  });

  test('10. Subject modal suggest -> apply -> reopen -> clear -> reopen never leaks query_fragment or drops modal chrome', async ({ page, baseURL }) => {
    test.skip(baseURL?.includes('heritage') ?? false, 'Subject facet modal with >10 seeded values is tested on Canadiana');

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/catalogue?lang=en&q=&search_field=all_fields');
    await page.waitForLoadState('domcontentloaded');

    const openSubjectModal = async () => {
      const subjectSection = page.locator('.blacklight-subject_ssim_str').first();
      await expect(subjectSection).toBeVisible({ timeout: 10000 });
      const toggleBtn = subjectSection.locator('button[data-bs-toggle="collapse"]').first();
      if ((await toggleBtn.count()) > 0 && (await toggleBtn.getAttribute('aria-expanded')) === 'false') {
        await toggleBtn.click();
      }
      const moreLink = subjectSection.locator('a[data-checkbox-facet-more="true"]').first();
      await expect(moreLink).toBeVisible({ timeout: 10000 });
      await moreLink.click();

      const modal = page.locator('#blacklight-modal');
      await expect(modal).toBeVisible({ timeout: 10000 });
      await expect(modal.locator('.modal-header')).toBeVisible({ timeout: 10000 });
      await expect(modal.locator('.facet-suggest')).toBeVisible({ timeout: 10000 });
      return modal;
    };

    // Step 1: Open Subject "more" modal, search for "Police", wait for facet_suggest AJAX response, check, and Apply
    const modal1 = await openSubjectModal();
    const suggestInput = modal1.locator('.facet-suggest');
    const suggestResponsePromise = page.waitForResponse(
      (res) => res.url().includes('/catalogue/facet_suggest/subject_ssim_str/Police') && res.status() === 200
    );
    await suggestInput.fill('Police');
    await suggestResponsePromise;
    await expect(modal1.locator('.facet-extended-list.facet-suggestions')).toBeVisible({ timeout: 10000 });

    const policeOption = modal1.locator('.checkbox-facet-option', { hasText: /Police -- Canada -- Periodicals/i }).first();
    await expect(policeOption).toBeVisible({ timeout: 10000 });
    await policeOption.locator('input[type="checkbox"]').check();

    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
      modal1.locator('.checkbox-facet-apply').click(),
    ]);

    // URL must contain the applied subject filter and must NOT leak query_fragment
    const appliedUrl = new URL(page.url());
    expect(appliedUrl.searchParams.has('query_fragment'), `Unexpected query_fragment in URL: ${page.url()}`).toBe(false);
    expect(appliedUrl.searchParams.getAll('f_inclusive[subject_ssim_str][]')).toContain('Police -- Canada -- Periodicals');

    // Step 2: Reopen Subject "more" modal and click Clear
    const modal2 = await openSubjectModal();
    const clearLink = modal2.locator('.checkbox-facet-clear');
    await expect(clearLink).toBeVisible({ timeout: 10000 });

    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded' }),
      clearLink.click(),
    ]);

    // URL after Clear must not contain query_fragment or the cleared subject filter
    const clearedUrl = new URL(page.url());
    expect(clearedUrl.searchParams.has('query_fragment'), `Unexpected query_fragment after Clear: ${page.url()}`).toBe(false);
    expect(clearedUrl.searchParams.getAll('f_inclusive[subject_ssim_str][]')).toEqual([]);

    // Step 3: Reopen Subject "more" modal again — must render full modal with header, suggest input, and unfiltered subjects
    const modal3 = await openSubjectModal();
    await expect(modal3.locator('.facet-suggest')).toHaveValue('');
    expect(await modal3.locator('.checkbox-facet-option').count()).toBeGreaterThan(2);
    await modal3.locator('.modal-header button.btn-close, .modal-header [data-bs-dismiss="modal"]').first().click();

    // Step 4: Even if a user lands on a stale URL with ?query_fragment=Police, opening Subject "more" still renders full modal
    await page.goto('/catalogue?lang=en&q=&query_fragment=Police&search_field=all_fields');
    await page.waitForLoadState('domcontentloaded');
    const modal4 = await openSubjectModal();
    await expect(modal4.locator('.facet-suggest')).toHaveValue('');
    expect(await modal4.locator('.checkbox-facet-option').count()).toBeGreaterThan(2);
  });
});
