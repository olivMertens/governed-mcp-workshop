// Runs a reviewed validator or read-only CLI query and renders its masked output.
// Usage (from the repository root, after `npm ci --prefix tools/capture`):
//   node tools/capture/capture-terminal.mjs [--only <file>]   run every shot in terminal-shots.json
// Each run prints the masked output, so the guide's "Real result" box can quote exactly what the image shows.
import { spawnSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { chromium } from 'playwright-core';
import { PINK, applyRules, findLeaks, loadContext, maskRules, repoRoot } from './mask.mjs';

const { values } = parseArgs({ options: { only: { type: 'string', multiple: true } } });
const context = loadContext();
const rules = maskRules(context);
const { participant, account } = context;
const stem = `mcp-${participant.participant_prefix}-${participant.resource_suffix}`;
const names = {
  subscriptionId: account.id,
  tenantId: account.tenantId,
  resourceGroup: participant.existing_resource_group_name || `rg-${stem}`,
  functionApp: participant.resource_suffix.length === 10 ? `func-${stem}` :
    `func-mcp-${participant.participant_prefix.slice(0, 6)}-${participant.resource_suffix}`,
  gateway: `apim-${stem}`,
  applicationInsights: `appi-${stem}`,
  oboIdentity: `id-${stem}-obo`,
  reportIdentity: `id-${stem}-report`,
  workshopTag: stem,
};
const fill = (text) => text
  .replace(/\{(tenantId|subscriptionId|resourceGroup|functionApp|gateway|applicationInsights|oboIdentity|reportIdentity|workshopTag)\}/g,
    (_, name) => names[name]);
const html = (text) => text.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function lineClass(line) {
  if (/^PASS\b/.test(line)) return 'pass';
  if (/^FAIL\b/.test(line)) return 'fail';
  if (/^(INFO|WARN)\b/.test(line)) return 'info';
  if (/^== /.test(line)) return 'step';
  if (/^\s+Why:/.test(line)) return 'why';
  return '';
}

function render(shot, lines) {
  const groups = (shot.highlights ?? []).map((highlight, index) => {
    const pattern = new RegExp(highlight.match);
    const hits = lines.map((line, i) => (pattern.test(line.text) ? i : -1)).filter((i) => i >= 0);
    if (!hits.length) throw new Error(`Highlight ${index + 1} matched no line: ${highlight.match}`);
    return { n: index + 1, first: Math.min(...hits), last: Math.max(...hits) };
  });
  const body = lines.map((line) => {
    const text = html(line.text) || '&nbsp;';
    const marked = /^(PASS|FAIL)\b/.test(line.text) ? text.replace(/^(PASS|FAIL)/, (word) => `<b class="k ${word.toLowerCase()}">${word}</b>`) : text;
    return `<div class="line ${line.kind}">${marked}</div>`;
  }).join('');
  return {
    groups,
    html: `<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:transparent}
    .term{width:1200px;background:#0C0C0C;border-radius:10px;overflow:hidden;font:14px/22px "Cascadia Mono",Consolas,monospace;color:#CCCCCC}
    .bar{height:36px;background:#202020;display:flex;align-items:center;gap:8px;padding:0 14px;color:#DDD;font:13px "Segoe UI",sans-serif}
    .dot{width:12px;height:12px;border-radius:50%} .bar span.t{margin-left:14px}
    .out{position:relative;padding:14px 22px 18px}
    .line{white-space:pre-wrap;word-break:break-word;min-height:22px}
    .cmd{color:#F9F1A5} .k{font-weight:700} .k.pass{color:#16C60C} .k.fail{color:#E74856}
    .step{color:#61D6D6;font-weight:700} .why{color:#8A8A8A;font-style:italic} .info{color:#B4B4B4}
    .title{color:#FFFFFF;font-weight:700}
    .box{position:absolute;left:12px;right:12px;border:3px solid ${PINK};border-radius:8px;box-sizing:border-box;pointer-events:none}
    .box b{position:absolute;right:-15px;top:-15px;width:26px;height:26px;border-radius:50%;background:${PINK};color:#fff;border:2px solid #fff;font:700 14px "Segoe UI",sans-serif;display:flex;align-items:center;justify-content:center}
  </style><div class="term"><div class="bar"><i class="dot" style="background:#FF5F57"></i><i class="dot" style="background:#FEBC2E"></i><i class="dot" style="background:#28C840"></i><span class="t">${html(shot.title)}</span></div><div class="out">${body}</div></div>`,
  };
}

// Frames are measured on the rendered lines, so a long line that wraps stays inside its frame.
async function drawFrames(page, groups) {
  await page.evaluate((list) => {
    const out = document.querySelector('.out');
    const rows = [...out.querySelectorAll('.line')];
    for (const group of list) {
      const top = rows[group.first].offsetTop - 2;
      const bottom = rows[group.last].offsetTop + rows[group.last].offsetHeight + 2;
      const box = document.createElement('span');
      box.className = 'box';
      box.style.top = `${top}px`;
      box.style.height = `${bottom - top}px`;
      box.innerHTML = `<b>${group.n}</b>`;
      out.append(box);
    }
  }, groups);
}

const shots = JSON.parse(await readFile(new URL('./terminal-shots.json', import.meta.url), 'utf8'));
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const page = await browser.newPage({ viewport: { width: 1240, height: 400 }, deviceScaleFactor: 1 });
let failures = 0;
for (const shot of shots.filter((item) => !values.only || values.only.includes(item.file))) {
  try {
    const result = spawnSync(shot.run.command, shot.run.args.map(fill), {
      cwd: repoRoot, encoding: 'utf8', env: { ...process.env, NO_COLOR: '1', ...(shot.run.env ?? {}) }, timeout: (shot.run.timeoutSeconds ?? 600) * 1000,
    });
    if (result.error) throw result.error;
    let output = applyRules(`${result.stdout ?? ''}${result.stderr ?? ''}`, rules).replace(/\x1b\[[0-9;]*m/g, '').replace(/\r/g, '');
    let outLines = output.split('\n').filter((line, i, all) => line.trim() || (i > 0 && all[i - 1].trim()));
    // PowerShell wraps redirected output at the console width: rejoin continuation lines to their check line.
    if (!shot.preserveLines) outLines = outLines.reduce((joined, line) => {
      const previous = joined.at(-1);
      if (previous?.trim() && line.trim() && !/^(PASS|FAIL|INFO|WARN|==|\s+Why:|Module \d\d validator)/.test(line)) {
        joined[joined.length - 1] = `${previous}${previous.endsWith(' ') ? '' : ' '}${line.trimStart()}`;
      } else joined.push(line);
      return joined;
    }, []);
    if (shot.keep) outLines = outLines.filter((line) => new RegExp(shot.keep).test(line));
    if (shot.expectExit !== undefined && result.status !== shot.expectExit) {
      throw new Error(`exit code ${result.status}, expected ${shot.expectExit}. Output:\n${outLines.join('\n')}`);
    }
    for (const pattern of shot.requireOutput ?? []) {
      if (!new RegExp(pattern).test(output)) throw new Error(`Required result missing: ${pattern}`);
    }
    const lines = [
      ...shot.show.map((command) => ({ kind: 'cmd', text: `${shot.prompt ?? 'PS C:\\workshop-mcp>'} ${command}` })),
      ...outLines.map((text) => ({ kind: /^Module \d\d validator/.test(text) ? 'title' : lineClass(text), text })),
    ];
    const leaks = findLeaks(lines.map((line) => line.text).join('\n'), context);
    if (leaks.length) throw new Error(`Masking incomplete: ${leaks.join(', ')}`);
    const rendered = render(shot, lines);
    await page.setContent(rendered.html);
    await drawFrames(page, rendered.groups);
    await page.locator('.term').screenshot({ path: join(repoRoot, 'assets', 'screenshots', shot.file), omitBackground: true });
    console.log(`PASS ${shot.file}\n----- masked output -----\n${outLines.join('\n')}\n-------------------------`);
  } catch (error) {
    failures++;
    console.log(`FAIL ${shot.file}: ${error instanceof Error ? applyRules(error.message, rules) : 'unknown error'}`);
  }
}
await browser.close();
if (failures) process.exitCode = 1;
