'use strict';
// Browser subprocesses receive OS paths/locale only, never server credentials.
function browserEnv(env = process.env) {
  const keys = ['PATH', 'Path', 'SystemRoot', 'SYSTEMROOT', 'WINDIR', 'HOME',
    'USERPROFILE', 'TEMP', 'TMP', 'TMPDIR', 'LOCALAPPDATA', 'APPDATA', 'LANG', 'LC_ALL'];
  return Object.fromEntries(keys.filter(key => typeof env[key] === 'string').map(key => [key, env[key]]));
}
module.exports = { browserEnv };
