// Serves backend/.data/qa-media (generated dish photos for local QA) with
// CORS so the web build on another port can draw them. Local only.
//   node scripts/serve-media.js [port]
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] ?? 8643);
const root = path.resolve(__dirname, '..', '.data', 'qa-media');
const types = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml' };

http
  .createServer((req, res) => {
    const name = path.basename(decodeURIComponent((req.url ?? '/').split('?')[0]));
    const file = path.join(root, name);
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (!name || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': types[path.extname(name).toLowerCase()] ?? 'application/octet-stream', 'Cache-Control': 'no-cache' });
    fs.createReadStream(file).pipe(res);
  })
  .listen(port, () => console.log(`qa-media on http://localhost:${port} (${root})`));
