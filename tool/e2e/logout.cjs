'use strict';
const assert = require('node:assert/strict');
const { security } = require('./security.cjs');
function observeLogout(page, backend) {
  return page.waitForResponse(response => {
    const url = new URL(response.url());
    return url.origin === backend && url.pathname === '/auth/v1/logout' && response.request().method() === 'POST';
  }).then(response => response.status()).catch(() => null);
}
async function verifyRevocation(logout, api, refreshToken) {
  // UI signedOut notifications precede the SDK's awaited server revocation.
  assert.equal(await logout, 204, 'Server logout did not complete');
  const replay = await api.request('/auth/v1/token?grant_type=refresh_token', {
    method: 'POST', body: { refresh_token: refreshToken },
  });
  security(replay.status !== 200, 'Refresh replay accepted after confirmed logout');
  assert.equal(replay.status, 400, 'Refresh rejection response unavailable');
}
module.exports = { observeLogout, verifyRevocation };
