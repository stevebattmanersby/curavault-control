'use strict';
function security(condition, reason) {
  if (condition) return;
  const error = new Error(reason);
  error.name = 'SecurityContractFailure';
  error.safeReason = reason;
  throw error;
}
module.exports = { security };
