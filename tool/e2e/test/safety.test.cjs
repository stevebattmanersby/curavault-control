'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { config, allowed, REF, PRODUCTION } = require('../config.cjs');
const { Api } = require('../api.cjs');
const { Fixtures } = require('../fixtures.cjs');
const { classify } = require('../contracts.cjs');
const { totp } = require('../totp.cjs');
const { browserEnv } = require('../browser-env.cjs');
const jwt = (ref, role) => `header.${Buffer.from(JSON.stringify({ ref, role })).toString('base64url')}.signature`;
const env = () => ({ CONTROL_E2E_SUPABASE_URL: `https://${REF}.supabase.co`,
  CONTROL_E2E_ANON_KEY: jwt(REF, 'anon'), CONTROL_E2E_ADMIN_KEY: jwt(REF, 'service_role') });
test('browser subprocess environment excludes fixture and unrelated provider secrets', () => {
  assert.deepEqual(browserEnv({ PATH: '/trusted/bin', TEMP: '/tmp', CONTROL_E2E_ADMIN_KEY: 'fixture-secret',
    SUPABASE_SERVICE_ROLE_KEY: 'production-secret', OPENAI_API_KEY: 'provider-secret', GITHUB_TOKEN: 'write-secret' }),
  { PATH: '/trusted/bin', TEMP: '/tmp' });
});
test('configuration fails closed on missing, production, mixed or privileged browser credentials', () => {
  assert.equal(config(env()).ref, REF);
  for (const override of [ { CONTROL_E2E_SUPABASE_URL: undefined },
    { CONTROL_E2E_SUPABASE_URL: `https://${PRODUCTION}.supabase.co` },
    { CONTROL_E2E_SUPABASE_URL: `https://${REF}.supabase.co/` },
    { CONTROL_E2E_ANON_KEY: jwt(PRODUCTION, 'anon') },
    { CONTROL_E2E_ANON_KEY: jwt(REF, 'service_role') },
    { CONTROL_E2E_ADMIN_KEY: jwt(PRODUCTION, 'service_role') },
    { CONTROL_E2E_ADMIN_KEY: undefined }, { CONTROL_E2E_ANON_KEY: 'sb_publishable_unbound' } ]) {
    assert.throws(() => config({ ...env(), ...override }));
  }
});
test('network allowlist rejects production, other projects, credential URLs and encoded host tricks', () => {
  const origin = 'http://127.0.0.1:4178';
  assert.ok(allowed(`https://${REF}.supabase.co/rest/v1/admin_users`, origin));
  assert.ok(allowed(origin + '/main.dart.js', origin));
  assert.ok(allowed('https://fonts.gstatic.com/s/roboto/v32/static.woff2', origin));
  assert.equal(allowed('https://fonts.gstatic.com/s/roboto/v32/static.woff2'), false);
  for (const raw of [`https://${PRODUCTION}.supabase.co`, `https://${REF}.supabase.co.evil.example`,
    `https://user@${REF}.supabase.co`, `http://${REF}.supabase.co`, 'http://localhost:4178',
    origin + '/?override=' + PRODUCTION, 'https://other.supabase.co', 'https://fonts.googleapis.com',
    'https://fonts.gstatic.com/s/font.ttf?apikey=secret', 'https://fonts.gstatic.com/auth/v1/token'])
    assert.equal(allowed(raw, origin), false);
});
test('privileged API prevents target escape and tells transport never to follow redirects', async () => {
  let calls = 0;
  const api = new Api(config(env()), async (url, options) => {
    calls++; assert.ok(allowed(url)); assert.equal(options.redirect, 'error');
    return new Response('{}', { status: 200 });
  });
  await assert.rejects(api.request('//evil.example')); await assert.rejects(api.request('https://evil.example'));
  assert.equal(calls, 0); await api.ok('/auth/v1/admin/users', { admin: true }); assert.equal(calls, 1);
});
test('known failures are precisely classified; entitlement and telemetry defects still fail proof', () => {
  assert.equal(classify('GET', '/rest/v1/user_entitlements', 400, '42703', 'owner-ui').expected, false);
  assert.equal(classify('POST', '/rest/v1/usage_events', 400, 'PGRST204', 'owner-ui').expected, false);
  assert.equal(classify('POST', '/rest/v1/rpc/admin_get_ai_usage_summary_v2', 404, 'PGRST202', 'owner-ui').category, 'E');
  assert.equal(classify('POST', '/rest/v1/admin_audit_log', 403, '42501', 'readonly-ui').expected, true);
  assert.equal(classify('POST', '/rest/v1/admin_audit_log', 403, '42501', 'owner-ui').expected, false);
  assert.equal(classify('POST', '/rest/v1/admin_users', 403, '42501', 'readonly-ui').expected, false);
  assert.equal(classify('POST', '/rest/v1/rpc/admin_get_ai_usage_summary_v2', 404, 'other', 'owner-ui').expected, false);
});
test('TOTP matches published RFC 6238 SHA1 vector reduced to six digits', () => {
  assert.equal(totp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', 59000), '287082');
});
function fakeApi(options = {}) {
  const users = new Map(); let creates = 0; let deletes = 0;
  const api = {
    async ok(endpoint, operation = {}) {
      if (endpoint === '/auth/v1/admin/users' && operation.method === 'POST') {
        const user = { id: crypto.randomUUID(), email: operation.body.email, user_metadata: operation.body.user_metadata };
        users.set(user.id, user); creates++;
        if (options.loseCreateResponse && creates === 2) throw new Error('Response lost');
        return user;
      }
      if (endpoint.startsWith('/auth/v1/admin/users?')) return { users: [...users.values()] };
      if (endpoint.startsWith('/auth/v1/admin/users/') && operation.method === 'DELETE') {
        if (options.failDelete) throw new Error('Unavailable');
        users.delete(endpoint.split('/').at(-1)); deletes++; return {};
      }
      if (endpoint === '/rest/v1/admin_users' && operation.method === 'POST' && options.failAllowlist) throw new Error('Fixture role setup failure');
      if (endpoint.startsWith('/rest/v1/')) return operation.method === 'DELETE' ? null : [];
      throw new Error('Unhandled fake request');
    },
    async request(endpoint) {
      const user = users.get(endpoint.split('/').at(-1));
      return { status: user ? 200 : 404, data: user };
    },
  };
  return { api, users, get deletes() { return deletes; } };
}
async function withJournal(action) {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'control-e2e-unit-'));
  try { await action(path.join(folder, 'fixtures.json')); }
  finally { fs.rmSync(folder, { recursive: true, force: true }); }
}
test('each role/scenario gets an isolated identity; secret-free journal supports idempotent cleanup', async () => withJournal(async file => {
  const fake = fakeApi(); const fixtures = new Fixtures(fake.api, file); const users = await fixtures.create();
  assert.equal(new Set(users.map(user => user.id)).size, 7);
  assert.equal(new Set(users.map(user => user.password)).size, 7);
  for (const user of users) assert.ok(!fs.readFileSync(file, 'utf8').includes(user.password));
  await fixtures.cleanup(); assert.equal(fake.users.size, 0); assert.equal(fixtures.cleaned, 7);
  const recovery = Fixtures.load(fake.api, file); await recovery.cleanup(); assert.equal(fake.users.size, 0);
}));
test('cleanup recovers partially configured fixtures after allowlist failure', async () => withJournal(async file => {
  const fake = fakeApi({ failAllowlist: true }); const fixtures = new Fixtures(fake.api, file);
  await assert.rejects(fixtures.create()); await fixtures.cleanup(); assert.equal(fake.users.size, 0);
}));
test('intent journal recovers an Auth creation whose response was lost', async () => withJournal(async file => {
  const fake = fakeApi({ loseCreateResponse: true }); const fixtures = new Fixtures(fake.api, file);
  await assert.rejects(fixtures.create());
  assert.equal(JSON.parse(fs.readFileSync(file)).fixtures[1].id, null);
  const recovery = Fixtures.load(fake.api, file);
  await recovery.cleanup(); assert.equal(fake.users.size, 0);
  assert.equal(recovery.created, 2); assert.equal(recovery.cleaned, 2);
}));
test('cleanup outage is fatal and retains an unresolved recovery journal', async () => withJournal(async file => {
  const fake = fakeApi({ failDelete: true }); const fixtures = new Fixtures(fake.api, file); await fixtures.create();
  await assert.rejects(fixtures.cleanup(), /Cleanup failed/);
  assert.ok(JSON.parse(fs.readFileSync(file)).fixtures.some(entry => !entry.cleaned));
}));
test('forged journals cannot select arbitrary identities or production', async () => withJournal(async file => {
  const fake = fakeApi(); const fixtures = new Fixtures(fake.api, file); await fixtures.create();
  const journal = JSON.parse(fs.readFileSync(file)); journal.ref = PRODUCTION;
  fs.writeFileSync(file, JSON.stringify(journal)); assert.throws(() => Fixtures.load(fake.api, file));
  journal.ref = REF; journal.fixtures[0].email = 'real-user@example.com';
  fs.writeFileSync(file, JSON.stringify(journal)); assert.throws(() => Fixtures.load(fake.api, file));
}));
test('forged IDs cannot delete a different existing user, even when synthetic email is absent', async () => withJournal(async file => {
  const fake = fakeApi(); const fixtures = new Fixtures(fake.api, file); await fixtures.create();
  const journal = JSON.parse(fs.readFileSync(file));
  const original = journal.fixtures[0]; fake.users.delete(original.id);
  const realId = crypto.randomUUID();
  fake.users.set(realId, { id: realId, email: 'other-user@example.invalid', user_metadata: {} });
  original.id = realId; fs.writeFileSync(file, JSON.stringify(journal));
  await assert.rejects(Fixtures.load(fake.api, file).cleanup());
  assert.ok(fake.users.has(realId), 'Unrelated identity was deleted');
}));
