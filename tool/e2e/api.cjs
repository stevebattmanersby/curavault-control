'use strict';
const assert = require('node:assert/strict');
const { allowed } = require('./config.cjs');
class Api {
  constructor(config, transport = fetch) { this.config = config; this.transport = transport; }
  async request(endpoint, { method = 'GET', body, token, admin = false, prefer } = {}) {
    assert.ok(endpoint.startsWith('/') && !endpoint.startsWith('//'), 'Relative API path required');
    const url = this.config.url + endpoint;
    assert.ok(allowed(url), 'API target denied');
    const key = admin ? this.config.adminKey : this.config.anon;
    const response = await this.transport(url, {
      method, redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { apikey: key, Authorization: `Bearer ${token || key}`,
        'Content-Type': 'application/json', ...(prefer ? { Prefer: prefer } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    const text = await response.text();
    let data;
    try { data = text ? JSON.parse(text) : null; } catch { data = null; }
    // Never include response bodies or credential-bearing URLs in exceptions.
    return { status: response.status, data };
  }
  async ok(endpoint, options, statuses = [200]) {
    const response = await this.request(endpoint, options);
    assert.ok(statuses.includes(response.status), `API status ${response.status}; expected ${statuses.join('/')}`);
    return response.data;
  }
}
module.exports = { Api };
