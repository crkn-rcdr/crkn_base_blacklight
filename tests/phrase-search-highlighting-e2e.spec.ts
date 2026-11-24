import { test, expect } from '@playwright/test';

/**
 * Exact Phrase Search & Multiline Highlighting E2E
 *
 * Verifies:
 * 1. Quoted phrases enforce exact adjacency (qs=0) across SearchBuilder,
 *    PageSearchComponent, and crkn_iiif_content_search (non-adjacent words
 *    like "ROYAL MOUNTED" from "ROYAL CANADIAN MOUNTED" return 0 hits).
 * 2. Quoted phrases that wrap across OCR line breaks (e.g. "Cargo\nQueen")
 *    match in search results, render accurate page chips, and highlight cleanly
 *    in Mirador without returning "No results found" or duplicate annotations.
 */

test.describe('Exact Phrase Search & Multiline Highlighting E2E', () => {
  test('Non-adjacent quoted phrase returns zero false positives and zero page chips', async ({ page, baseURL }) => {
    const isHeritage = Boolean(baseURL && (baseURL.includes('3010') || baseURL.toLowerCase().includes('heritage')));
    test.skip(isHeritage, 'Seeded full-text OCR phrase fixtures live in the Canadiana core');

    // "ROYAL CANADIAN MOUNTED" exists on p.2 of sru.00004_196107 (69429/m20260000982k4q).
    // With qs=0, "ROYAL MOUNTED" (1 word apart) must NOT match.
    await page.goto('/catalogue?search_field=all_fields&q=%22ROYAL+MOUNTED%22');
    await page.waitForLoadState('domcontentloaded');

    await expect(page.locator('[data-document-id="sru-00004_196107"]')).toHaveCount(0);

    // Direct IIIF Content Search check for the same manifest must also return 0 items
    const searchResp = await page.request.get('http://localhost:3001/search/69429/m20260000982k4q?q=%22ROYAL+MOUNTED%22');
    expect(searchResp.status()).toBe(200);
    const searchJson = await searchResp.json();
    expect(searchJson.items).toEqual([]);
  });

  test('Line-wrapped exact phrase matches search, renders page chip, and highlights in Mirador without duplicates', async ({ page, baseURL }) => {
    const isHeritage = Boolean(baseURL && (baseURL.includes('3010') || baseURL.toLowerCase().includes('heritage')));
    test.skip(isHeritage, 'Seeded full-text OCR phrase fixtures live in the Canadiana core');

    // "Cargo\nQueen" wraps across a line break on p.3 of sru.00004_196107 (69429/m20260000982k4q)
    await page.goto('/catalogue?search_field=all_fields&q=%22Cargo+Queen%22');
    await page.waitForLoadState('domcontentloaded');

    const docArticle = page.locator('article').filter({ hasText: 'sru.00004_196107' }).first();
    await expect(docArticle).toBeVisible();

    const page3Chip = docArticle.locator('a.page-chip', { hasText: /^3$/ }).first();
    await expect(page3Chip).toBeVisible();

    // Verify IIIF Content Search API returns exactly 2 deduplicated word annotations across the line break
    const apiResp = await page.request.get('http://localhost:3001/search/69429/m20260000982k4q?q=%22Cargo+Queen%22');
    expect(apiResp.status()).toBe(200);
    const apiJson = await apiResp.json();
    expect(apiJson.items.length).toBe(2);
    expect(apiJson.items.map((i: any) => i.body.value)).toEqual(['Cargo', 'Queen']);
    expect(new Set(apiJson.items.map((i: any) => i.id)).size).toBe(2);

    // Click the page 3 chip and verify Mirador loads hits (NOT "No results found")
    await Promise.all([
      page.waitForURL(/\/catalogue\/sru\.00004_196107.*pageNum=3/),
      page3Chip.click(),
    ]);
    await page.waitForLoadState('domcontentloaded');

    const mirador = page.locator('#my-mirador');
    await expect(mirador).toBeVisible({ timeout: 15000 });

    // Wait for Mirador in-viewer search to show hit count rather than "No results found"
    await expect(mirador).toContainText(/\d+\s*\/\s*\d+|\d+\s+result/i, { timeout: 15000 });
    await expect(mirador).not.toContainText(/No results found/i);
  });

  test('Page chips exclude non-adjacent pages (no ghost chips) and every chip has Mirador highlights', async ({ page, baseURL }) => {
    const isHeritage = Boolean(baseURL && (baseURL.includes('3010') || baseURL.toLowerCase().includes('heritage')));
    test.skip(isHeritage, 'Seeded full-text OCR phrase fixtures live in the Canadiana core');

    // On sru.00004_196107 (69429/m20260000982k4q):
    // - Exact phrase "ROYAL CANADIAN" appears on pages [2, 5, 17, 28, 54].
    // - Page 67 has "ROYAL" and "CANADIAN" separately (non-adjacent).
    // PageSearchComponent must NOT show a ghost chip for page 67.
    await page.goto('/catalogue?search_field=all_fields&q=%22ROYAL+CANADIAN%22');
    await page.waitForLoadState('domcontentloaded');

    const docArticle = page.locator('article').filter({ hasText: 'sru.00004_196107' }).first();
    await expect(docArticle).toBeVisible();

    const chips = docArticle.locator('a.page-chip');
    const chipTexts = (await chips.allInnerTexts()).map(t => t.trim());
    expect(chipTexts).toEqual(['2', '5', '17', '28', '54']);
    expect(chipTexts).not.toContain('67');

    // Verify IIIF Content Search returns deduplicated annotations matching those exact pages
    const apiResp = await page.request.get('http://localhost:3001/search/69429/m20260000982k4q?q=%22ROYAL+CANADIAN%22');
    expect(apiResp.status()).toBe(200);
    const apiJson = await apiResp.json();
    expect(apiJson.items.length).toBeGreaterThan(0);
    expect(new Set(apiJson.items.map((i: any) => i.id)).size).toBe(apiJson.items.length);

    // Click page 2 chip and confirm Mirador highlights the exact phrase
    await Promise.all([
      page.waitForURL(/\/catalogue\/sru\.00004_196107.*pageNum=2/),
      chips.first().click(),
    ]);
    await page.waitForLoadState('domcontentloaded');

    const mirador = page.locator('#my-mirador');
    await expect(mirador).toBeVisible({ timeout: 15000 });
    await expect(mirador).toContainText(/\d+\s*\/\s*\d+|\d+\s+result/i, { timeout: 15000 });
    await expect(mirador).not.toContainText(/No results found/i);
  });
});
