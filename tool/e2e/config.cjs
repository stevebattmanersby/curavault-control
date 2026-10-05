'use strict';
const assert = require('node:assert/strict');
const REF = 'evvksortjegefsldamwb';
const PRODUCTION = 'rzqgxtizragjhenmjykq';
function claims(key) {
  try { return JSON.parse(Buffer.from(key.split('.')[1], 'base64url')); }
  catch { throw new Error('Expected a project-bound legacy JWT key'); }
}
function config(env = process.env, admin = true) {
  const url = env.CONTROL_E2E_SUPABASE_URL;
  assert.equal(url, `https://${REF}.supabase.co`, 'Only the approved disposable URL is permitted');
  const anon = env.CONTROL_E2E_ANON_KEY;
  assert.ok(anon, 'Explicit disposable anon key required');
  assert.equal(claims(anon).ref, REF, 'Anon key project mismatch');
  assert.equal(claims(anon).role, 'anon', 'Browser key must be anon');
  const adminKey = admin ? env.CONTROL_E2E_ADMIN_KEY : undefined;
  if (admin) {
    assert.ok(adminKey, 'Explicit server-only disposable fixture key required');
    assert.equal(claims(adminKey).ref, REF, 'Fixture key project mismatch');
    assert.equal(claims(adminKey).role, 'service_role', 'Fixture key role mismatch');
  }
  return { url, anon, adminKey, ref: REF };
}
function allowed(raw, origin) {
  const url = new URL(raw);
  if (raw.includes(PRODUCTION)) return false;
  if (url.username || url.password) return false;
  return (url.origin === `https://${REF}.supabase.co` && url.protocol === 'https:') ||
    (!!origin && url.origin === origin && url.protocol === 'http:' && url.hostname === '127.0.0.1');
}
module.exports = { REF, PRODUCTION, claims, config, allowed };
