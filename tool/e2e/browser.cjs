'use strict';
const assert = require('node:assert/strict');
const { allowed, PRODUCTION, claims } = require('./config.cjs');
const { classify } = require('./contracts.cjs');
const { totp } = require('./totp.cjs');
function playwright() {
  return process.env.PLAYWRIGHT_MODULE_PATH ? require(process.env.PLAYWRIGHT_MODULE_PATH) : require('playwright');
}
async function browserScenario(browser, api, fixture, evidence) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
  const pending = []; const successful = new Set();
  let session; const scenario = fixture.scenario;
  const origin = 'http://127.0.0.1:4178';
  await context.route('**/*', async route => {
    const url = route.request().url();
    if (url.includes(PRODUCTION)) evidence.productionRequestAttempts++;
    if (!allowed(url, origin)) {
      evidence.blockedRequests++; evidence.networkFailures.push({ scenario, endpoint: 'blocked-external-target', expected: false, category: 'A' });
      return route.abort('blockedbyclient');
    }
    if (new URL(url).origin === origin) return route.continue();
    try {
      // Disallow redirects BEFORE following them, including redirects from an allowed host.
      const response = await route.fetch({ maxRedirects: 0, maxRetries: 0, timeout: 15000 });
      if (response.status() >= 300 && response.status() < 400) {
        evidence.networkFailures.push({ scenario, endpoint: 'backend-redirect', expected: false, category: 'A' });
        return route.abort('blockedbyclient');
      }
      await route.fulfill({ response });
    } catch { await route.abort('failed').catch(() => {}); }
  });
  await context.routeWebSocket('**/*', socket => {
    evidence.blockedRequests++;
    evidence.networkFailures.push({ scenario, endpoint: 'unexpected-websocket', expected: false, category: 'A' });
    socket.close();
  });
  const page = await context.newPage(); page.setDefaultTimeout(25000);
  page.on('pageerror', () => { evidence.pageErrors++; });
  page.on('console', message => {
    if (message.type() !== 'error' && message.type() !== 'warning') return;
    // Never persist arbitrary console text (it may contain sessions, QR or provider data).
    const text = message.text();
    const kind = /Failed to load resource/.test(text) ? 'http-resource-error' :
      /audit.*failed|audit.*denied/i.test(text) ? 'audit-error' :
      /usage_events/.test(text) ? 'telemetry-error' : 'unclassified-console';
    evidence.console.push({ scenario, level: message.type(), kind });
  });
  page.on('requestfailed', request => {
    const url = new URL(request.url());
    // Closing a context intentionally aborts pending requests; still report it.
    evidence.networkFailures.push({ scenario, endpoint: url.origin === origin ? 'local-resource' : url.pathname.replace(/[0-9a-f-]{36}/g, ':id'),
      status: 0, category: 'A', expected: false, reason: 'Transport failure' });
  });
  page.on('response', response => {
    pending.push((async () => {
      const url = new URL(response.url());
      if (url.origin === origin) return;
      const pathname = url.pathname;
      if (response.status() < 400) {
        successful.add(pathname);
        if (pathname === '/auth/v1/token' || /\/verify$/.test(pathname)) {
          const data = await response.json();
          if (data.access_token) session = data;
        }
        return;
      }
      let code;
      try { code = (await response.json()).code; } catch { /* no raw body */ }
      evidence.networkFailures.push({ scenario, endpoint: pathname.replace(/[0-9a-f-]{36}/g, ':id'), method: response.request().method(),
        status: response.status(), code, ...classify(response.request().method(), pathname, response.status(), code, scenario) });
    })().catch(() => { evidence.pageErrors++; }));
  });
  try {
    await page.goto(origin + '/#/login');
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await type(page, 'Email', fixture.email); await type(page, 'Password', fixture.password);
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    if (!fixture.active) {
      await page.locator('[flt-semantics-identifier="control-login-error"]').waitFor();
      const label = await page.locator('[flt-semantics-identifier="control-login-error"]').getAttribute('aria-label');
      assert.ok(/Access denied|inactive|not allow-listed/i.test(label || ''), 'Explicit denial missing');
      assert.ok(page.url().endsWith('/login'));
      await page.goto(origin + '/#/dashboard');
      await page.waitForURL('**/#/login');
      // Verify ordinary/inactive reporting denial with the captured pre-revocation JWT.
      await Promise.all(pending);
      assert.ok(session, 'Denied sign-in session not captured');
      const denial = await api.request('/rest/v1/rpc/admin_get_dashboard_metrics', { method: 'POST', body: {}, token: session.access_token });
      assert.equal(denial.status, 403); assert.equal(denial.data.code, '42501');
      const replay = await api.request('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh_token } });
      assert.equal(replay.status, 400, 'Denied session refresh survived sign-out');
      return;
    }
    await page.waitForURL('**/#/mfa');
    const enrollmentResponse = page.waitForResponse(response => new URL(response.url()).pathname === '/auth/v1/factors' && response.request().method() === 'POST' && response.status() === 200);
    await page.getByRole('button', { name: 'Start setup', exact: true }).click();
    const enrollment = await (await enrollmentResponse).json();
    const metricsResponse = page.waitForResponse(response => new URL(response.url()).pathname === '/rest/v1/rpc/admin_get_dashboard_metrics' && response.status() === 200);
    await type(page, '6-digit code', totp(enrollment.totp.secret));
    await page.getByRole('button', { name: 'Verify and continue', exact: true }).click();
    await page.waitForURL('**/#/dashboard');
    const raw = await (await metricsResponse).json();
    const metrics = Array.isArray(raw) ? raw[0] : raw;
    assert.ok(Number.isInteger(metrics.total_admin_users) && metrics.total_admin_users >= 6);
    await page.getByText('Dashboard metrics loaded', { exact: true }).waitFor({ state: 'attached' });
    await Promise.all(pending);
    assert.equal(claims(session.access_token).aal, 'aal2');
    // Known v2 probes are acceptable only when their documented V1 fallback succeeds.
    for (const [probe, fallback] of [['admin_get_ai_usage_summary_v2', 'admin_get_ai_usage_summary'], ['admin_get_storage_summary_v2', 'admin_get_storage_summary']]) {
      if (evidence.networkFailures.some(failure => failure.scenario === scenario && failure.endpoint.endsWith('/' + probe)))
        assert.ok(successful.has('/rest/v1/rpc/' + fallback), 'V1 fallback did not succeed');
    }
    await page.goto(origin + '/#/settings');
    if (fixture.role === 'read_only') {
      await page.waitForURL('**/#/unauthorized');
      await page.getByText('Access denied', { exact: true }).waitFor();
      const update = await api.request(`/rest/v1/admin_users?admin_user_id=eq.${fixture.id}`, { method: 'PATCH', token: session.access_token,
        prefer: 'return=representation', body: { role: 'owner' } });
      assert.equal(update.status, 200); assert.deepEqual(update.data, [], 'read_only mutation unexpectedly accepted');
      const unchanged = await api.ok(`/rest/v1/admin_users?admin_user_id=eq.${fixture.id}&select=role`, { admin: true });
      assert.equal(unchanged[0].role, 'read_only');
      await page.getByRole('button', { name: 'Logout', exact: true }).click();
    } else {
      await page.waitForURL('**/#/settings');
      await page.locator('[flt-semantics-identifier="control-logout"]').click();
    }
    await page.waitForURL('**/#/login');
    const replay = await api.request('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: session.refresh_token } });
    assert.equal(replay.status, 400, 'Logout refresh replay accepted');
    await page.goto(origin + '/#/dashboard'); await page.waitForURL('**/#/login');
    // No MFA, credentials, traces, HAR, raw response bodies or console strings are saved.
  } finally {
    await Promise.all(pending);
    await context.close();
  }
}
async function type(page, name, value) {
  const input = page.getByRole('textbox', { name, exact: true });
  await input.click(); await input.pressSequentially(value); await input.press('Tab');
}
module.exports = { browserScenario, playwright };
