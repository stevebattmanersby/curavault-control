'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf' };
async function serve(root) {
  const server = http.createServer((req, res) => {
    try {
      const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
      let file = path.resolve(root, '.' + pathname);
      if (file !== root && !file.startsWith(root + path.sep)) throw new Error('Path traversal');
      if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(root, 'index.html');
      const real = fs.realpathSync(file);
      if (!real.startsWith(fs.realpathSync(root) + path.sep)) throw new Error('Symlink');
      res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
        'Cache-Control': 'no-store', 'Content-Security-Policy': "connect-src 'self' https://evvksortjegefsldamwb.supabase.co https://fonts.gstatic.com; img-src 'self' data: blob:; font-src 'self' data: https://fonts.gstatic.com" });
      fs.createReadStream(file).pipe(res);
    } catch { res.writeHead(400); res.end(); }
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(4178, '127.0.0.1', resolve); });
  return server;
}
module.exports = { serve };
