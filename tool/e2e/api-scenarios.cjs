'use strict';
const assert = require('node:assert/strict');
const { claims } = require('./config.cjs');
const { totp } = require('./totp.cjs');
const { security } = require('./security.cjs');
async function apiScenario(api, user, upgrade) {
  let session = await api.ok('/auth/v1/token?grant_type=password', { method: 'POST', body: { email: user.email, password: user.password } });
  assert.equal(claims(session.access_token).aal, 'aal1');
  const denied = await api.request('/rest/v1/rpc/admin_get_dashboard_metrics', { method: 'POST', body: {}, token: session.access_token });
  security(denied.status === 403 && denied.data?.code === '42501', 'AAL1 reporting denial changed');
  if (upgrade) {
    const factor = await api.ok('/auth/v1/factors', { method: 'POST', token: session.access_token, body: { factor_type: 'totp', friendly_name: 'Synthetic E2E' } });
    const challenge = await api.ok(`/auth/v1/factors/${factor.id}/challenge`, { method: 'POST', token: session.access_token, body: {} });
    session = await api.ok(`/auth/v1/factors/${factor.id}/verify`, { method: 'POST', token: session.access_token, body: { challenge_id: challenge.id, code: totp(factor.totp.secret) } });
    assert.equal(claims(session.access_token).aal, 'aal2');
    const raw = await api.ok('/rest/v1/rpc/admin_get_dashboard_metrics', { method: 'POST', body: {}, token: session.access_token });
    const metrics = Array.isArray(raw) ? raw[0] : raw;
    assert.ok(Number.isInteger(metrics.total_admin_users) && metrics.total_admin_users >= 6, 'Synthetic counts absent');
  }
  await api.ok('/auth/v1/logout', { method: 'POST', token: session.access_token }, [204]);
  const replay = await api.request('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh_token } });
  security(replay.status === 400 && ['refresh_token_not_found', 'refresh_token_already_used'].includes(replay.data.error_code), 'Refresh replay denial changed');
}
module.exports = { apiScenario };
