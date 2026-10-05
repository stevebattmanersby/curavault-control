'use strict';
const assert = require('node:assert/strict');
const { allowed, PRODUCTION, claims } = require('./config.cjs');
const { classify } = require('./contracts.cjs');
const { totp } = require('./totp.cjs');
const { security } = require('./security.cjs');
const { observeLogout, verifyRevocation } = require('./logout.cjs');
const { loadLogin } = require('./bootstrap.cjs');
function playwright() {
  return process.env.PLAYWRIGHT_MODULE_PATH ? require(process.env.PLAYWRIGHT_MODULE_PATH) : require('playwright');
}
async function browserScenario(browser, api, fixture, evidence) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, serviceWorkers: 'block' });
  const pending = []; const successful = new Set();
  let closing = false;
  let session; let telemetryWrites = 0; const scenario = fixture.scenario;
  const origin = 'http://127.0.0.1:4178';
  const step = name => { fixture.step = name; };
  await context.route('**/*', async route => {
    const url = route.request().url();
    if (url.includes(PRODUCTION)) evidence.productionRequestAttempts++;
    if (!allowed(url, origin)) {
      evidence.blockedRequests++; evidence.networkFailures.push({ scenario, endpoint: 'blocked-external-target', expected: false, category: 'A' });
      return route.abort('blockedbyclient');
    }
    if (new URL(url).origin === origin) return route.continue();
    if (new URL(url).origin === 'https://fonts.gstatic.com') {
      const headers = route.request().headers();
      if (route.request().method() !== 'GET' || headers.authorization || headers.apikey) {
        evidence.blockedRequests++; return route.abort('blockedbyclient');
      }
    }
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
    const local = url.origin === origin;
    const safePath = local && /^\/[a-zA-Z0-9_./-]*$/.test(url.pathname) ? url.pathname : undefined;
    const failure = request.failure()?.errorText;
    evidence.networkFailures.push({ scenario, endpoint: local ? 'local-resource' : url.pathname.replace(/[0-9a-f-]{36}/g, ':id'),
      ...(safePath ? { resourceUrl: origin + safePath } : {}), resourceType: request.resourceType(),
      phase: closing ? 'context-close' : fixture.step,
      failureCode: /^net::[A-Z_]+$/.test(failure || '') ? failure : 'unknown',
      status: 0, category: 'A', expected: false, reason: 'Transport failure' });
  });
  page.on('response', response => {
    pending.push((async () => {
      const url = new URL(response.url());
      if (url.origin === origin) return;
      const pathname = url.pathname;
      if (response.status() < 400) {
        successful.add(pathname);
        if (pathname === '/rest/v1/usage_events' && response.request().method() === 'POST') {
          const payload = response.request().postDataJSON();
          assert.equal(payload.user_id, fixture.id);
          assert.equal(payload.owner_user_id, fixture.id);
          assert.ok(payload.event_key && payload.event_type);
          assert.ok(Object.keys(payload).every(key => ['user_id', 'owner_user_id', 'event_key', 'event_type', 'success', 'failure_code', 'properties'].includes(key)));
          telemetryWrites++;
        }
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
    step('login');
    await loadLogin(page, origin);
    await page.locator('flt-semantics-placeholder').evaluate(element => element.click());
    await type(page, 'Email', fixture.email); await type(page, 'Password', fixture.password);
    let logoutResponse = !fixture.active ? observeLogout(page, api.config.url) : null;
    await page.getByRole('button', { name: 'Sign in', exact: true }).click();
    if (!fixture.active) {
      step('denial-message');
      await page.locator('[flt-semantics-identifier="control-login-error"]').waitFor();
      const label = await semanticText(page.locator('[flt-semantics-identifier="control-login-error"]'));
      assert.ok(/Access denied|inactive|not allow-listed/i.test(label || ''), 'Explicit denial missing');
      assert.ok(page.url().endsWith('/login'));
      await page.goto(origin + '/#/dashboard');
      await page.waitForURL('**/#/login');
      // Verify ordinary/inactive reporting denial with the captured pre-revocation JWT.
      await Promise.all(pending);
      step('denied-session-backend-and-refresh');
      assert.ok(session, 'Denied sign-in session not captured');
      const denial = await api.request('/rest/v1/rpc/admin_get_dashboard_metrics', { method: 'POST', body: {}, token: session.access_token });
      security(denial.status === 403 && denial.data?.code === '42501', 'Non-admin reporting denial changed');
      await verifyRevocation(logoutResponse, api, session.refresh_token);
      return;
    }
    await page.waitForURL('**/#/mfa');
    step('totp-enrollment');
    const enrollmentResponse = page.waitForResponse(response => new URL(response.url()).pathname === '/auth/v1/factors' && response.request().method() === 'POST' && response.status() === 200).catch(() => null);
    await page.getByRole('button', { name: 'Start setup', exact: true }).click();
    const response = await enrollmentResponse; assert.ok(response, 'Enrollment response missing');
    const enrollment = await response.json();
    step('aal2-upgrade');
    const metricsResponse = page.waitForResponse(response => new URL(response.url()).pathname === '/rest/v1/rpc/admin_get_dashboard_metrics' && response.status() === 200).catch(() => null);
    await type(page, '6-digit code', totp(enrollment.totp.secret));
    await page.getByRole('button', { name: 'Verify and continue', exact: true }).click();
    await page.waitForURL('**/#/dashboard');
    step('reporting-rpc-and-ui');
    const metricsReply = await metricsResponse; assert.ok(metricsReply, 'Reporting response missing');
    const raw = await metricsReply.json();
    const metrics = Array.isArray(raw) ? raw[0] : raw;
    assert.ok(Number.isInteger(metrics.total_admin_users) && metrics.total_admin_users >= 6);
    const status = page.locator('[flt-semantics-identifier="control-dashboard-status"]');
    await status.waitFor({ state: 'attached' });
    assert.ok((await semanticText(status)).includes('Dashboard metrics loaded: Yes'), 'UI reporting status did not confirm loaded data');
    await Promise.all(pending);
    assert.ok(telemetryWrites > 0, 'Canonical telemetry did not persist');
    const upgraded = claims(session.access_token);
    security(upgraded.aal === 'aal2' && upgraded.role === 'authenticated' && upgraded.sub === fixture.id, 'Browser AAL2 fixture claims mismatch');
    // Known v2 probes are acceptable only when their documented V1 fallback succeeds.
    for (const [probe, fallback] of [['admin_get_ai_usage_summary_v2', 'admin_get_ai_usage_summary'], ['admin_get_storage_summary_v2', 'admin_get_storage_summary']]) {
      if (evidence.networkFailures.some(failure => failure.scenario === scenario && failure.endpoint.endsWith('/' + probe)))
        assert.ok(successful.has('/rest/v1/rpc/' + fallback), 'V1 fallback did not succeed');
    }
    step('settings-rbac');
    logoutResponse = observeLogout(page, api.config.url);
    await page.goto(origin + '/#/settings');
    await semantics(page);
    if (fixture.role !== 'owner') {
      await page.waitForURL('**/#/unauthorized');
      await page.getByText('Access denied', { exact: true }).waitFor();
      if (fixture.role === 'read_only') {
      step('readonly-backend-mutation-denial');
      const update = await api.request(`/rest/v1/admin_users?admin_user_id=eq.${fixture.id}`, { method: 'PATCH', token: session.access_token,
        prefer: 'return=representation', body: { role: 'owner' } });
      security(update.status === 200 && Array.isArray(update.data) && update.data.length === 0, 'read_only mutation denial changed');
      const unchanged = await api.ok(`/rest/v1/admin_users?admin_user_id=eq.${fixture.id}&select=role`, { admin: true });
      security(unchanged[0].role === 'read_only', 'read_only fixture role changed');
      const audit = await api.request('/rest/v1/admin_audit_log', { method: 'POST', token: session.access_token,
        body: { admin_user_id: fixture.id, admin_email: fixture.email, action_type: 'control_e2e_denied', result: 'success' } });
      security(audit.status === 403 && audit.data?.code === '42501', 'read_only audit INSERT denial changed');
      }
      step('ui-logout');
      await page.getByRole('button', { name: 'Logout', exact: true }).click();
    } else {
      await page.waitForURL('**/#/settings');
      step('ui-logout');
      const logout = page.locator('[flt-semantics-identifier="control-logout"]');
      await logout.waitFor({ state: 'attached' });
      // Dispatch the accessible DOM action; Flutter's canvas overlay can intercept
      // synthesized pointer clicks even when the semantics action is available.
      await logout.evaluate(element => element.click());
    }
    step('logout-route');
    await page.waitForURL('**/#/login');
    step('logout-refresh-replay-and-route-denial');
    await verifyRevocation(logoutResponse, api, session.refresh_token);
    await page.goto(origin + '/#/dashboard'); await page.waitForURL('**/#/login');
    // No MFA, credentials, traces, HAR, raw response bodies or console strings are saved.
  } finally {
    await Promise.all(pending);
    closing = true;
    await context.close();
  }
}
async function type(page, name, value) {
  const input = page.getByRole('textbox', { name, exact: true });
  await input.click(); await input.pressSequentially(value); await input.press('Tab');
}
async function semantics(page) {
  await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder') || document.querySelector('flt-semantics[role="button"]'));
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
}
async function semanticText(locator) {
  // Flutter renders text semantics as DOM text and interactive labels as ARIA.
  return `${await locator.getAttribute('aria-label') || ''} ${await locator.textContent() || ''}`.trim();
}
module.exports = { browserScenario, playwright };
