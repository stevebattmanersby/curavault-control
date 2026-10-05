'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { config } = require('./config.cjs');
const { Api } = require('./api.cjs');
const { Fixtures } = require('./fixtures.cjs');
const { BUILD, ROOT, verifyBuild, sha } = require('./build.cjs');
const { serve } = require('./server.cjs');
const { browserScenario, playwright } = require('./browser.cjs');
const { apiScenario } = require('./api-scenarios.cjs');
async function main() {
  const started = Date.now(); const cfg = config(); const api = new Api(cfg);
  const folder = path.join(ROOT, 'build/control-e2e/runs', crypto.randomUUID());
  fs.mkdirSync(folder, { recursive: true });
  const journalPath = path.join(folder, 'fixtures.json');
  const evidence = { version: 1, sha: sha(), ref: cfg.ref, scenarioResults: [],
    fixtureCreationCount: 0, fixtureCleanupCount: 0, fixtureIsolation: false, cleanupVerified: false,
    console: [], pageErrors: 0, networkFailures: [], productionRequestAttempts: 0,
    productionBackendRequests: 0, blockedRequests: 0, artifacts: [], liveCIEnabled: false };
  let fixtures; let server; let browser; let interrupted = false;
  const interrupt = () => { interrupted = true; if (browser) void browser.close().catch(() => {}); };
  process.once('SIGINT', interrupt); process.once('SIGTERM', interrupt);
  const timeout = setTimeout(interrupt, 600000);
  try {
    verifyBuild(cfg);
    assert.equal(require('node:child_process').execFileSync('git', ['status', '--porcelain'], { cwd: ROOT, encoding: 'utf8' }).trim(), '', 'Commit source before durable proof');
    // Do not start a second run while any earlier cleanup journal is unresolved.
    const runs = path.dirname(folder);
    for (const dir of fs.readdirSync(runs)) {
      const file = path.join(runs, dir, 'fixtures.json');
      if (file !== journalPath && fs.existsSync(file)) {
        const previous = Fixtures.load(api, file);
        assert.ok(previous.journal.fixtures.every(entry => entry.cleaned), 'Unresolved fixture journal: recover before another run');
      }
    }
    // Verify cleanup privileges against zero matching rows before creating users.
    for (const table of ['admin_audit_log', 'admin_users']) {
      await api.ok(`/rest/v1/${table}?admin_user_id=eq.00000000-0000-0000-0000-000000000000`, { admin: true, method: 'DELETE' }, [204]);
    }
    fixtures = new Fixtures(api, journalPath); fixtures.save();
    const users = await fixtures.create();
    evidence.fixtureIsolation = new Set(users.map(user => user.id)).size === users.length;
    server = await serve(BUILD);
    const browserEnv = { ...process.env };
    delete browserEnv.CONTROL_E2E_ADMIN_KEY;
    browser = await playwright().chromium.launch({ headless: true, env: browserEnv,
      ...(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {}) });
    for (const user of users) {
      if (interrupted) throw new Error('Run interrupted or suite time limit reached');
      const time = Date.now();
      try {
        if (user.scenario.endsWith('-api')) await apiScenario(api, user, user.scenario === 'aal2-api');
        else await browserScenario(browser, api, user, evidence);
        evidence.scenarioResults.push({ scenario: user.scenario, result: 'PASS', elapsedMs: Date.now() - time });
      } catch (error) {
        // Error messages/stacks from Playwright can contain typed credentials and DOM secrets.
        evidence.scenarioResults.push({ scenario: user.scenario, result: 'FAIL', errorKind: error.name || 'Error', elapsedMs: Date.now() - time });
      }
    }
  } catch (error) { evidence.setupFailure = error.name || 'Error'; }
  finally {
    if (browser) await browser.close().catch(() => {});
    if (server) await new Promise(resolve => server.close(resolve));
    if (fixtures) {
      evidence.fixtureCreationCount = fixtures.created;
      try { await fixtures.cleanup(); evidence.cleanupVerified = true; }
      catch { evidence.cleanupFailure = 'STOP: run cleanup.cjs with the retained journal'; }
      evidence.fixtureCleanupCount = fixtures.cleaned;
    }
    clearTimeout(timeout); process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', interrupt);
    evidence.consoleErrorCount = evidence.console.filter(item => item.level === 'error').length;
    evidence.pageErrorCount = evidence.pageErrors;
    evidence.expectedNetworkFailureCount = evidence.networkFailures.filter(item => item.expected).length;
    evidence.unexpectedNetworkFailureCount = evidence.networkFailures.filter(item => !item.expected).length;
    evidence.elapsedMs = Date.now() - started;
    const scenariosPass = evidence.scenarioResults.length === 7 && evidence.scenarioResults.every(item => item.result === 'PASS');
    const unclassifiedConsole = evidence.console.some(item => item.kind === 'unclassified-console');
    evidence.result = scenariosPass && evidence.cleanupVerified && !evidence.setupFailure && evidence.productionRequestAttempts === 0 &&
      evidence.blockedRequests === 0 && evidence.pageErrors === 0 && evidence.unexpectedNetworkFailureCount === 0 && !unclassifiedConsole ? 'PASS' : 'FAIL';
    const file = path.join(folder, 'evidence.json'); evidence.artifacts.push(path.relative(ROOT, file).replaceAll('\\', '/'));
    fs.writeFileSync(file, JSON.stringify(evidence, null, 2));
    console.log(JSON.stringify({ result: evidence.result, scenarios: evidence.scenarioResults,
      created: evidence.fixtureCreationCount, cleaned: evidence.fixtureCleanupCount, cleanupVerified: evidence.cleanupVerified,
      expectedNetworkFailures: evidence.expectedNetworkFailureCount, unexpectedNetworkFailures: evidence.unexpectedNetworkFailureCount,
      evidence: path.relative(ROOT, file), setupFailure: evidence.setupFailure, cleanupFailure: evidence.cleanupFailure }));
    process.exitCode = evidence.result === 'PASS' ? 0 : 1;
  }
}
main().catch(() => { console.error('HARNESS_CONFIG_FAILURE (no credential output)'); process.exitCode = 1; });
