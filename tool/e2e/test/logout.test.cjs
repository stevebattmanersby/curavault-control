'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { verifyRevocation } = require('../logout.cjs');
test('refresh replay waits for server logout even when UI already signed out', async () => {
  let complete; let calls = 0;
  const logout = new Promise(resolve => { complete = resolve; });
  const check = verifyRevocation(logout, { request: async () => { calls++; return { status: 400 }; } }, 'synthetic');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls, 0);
  complete(204); await check; assert.equal(calls, 1);
});
test('failed logout never dispatches replay; accepted post-logout replay is a security stop', async () => {
  let calls = 0;
  const api = { request: async () => { calls++; return { status: 200 }; } };
  await assert.rejects(verifyRevocation(Promise.resolve(500), api, 'synthetic'));
  assert.equal(calls, 0);
  await assert.rejects(verifyRevocation(Promise.resolve(204), api, 'synthetic'), { name: 'SecurityContractFailure' });
  assert.equal(calls, 1);
});
