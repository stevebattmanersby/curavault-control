'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { spawnSync, execFileSync } = require('node:child_process');
const { config, PRODUCTION } = require('./config.cjs');
const ROOT = path.resolve(__dirname, '../..');
const BUILD = path.join(ROOT, 'build/control-e2e/web');
function sha() { return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: ROOT, encoding: 'utf8' }).trim(); }
function hashes(directory = BUILD) {
  const result = {};
  function walk(dir) {
    for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
      assert.ok(!item.isSymbolicLink(), 'Build symlinks forbidden');
      const file = path.join(dir, item.name);
      if (item.isDirectory()) walk(file);
      else if (item.name !== 'e2e-stamp.json') {
        const bytes = fs.readFileSync(file);
        assert.ok(!bytes.includes(Buffer.from(PRODUCTION)), 'Production ref found in isolated build');
        result[path.relative(directory, file).replaceAll('\\', '/')] = crypto.createHash('sha256').update(bytes).digest('hex');
      }
    }
  }
  walk(directory); return result;
}
function verifyBuild(cfg) {
  const stamp = JSON.parse(fs.readFileSync(path.join(BUILD, 'e2e-stamp.json')));
  assert.equal(stamp.ref, cfg.ref); assert.equal(stamp.sha, sha(), 'Stale build SHA');
  assert.deepEqual(stamp.hashes, hashes(), 'Build changed since isolation check');
  const publicConfig = JSON.parse(fs.readFileSync(path.join(BUILD, 'assets/assets/config/control_site_config.json')));
  assert.equal(publicConfig.SUPABASE_URL, cfg.url); assert.equal(publicConfig.SUPABASE_ANON_KEY, cfg.anon);
  return stamp;
}
function build() {
  const cfg = config(process.env, false);
  fs.mkdirSync(path.dirname(BUILD), { recursive: true });
  const file = path.join(ROOT, 'build/control-e2e/public-defines.json');
  const defines = { SUPABASE_URL: cfg.url, SUPABASE_ANON_KEY: cfg.anon,
    CONTROL_SITE_BASE_URL: 'http://127.0.0.1:4178', CONTROL_SITE_ENV_LABEL: 'DISPOSABLE E2E' };
  fs.writeFileSync(file, JSON.stringify(defines), { mode: 0o600 });
  const env = { ...process.env };
  delete env.CONTROL_E2E_ADMIN_KEY;
  try {
    const result = spawnSync('flutter', ['build', 'web', '--release', '--no-web-resources-cdn',
      `--dart-define-from-file=${file}`, `--output=${BUILD}`],
    { cwd: ROOT, env, shell: process.platform === 'win32', stdio: 'inherit' });
    assert.equal(result.status, 0, 'Isolated Flutter build failed');
    // Source production config is untouched. Its build copy cannot be a fallback.
    fs.writeFileSync(path.join(BUILD, 'assets/assets/config/control_site_config.json'), JSON.stringify(defines));
    const stamp = { version: 1, sha: sha(), ref: cfg.ref, hashes: hashes() };
    fs.writeFileSync(path.join(BUILD, 'e2e-stamp.json'), JSON.stringify(stamp, null, 2));
    verifyBuild(cfg);
    console.log('ISOLATED_BUILD_VERIFIED');
  } finally { fs.rmSync(file, { force: true }); }
}
if (require.main === module) {
  try { build(); } catch { console.error('ISOLATED_BUILD_FAILED (no credential output)'); process.exitCode = 1; }
}
module.exports = { ROOT, BUILD, sha, hashes, verifyBuild };
