'use strict';
const path = require('node:path');
const { config } = require('./config.cjs');
const { Api } = require('./api.cjs');
const { Fixtures } = require('./fixtures.cjs');
async function main() {
  const file = path.resolve(process.argv[2] || '');
  const fixtures = Fixtures.load(new Api(config()), file);
  await fixtures.cleanup();
  console.log(JSON.stringify({ ref: fixtures.journal.ref, cleanupVerified: true, cleaned: fixtures.cleaned }));
}
main().catch(() => { console.error('CLEANUP_FAILED: retain journal; no further live runs'); process.exitCode = 1; });
