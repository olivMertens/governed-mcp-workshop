// Keeps one signed-in Edge window open for capture-portal.mjs --cdp http://127.0.0.1:9333, so you sign in only once.
// Usage: node tools/capture/browser.mjs   (leave it running; press Ctrl+C or close the window when done)
import { join } from 'node:path';
import { chromium } from 'playwright-core';
import { repoRoot } from './mask.mjs';

const browser = await chromium.launchPersistentContext(join(repoRoot, '.workshop', 'capture-profile'), {
  channel: 'msedge', headless: false, viewport: null, colorScheme: 'dark', locale: 'en-US',
  // Loopback only: the debugging endpoint is not reachable from the network.
  args: ['--remote-debugging-port=9333', '--remote-debugging-address=127.0.0.1', '--window-size=1460,980'],
});
const page = browser.pages()[0] ?? await browser.newPage();
await page.goto('https://portal.azure.com/');
console.log('Sign in to your TEST tenant in this window and keep it open. Captures connect with --cdp http://127.0.0.1:9333');
await new Promise((resolve) => browser.on('close', resolve));
