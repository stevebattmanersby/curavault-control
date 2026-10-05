'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { loadLogin } = require('../bootstrap.cjs');
test('login bootstrap waits for complete manifest transfer and bounded network readiness', async () => {
  let finish; let ready = false;
  const response = { url: () => 'http://127.0.0.1:4178/assets/FontManifest.json', status: () => 200,
    finished: () => new Promise(resolve => { finish = resolve; }),
    json: async () => [{ family: 'Synthetic', fonts: [{ asset: 'synthetic.ttf' }] }] };
  const page = { waitForResponse: async predicate => { assert.ok(predicate(response)); return response; },
    goto: async () => {}, waitForLoadState: async state => { assert.equal(state, 'networkidle'); ready = true; } };
  const boot = loadLogin(page, 'http://127.0.0.1:4178');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(ready, false); finish(null); await boot; assert.equal(ready, true);
});
test('aborted or malformed required font resource never grants readiness', async () => {
  for (const aborted of [true, false]) {
    let ready = false;
    const response = { status: () => 200, finished: async () => aborted ? new Error('synthetic abort') : null,
      json: async () => ({ invalid: true }) };
    const page = { waitForResponse: async () => response, goto: async () => {},
      waitForLoadState: async () => { ready = true; } };
    await assert.rejects(loadLogin(page, 'http://127.0.0.1:4178')); assert.equal(ready, false);
  }
});
