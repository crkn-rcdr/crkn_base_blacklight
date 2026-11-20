import { test, expect } from '@playwright/test';

/**
 * End-to-End Test: OpenSeadragon Navigation Image Requests
 *
 * Ensures neither Mirador's OpenSeadragon viewer nor the Stimulus
 * openseadragon-preview controller requests legacy /assets/*_*.png
 * button sprites (e.g. /assets/flip_rest.png, /assets/rotateleft_hover.png)
 * that trigger Rails 404 storms. Button icons are rendered via CSS
 * Bootstrap Icons ::before pseudo-elements with inline 1x1 transparent
 * GIF data URIs.
 */

const OSD_PNG_PATTERN = /\/assets\/[^/?#]+_(rest|hover|pressed|grouphover)\.png/i;

test.describe('OpenSeadragon Zero-Sprite-Request E2E', () => {
  test('Item page Mirador viewer mounts OSD controls without requesting /assets/*_*.png', async ({ page, baseURL }) => {
    const isHeritage = baseURL?.includes('3010') || baseURL?.includes('heritage');
    const docPath = isHeritage
      ? '/catalogue/oocihm.lac_reel_h2971'
      : '/catalogue/oon.00002_194801';

    const osdPngRequests: string[] = [];
    const assetPng404s: string[] = [];

    page.on('request', (req) => {
      if (OSD_PNG_PATTERN.test(req.url())) {
        osdPngRequests.push(req.url());
      }
    });

    page.on('response', (res) => {
      if (res.status() === 404 && /\/assets\/.*\.png/i.test(res.url())) {
        assetPng404s.push(res.url());
      }
    });

    await page.goto(docPath, { waitUntil: 'domcontentloaded' });

    // Wait for Mirador and its OpenSeadragon container + controls to mount
    const osdContainer = page.locator('#my-mirador .openseadragon-container').first();
    await expect(osdContainer).toBeVisible({ timeout: 20000 });

    const zoomInBtn = osdContainer.locator('div[title="Zoom in"]').first();
    const rotateLeftBtn = osdContainer.locator('div[title="Rotate left"]').first();
    await expect(zoomInBtn).toBeVisible({ timeout: 15000 });
    await expect(rotateLeftBtn).toBeVisible({ timeout: 15000 });

    // Hover and press a control to trigger OSD hover/pressed image state transitions
    await rotateLeftBtn.hover();
    await zoomInBtn.hover();

    // Verify OSD control <img> elements use inline data URIs instead of /assets/ URLs
    const controlImgSrcs = await osdContainer.locator('div[title] img').evaluateAll((imgs) =>
      imgs.map((img) => img.getAttribute('src') || '')
    );
    expect(controlImgSrcs.length).toBeGreaterThan(0);
    for (const src of controlImgSrcs) {
      expect(src).toMatch(/^data:image\/gif;base64,/);
    }

    // Confirm zero legacy /assets/*_*.png requests and zero /assets/*.png 404s
    expect(osdPngRequests).toEqual([]);
    expect(assetPng404s).toEqual([]);
  });

  test('Homepage OpenSeadragon preview cards do not request /assets/*_*.png', async ({ page }) => {
    const osdPngRequests: string[] = [];
    const assetPng404s: string[] = [];

    page.on('request', (req) => {
      if (OSD_PNG_PATTERN.test(req.url())) {
        osdPngRequests.push(req.url());
      }
    });

    page.on('response', (res) => {
      if (res.status() === 404 && /\/assets\/.*\.png/i.test(res.url())) {
        assetPng404s.push(res.url());
      }
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(3000);

    expect(osdPngRequests).toEqual([]);
    expect(assetPng404s).toEqual([]);
  });
});
