'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const { REF } = require('./config.cjs');
const ROLES = [
  ['owner-ui', 'owner', true], ['admin-ui', 'admin', true],
  ['readonly-ui', 'read_only', true], ['inactive-ui', 'admin', false],
  ['ordinary-ui', null, false], ['aal1-api', 'admin', true], ['aal2-api', 'admin', true],
];
class Fixtures {
  constructor(api, file, runId = crypto.randomUUID()) {
    assert.match(runId, /^[0-9a-f-]{36}$/);
    this.api = api; this.file = file;
    this.journal = { version: 1, ref: REF, runId, fixtures: [] };
    this.users = []; this.created = 0; this.cleaned = 0;
  }
  save() {
    fs.writeFileSync(this.file + '.tmp', JSON.stringify(this.journal, null, 2), { mode: 0o600 });
    fs.renameSync(this.file + '.tmp', this.file);
  }
  async create() {
    for (const [scenario, role, active] of ROLES) {
      const email = `control-e2e-${this.journal.runId}-${scenario}@example.invalid`;
      const entry = { email, scenario, id: null, cleaned: false };
      // Write intent BEFORE Auth creation: recovery discovers a user if the response is lost.
      this.journal.fixtures.push(entry); this.save();
      const password = crypto.randomBytes(32).toString('base64url') + 'aA1!';
      const user = await this.api.ok('/auth/v1/admin/users', {
        admin: true, method: 'POST', body: { email, password, email_confirm: true,
          user_metadata: { control_e2e_run: this.journal.runId } },
      }, [200, 201]);
      assert.match(user.id, /^[0-9a-f-]{36}$/);
      entry.id = user.id; this.created++; this.save();
      const fixture = { ...entry, password, role, active };
      this.users.push(fixture);
      if (role) await this.api.ok('/rest/v1/admin_users', {
        admin: true, method: 'POST', prefer: 'return=minimal',
        body: { admin_user_id: user.id, email, role, is_active: active },
      }, [201]);
    }
    assert.equal(new Set(this.users.map(u => u.id)).size, ROLES.length);
    return this.users;
  }
  static load(api, file) {
    const journal = JSON.parse(fs.readFileSync(file));
    assert.equal(journal.version, 1); assert.equal(journal.ref, REF);
    const fixtures = new Fixtures(api, file, journal.runId);
    assert.ok(Array.isArray(journal.fixtures) && journal.fixtures.length <= ROLES.length);
    for (const entry of journal.fixtures) {
      assert.ok(ROLES.some(([scenario]) => entry.scenario === scenario));
      assert.equal(entry.email, `control-e2e-${journal.runId}-${entry.scenario}@example.invalid`);
      if (entry.id) assert.match(entry.id, /^[0-9a-f-]{36}$/);
    }
    fixtures.journal = journal;
    return fixtures;
  }
  async discover(entry) {
    // Paginated, server-only lookup. Persist only the exact synthetic match.
    for (let page = 1; page <= 100; page++) {
      const result = await this.api.ok(`/auth/v1/admin/users?page=${page}&per_page=100`, { admin: true });
      const matches = result.users.filter(u => u.email === entry.email);
      assert.ok(matches.length <= 1);
      if (matches.length) return matches[0];
      if (result.users.length < 100) return null;
    }
    throw new Error('Fixture discovery pagination bound exceeded');
  }
  async cleanup() {
    const failures = [];
    for (const entry of this.journal.fixtures) {
      try {
        const found = await this.discover(entry);
        if (found) {
          assert.equal(found.user_metadata?.control_e2e_run, this.journal.runId, 'Synthetic ownership mismatch');
          if (entry.id) assert.equal(found.id, entry.id, 'Fixture identity changed');
          entry.id = found.id; this.save();
        }
        if (entry.id) {
          const existing = await this.api.request(`/auth/v1/admin/users/${entry.id}`, { admin: true });
          assert.ok([200, 404].includes(existing.status), 'Cannot verify cleanup identity');
          if (existing.status === 200) {
            assert.equal(existing.data.email, entry.email, 'Cleanup email mismatch');
            assert.equal(existing.data.user_metadata?.control_e2e_run, this.journal.runId, 'Cleanup run mismatch');
          }
          const query = `admin_user_id=eq.${entry.id}`;
          // Audit FK uses SET NULL; remove only fixture actor rows before deleting Auth.
          await this.api.ok(`/rest/v1/admin_audit_log?${query}`, { admin: true, method: 'DELETE' }, [204]);
          await this.api.ok(`/rest/v1/admin_users?${query}`, { admin: true, method: 'DELETE' }, [204]);
          if (found) await this.api.ok(`/auth/v1/admin/users/${entry.id}`, { admin: true, method: 'DELETE' }, [200]);
          const absence = await this.api.request(`/auth/v1/admin/users/${entry.id}`, { admin: true });
          assert.equal(absence.status, 404, 'Auth fixture remains');
          for (const [table, column] of [['admin_users', 'admin_user_id'], ['admin_audit_log', 'admin_user_id'], ['usage_events', 'user_id'], ['usage_events', 'owner_user_id']]) {
            const rows = await this.api.ok(`/rest/v1/${table}?${column}=eq.${entry.id}&select=${column}`, { admin: true });
            assert.equal(rows.length, 0, `Fixture remains in ${table}`);
          }
        }
        assert.equal(await this.discover(entry), null, 'Synthetic email remains');
        entry.cleaned = true; this.cleaned++; this.save();
      } catch { failures.push(entry.scenario); }
    }
    if (failures.length) throw new Error(`Cleanup failed: ${failures.join(', ')}; retain journal and run cleanup recovery`);
  }
}
module.exports = { Fixtures, ROLES };
