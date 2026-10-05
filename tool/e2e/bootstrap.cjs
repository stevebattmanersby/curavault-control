'use strict';
const assert = require('node:assert/strict');
async function loadLogin(page, origin) {
  const manifest = page.waitForResponse(response => response.url() === origin + '/assets/FontManifest.json')
    .catch(() => null);
  await page.goto(origin + '/#/login');
  const response = await manifest;
  assert.ok(response && response.status() === 200, 'Required font manifest response missing');
  assert.equal(await response.finished(), null, 'Font manifest transfer did not complete');
  const data = await response.json();
  assert.ok(Array.isArray(data) && data.length > 0 && data.every(family =>
    typeof family.family === 'string' && Array.isArray(family.fonts) && family.fonts.length > 0), 'Invalid font manifest');
  // Do not dispatch semantics/input actions while bootstrap resource loads remain.
  await page.waitForLoadState('networkidle');
}
module.exports = { loadLogin };
