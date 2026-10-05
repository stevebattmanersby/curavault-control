'use strict';
// Exact endpoint/status/code classifications; unknown errors always block PASS.
function classify(method, pathname, status, code, scenario) {
  if (status === 400 && pathname === '/rest/v1/usage_events' && method === 'POST' && code === 'PGRST204')
    return { category: 'D', defect: 'A', expected: false, reason: 'Optional telemetry uses incompatible columns' };
  if (status === 400 && pathname === '/rest/v1/user_entitlements' && method === 'GET' && code === '42703')
    return { category: 'A', expected: false, reason: 'Stale provider/store entitlement columns; billing remediation requires separate approval' };
  if (status === 404 && ['/rest/v1/rpc/admin_get_ai_usage_summary_v2', '/rest/v1/rpc/admin_get_storage_summary_v2'].includes(pathname) && code === 'PGRST202')
    return { category: 'E', expected: true, reason: 'Unsupported v2 probe; require successful V1 fallback separately' };
  if (status === 403 && pathname === '/rest/v1/admin_audit_log' && method === 'POST' && code === '42501' && scenario === 'readonly-ui')
    return { category: 'C', expected: true, reason: 'read_only audit INSERT denied by policy' };
  if (status === 403 && pathname === '/rest/v1/subscription_events' && method === 'GET' && code === '42501')
    return { category: 'C', defect: 'A', expected: false, reason: 'Service-only billing event table correctly denies browser; stale client dependency needs separate billing review' };
  if (status === 404 && ['/rest/v1/stripe_webhook_events', '/rest/v1/asset_library_backend'].includes(pathname) && method === 'GET' && code === 'PGRST205')
    return { category: 'A', defect: 'E', expected: false, reason: 'Client calls relation absent on disposable and production; separate contract remediation' };
  return { category: 'A', expected: false, reason: 'Unclassified backend/network failure' };
}
module.exports = { classify };
