// Builds masking rules from the operator's private context at run time. Nothing private is written to the repository.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const PINK = '#EC407A';
const ZERO_GUID = '00000000-0000-0000-0000-000000000000';
const GUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const PSEUDONYMS = ['contoso', 'contoso.onmicrosoft.com', 'p01', '<suffix>', 'workshop test subscription'];

export function az(args) {
  // az is az.cmd on Windows, which needs a shell; callers pass fixed literals and resource names only.
  const output = execFileSync('az', [...args, '-o', 'json', '--only-show-errors'],
    { encoding: 'utf8', shell: process.platform === 'win32', maxBuffer: 16 * 1024 * 1024 });
  return output.trim() ? JSON.parse(output) : null;
}

export function loadContext() {
  const account = az(['account', 'show']);
  const organization = az(['rest', '--method', 'GET', '--url', 'https://graph.microsoft.com/v1.0/organization'])?.value?.[0] ?? {};
  const participant = JSON.parse(readFileSync(join(repoRoot, '.workshop', 'participant.tfvars.json'), 'utf8'));
  return {
    account,
    participant,
    tenantName: organization.displayName,
    domains: (organization.verifiedDomains ?? []).map((domain) => domain.name),
  };
}

/** Returns [source, flags, replacement] triples, most specific first, serializable into the browser. */
export function maskRules(context) {
  const { account, participant } = context;
  const rules = [];
  const literal = (value, replacement) => {
    // Never rewrite a value that is already a pseudonym (a sandbox tenant may really be named Contoso).
    if (typeof value === 'string' && value.length >= 4 && !PSEUDONYMS.includes(value.toLowerCase())) {
      rules.push([escape(value), 'gi', replacement]);
    }
  };
  const prefix = participant.participant_prefix;
  const suffix = participant.resource_suffix;
  literal(account.user?.name, 'admin@contoso.onmicrosoft.com');
  for (const domain of context.domains) literal(domain, 'contoso.onmicrosoft.com');
  literal(account.name, 'Workshop test subscription');
  literal(context.tenantName, 'CONTOSO');
  if (prefix && suffix) {
    literal(`${prefix}-${suffix}`, 'p01-<suffix>');
    literal(`${prefix.slice(0, 6)}${suffix}`, 'p01<suffix>');
    literal(`${prefix.slice(0, 6)}-${suffix}`, 'p01-<suffix>');
    literal(suffix, '<suffix>');
    if (prefix !== 'p01') rules.push([`\\b${escape(prefix)}\\b`, 'g', 'p01']);
  }
  // Safety nets: any remaining tenant domain, then every GUID (tenant, subscription, object and client IDs).
  rules.push(['[a-z0-9-]+\\.onmicrosoft\\.com', 'gi', 'contoso.onmicrosoft.com']);
  rules.push([GUID.source, 'gi', ZERO_GUID]);
  rules.push(['\\b[0-9a-f]{32}\\b', 'gi', '0'.repeat(32)]);
  return rules;
}

export function applyRules(text, rules) {
  return rules.reduce((value, [source, flags, replacement]) => value.replace(new RegExp(source, flags), replacement), text);
}

/** Values that must never appear in a published capture, checked after masking. */
export function findLeaks(text, context) {
  const { account, participant } = context;
  const values = [account.user?.name, account.name, context.tenantName, ...context.domains, account.tenantId, account.id,
    participant.resource_suffix, participant.participant_prefix === 'p01' ? null : participant.participant_prefix];
  const lower = text.toLowerCase();
  // A value that is itself one of the pseudonyms (for example a sandbox tenant already named Contoso) is not private.
  const leaks = values.filter((value) => typeof value === 'string' && value.length >= 4 &&
    !PSEUDONYMS.includes(value.toLowerCase()) && lower.includes(value.toLowerCase()));
  if ((text.match(GUID) ?? []).some((guid) => guid !== ZERO_GUID)) leaks.push('a non-zero GUID');
  // Report the kind of leak only, never the private value itself.
  return leaks.map((value) => (value === 'a non-zero GUID' ? value : `a private value (${value.length} characters)`));
}
