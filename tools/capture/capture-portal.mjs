// Captures Azure portal pages from your own test tenant, masks private values, and frames what attendees must check.
// Usage (from the repository root, after `npm ci --prefix tools/capture`):
//   node tools/capture/capture-portal.mjs --login            sign in once (MFA) in the Edge window that opens
//   node tools/capture/capture-portal.mjs [--only <file>]    capture every shot in portal-shots.json
//   node tools/capture/capture-portal.mjs --explore <rg|function|apim|storage|app> [blade]   open a page and print its URL
import { mkdirSync } from 'node:fs';
import { readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { chromium } from 'playwright-core';
import { PINK, applyRules, az, findLeaks, loadContext, maskRules, repoRoot } from './mask.mjs';

const { values } = parseArgs({
  options: {
    login: { type: 'boolean', default: false },
    only: { type: 'string', multiple: true },
    explore: { type: 'string' },
    blade: { type: 'string', default: '' },
    menu: { type: 'string', multiple: true },
    click: { type: 'string', multiple: true },
    headless: { type: 'boolean', default: false },
    cdp: { type: 'string' },
    inputs: { type: 'boolean', default: false },
  },
});
const profile = join(repoRoot, '.workshop', 'capture-profile');
const output = join(repoRoot, 'assets', 'screenshots');
mkdirSync(profile, { recursive: true });

const context = loadContext();
const rules = maskRules(context);
// With --cdp, reuse an Edge window you keep open (started with --remote-debugging-port), so you sign in only once.
const cdp = values.cdp ? await chromium.connectOverCDP(values.cdp) : null;
const browser = cdp ? cdp.contexts()[0] : await chromium.launchPersistentContext(profile, {
  channel: 'msedge', headless: values.headless && !values.login, viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1,
  colorScheme: 'dark', locale: 'en-US',
});
const page = cdp
  ? browser.pages().find((item) => item.url().startsWith('https://portal.azure.com/')) ?? await browser.newPage()
  : browser.pages()[0] ?? await browser.newPage();
if (cdp) await page.setViewportSize({ width: 1440, height: 900 });
const portal = `https://portal.azure.com/#@${context.account.tenantId}`;

function resourceIds() {
  const { participant_prefix: prefix, resource_suffix: suffix } = context.participant;
  const group = participant_group();
  const list = az(['resource', 'list', '--resource-group', group]);
  const find = (type, start) => list.find((item) => item.type.toLowerCase() === type && item.name.startsWith(start))?.id;
  return {
    rg: `/subscriptions/${context.account.id}/resourceGroups/${group}`,
    function: find('microsoft.web/sites', 'func-mcp-'),
    app: find('microsoft.web/sites', 'web-mcp-'),
    apim: find('microsoft.apimanagement/service', `apim-mcp-${prefix}`),
    storage: find('microsoft.storage/storageaccounts', 'st'),
    suffix,
  };
  function participant_group() {
    return context.participant.existing_resource_group_name ?? `rg-mcp-${prefix}-${suffix}`;
  }
}

async function maskAllFrames() {
  for (const frame of page.frames()) {
    await frame.evaluate((list) => {
      const apply = (text) => list.reduce((value, [source, flags, replacement]) => value.replace(new RegExp(source, flags), replacement), text);
      const walker = document.createTreeWalker(document.body ?? document, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node; node = walker.nextNode()) {
        const masked = apply(node.nodeValue);
        if (masked !== node.nodeValue) node.nodeValue = masked;
      }
      for (const element of document.querySelectorAll('input, textarea')) {
        const masked = apply(element.value);
        if (masked !== element.value) element.value = masked;
      }
      for (const element of document.querySelectorAll('[title], [placeholder], [aria-label]')) {
        for (const name of ['title', 'placeholder', 'aria-label']) {
          const value = element.getAttribute(name);
          if (value && apply(value) !== value) element.setAttribute(name, apply(value));
        }
      }
    }, rules).catch(() => {});
  }
}

async function visibleText() {
  const parts = [];
  for (const frame of page.frames()) {
    parts.push(await frame.evaluate(() => {
      const values = [...document.querySelectorAll('input, textarea')].map((element) => element.value);
      return `${document.body?.innerText ?? ''}\n${values.join('\n')}`;
    }).catch(() => ''));
  }
  return parts.join('\n');
}

async function locate(target) {
  for (const frame of page.frames()) {
    const locator = target.selector ? frame.locator(target.selector)
      : target.role ? frame.getByRole(target.role, { name: target.name, exact: target.exact ?? false })
        : frame.getByText(target.text, { exact: target.exact ?? false });
    const count = await locator.count().catch(() => 0);
    for (let index = 0; index < count; index++) {
      const box = await onScreen(locator.nth(index));
      if (box) {
        if ((target.nth ?? 0) === 0) return box;
        target = { ...target, nth: target.nth - 1 };
      }
    }
  }
  throw new Error(`Highlight target not found: ${JSON.stringify(target)}`);
}

// The portal keeps earlier blades loaded off screen: only an element inside the visible window counts.
async function onScreen(locator) {
  if (!(await locator.isVisible().catch(() => false))) return null;
  const box = await locator.boundingBox().catch(() => null);
  const size = page.viewportSize() ?? { width: 1440, height: 900 };
  return box && box.width > 0 && box.height > 0 && box.x >= 0 && box.y >= 0 && box.x < size.width && box.y < size.height ? box : null;
}

async function clickTarget(target, timeoutMs = 60_000) {
  const end = Date.now() + timeoutMs;
  for (;;) {
    for (const frame of page.frames()) {
      const locator = frame.getByText(target.text, { exact: target.exact ?? false });
      const count = await locator.count().catch(() => 0);
      for (let index = 0; index < count; index++) {
        if (await onScreen(locator.nth(index))) {
          // A DOM click: mouse events do not always reach the portal's cross-origin blade frames over CDP.
          await locator.nth(index).evaluate((element) => element.click());
          return;
        }
      }
    }
    if (Date.now() > end) throw new Error(`Click target not found: ${JSON.stringify(target)}`);
    await page.waitForTimeout(2_000);
  }
}

async function waitLocate(target, timeoutMs = 60_000) {
  const end = Date.now() + timeoutMs;
  for (;;) {
    try { return await locate(target); }
    catch (error) {
      if (Date.now() > end) throw error;
      await page.waitForTimeout(2_000);
    }
  }
}

async function frameBoxes(highlights) {
  const boxes = [];
  for (const [index, highlight] of highlights.entries()) {
    const found = [];
    for (const target of highlight.targets) found.push(await waitLocate(target, 20_000));
    const pad = highlight.pad ?? 6;
    const left = Math.min(...found.map((box) => box.x)) - pad;
    const top = Math.min(...found.map((box) => box.y)) - pad;
    const right = Math.max(...found.map((box) => box.x + box.width)) + pad + (highlight.extendRight ?? 0);
    const bottom = Math.max(...found.map((box) => box.y + box.height)) + pad;
    boxes.push({ n: highlight.number ?? index + 1, x: left, y: top, w: right - left, h: bottom - top });
  }
  await page.evaluate(({ list, color }) => {
    document.querySelectorAll('.capture-frame').forEach((element) => element.remove());
    for (const box of list) {
      const frame = document.createElement('div');
      frame.className = 'capture-frame';
      Object.assign(frame.style, {
        position: 'fixed', left: `${box.x}px`, top: `${box.y}px`, width: `${box.w}px`, height: `${box.h}px`,
        border: `3px solid ${color}`, borderRadius: '8px', boxSizing: 'border-box', zIndex: 2147483647, pointerEvents: 'none',
      });
      const badge = document.createElement('div');
      badge.textContent = String(box.n);
      Object.assign(badge.style, {
        position: 'absolute', right: '-15px', top: '-15px', width: '26px', height: '26px', borderRadius: '50%',
        background: color, color: '#fff', border: '2px solid #fff', font: '700 14px "Segoe UI", sans-serif',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      });
      frame.append(badge);
      document.body.append(frame);
    }
  }, { list: boxes, color: PINK });
}

async function open(resource, blade, menu) {
  const ids = resourceIds();
  const id = ids[resource];
  if (!id) throw new Error(`No deployed resource for '${resource}'. Deploy its module first.`);
  await page.goto(`${portal}/resource${id}${blade ?? ''}`, { waitUntil: 'domcontentloaded' });
  for (const item of [].concat(menu ?? [])) {
    const visible = await waitLocate({ text: item, exact: true }, 8_000).then(() => true).catch(() => false);
    if (!visible) {
      // Long resource menus render only visible items: filter the menu with its search box, as a person would.
      let search = null;
      for (let attempt = 0; attempt < 15 && !search; attempt++) {
        for (const frame of page.frames()) {
          const candidate = frame.locator('input[aria-label="Search box"], input[placeholder="Search"]').first();
          if (await candidate.isVisible().catch(() => false)) { search = candidate; break; }
        }
        if (!search) await page.waitForTimeout(2_000);
      }
      if (!search) throw new Error('Resource menu search box not found.');
      await search.fill(item);
      await page.waitForTimeout(2_000);
    }
    await clickTarget({ text: item, exact: true }, 15_000);
    await page.waitForTimeout(4_000);
  }
}

async function ensureSignedIn() {
  await page.goto('https://portal.azure.com/', { waitUntil: 'domcontentloaded' });
  // The portal first redirects to the sign-in page; wait until the signed-in portal stays loaded.
  const signedIn = (timeout) => page.waitForFunction(() => location.host === 'portal.azure.com' && /Microsoft Azure/.test(document.title),
    null, { timeout, polling: 1_000 });
  await page.waitForTimeout(8_000);
  if (/login\.microsoftonline\.com|mysignins/.test(page.url())) {
    console.log('Sign in to your TEST tenant in the Edge window (MFA included). Answer "Yes" to "Stay signed in?" to sign in only once.');
  }
  await signedIn(600_000);
  await page.waitForTimeout(10_000);
  await signedIn(600_000);
}

await ensureSignedIn();
if (values.login) {
  console.log('PASS signed in. The session is kept in .workshop/capture-profile (git-ignored).');
} else if (values.explore) {
  // Author aid: open a page, mask it, save a local screenshot in .workshop (never in the repository).
  await open(values.explore, values.blade, values.menu);
  await page.waitForTimeout(8_000);
  await maskAllFrames();
  const debug = join(repoRoot, '.workshop', 'capture-debug');
  mkdirSync(debug, { recursive: true });
  await page.screenshot({ path: join(debug, 'explore.png') });
  console.log(`URL ${applyRules(page.url(), rules)}`);
  if (values.inputs) {
    for (const frame of page.frames()) {
      const found = await frame.evaluate(() => [...document.querySelectorAll('input')].filter((input) => input.offsetParent)
        .map((input) => `${input.placeholder || '-'} | ${input.getAttribute('aria-label') || '-'} | x=${Math.round(input.getBoundingClientRect().x)}`)).catch(() => []);
      for (const line of found) console.log(`INPUT ${applyRules(line, rules)}`);
    }
  }
  console.log(`Saved .workshop/capture-debug/explore.png; leaks after masking: ${findLeaks(await visibleText(), context).join(', ') || 'none'}`);
} else {
  const shots = JSON.parse(await readFile(new URL('./portal-shots.json', import.meta.url), 'utf8'));
  let failures = 0;
  for (const shot of shots.filter((item) => !values.only || values.only.includes(item.file))) {
    try {
      await page.setViewportSize(shot.viewport ?? { width: 1440, height: 640 });
      await open(shot.resource, shot.blade, shot.menu);
      for (const wait of [].concat(shot.waitFor ?? [])) await waitLocate(wait);
      await page.waitForTimeout(shot.settleMs ?? 3_000);
      for (const step of shot.click ?? []) {
        await clickTarget(step);
        await page.waitForTimeout(step.waitMs ?? 4_000);
      }
      await maskAllFrames();
      await frameBoxes(shot.highlights ?? []);
      await maskAllFrames();
      const before = findLeaks(await visibleText(), context);
      if (before.length) throw new Error(`Masking incomplete: ${before.join(', ')}`);
      const file = join(output, shot.file);
      await page.screenshot({ path: file, clip: shot.clip });
      const after = findLeaks(await visibleText(), context);
      if (after.length) {
        await rm(file, { force: true });
        throw new Error(`The page changed during capture: ${after.join(', ')}`);
      }
      console.log(`PASS ${shot.file}`);
    } catch (error) {
      failures++;
      console.log(`FAIL ${shot.file}: ${error instanceof Error ? applyRules(error.message, rules) : 'unknown error'}`);
      // Masked page state for the author, kept in the git-ignored .workshop folder.
      await maskAllFrames().catch(() => {});
      mkdirSync(join(repoRoot, '.workshop', 'capture-debug'), { recursive: true });
      await page.screenshot({ path: join(repoRoot, '.workshop', 'capture-debug', shot.file) }).catch(() => {});
    }
  }
  if (failures) process.exitCode = 1;
}
if (cdp) { await page.evaluate(() => document.querySelectorAll('.capture-frame').forEach((element) => element.remove())).catch(() => {}); await cdp.close(); } else await browser.close();
