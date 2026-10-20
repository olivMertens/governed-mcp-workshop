import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { applyRules, findLeaks, maskRules } from './mask.mjs';

// Synthetic context only: the real one is read at run time from az and .workshop, never stored.
const context = {
  account: { user: { name: 'olivia@fabrikamlab.onmicrosoft.com' }, name: 'Fabrikam Lab Sub', tenantId: '11111111-2222-4333-8444-555555555555', id: '66666666-7777-4888-8999-aaaaaaaaaaaa' },
  participant: { participant_prefix: 'host07', resource_suffix: '0123456789abcdef' },
  tenantName: 'Fabrikam Lab',
  domains: ['fabrikamlab.onmicrosoft.com'],
};
const rules = maskRules(context);

test('masking replaces account, tenant, subscription, names and every GUID', () => {
  const page = 'olivia@fabrikamlab.onmicrosoft.com FABRIKAM LAB (fabrikamlab.onmicrosoft.com) Fabrikam Lab Sub '
    + 'func-mcp-host07-0123456789abcdef stmcphost070123456789abcdef /subscriptions/66666666-7777-4888-8999-aaaaaaaaaaaa '
    + 'session a9d054e33d4046b6b06825bd7a735bd8';
  const masked = applyRules(page, rules);
  assert.equal(findLeaks(masked, context).length, 0, masked);
  assert.match(masked, /admin@contoso\.onmicrosoft\.com/);
  assert.match(masked, /func-mcp-p01-<suffix>/);
  assert.match(masked, /\/subscriptions\/00000000-0000-0000-0000-000000000000/);
  assert.doesNotMatch(masked, /a9d054e3/);
});

test('a leak is reported by kind, never by value', () => {
  const leaks = findLeaks('still here: fabrikamlab.onmicrosoft.com and 11111111-2222-4333-8444-555555555555', context);
  assert.ok(leaks.length >= 2);
  for (const leak of leaks) assert.doesNotMatch(leak, /fabrikam|1111/i);
});

test('a tenant already named Contoso is neither rewritten nor reported', () => {
  const contoso = { ...context, tenantName: 'Contoso' };
  const masked = applyRules('contoso-tickets-mcp', maskRules(contoso));
  assert.equal(masked, 'contoso-tickets-mcp');
  assert.equal(findLeaks('CONTOSO (contoso.onmicrosoft.com)', contoso).length, 0);
});

test('shot specs reference files that exist, and frames never target a secret value', () => {
  for (const name of ['portal-shots.json', 'terminal-shots.json']) {
    const shots = JSON.parse(readFileSync(new URL(name, import.meta.url), 'utf8'));
    for (const shot of shots) {
      assert.match(shot.file, /^(azure|terminal)-\d\d[a-z]?-[\w-]+\.png$/);
      readFileSync(new URL(`../../assets/screenshots/${shot.file}`, import.meta.url));
      assert.doesNotMatch(JSON.stringify(shot), /"Show value"[^}]*"click"|Hidden value/);
    }
  }
  assert.doesNotMatch(readFileSync(new URL('capture-portal.mjs', import.meta.url), 'utf8'), /Show value['"]\s*,\s*exact[^]*?\.click\(/);
});
