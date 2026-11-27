const http = require('http');
const https = require('https');
const net = require('net');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.PORT || 3003;
const LOCAL_API_TARGET = process.env.API_TARGET || 'http://127.0.0.1:8000';
const WS_HOST = process.env.WS_HOST || '127.0.0.1';
const WS_PORT = Number(process.env.WS_PORT || 8080);

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.map': 'application/json',
};

function proxyRequest(req, res, targetBase) {
  const targetUrl = new URL(req.url, targetBase);
  const isHttps = targetUrl.protocol === 'https:';
  const client = isHttps ? https : http;

  const headers = { ...req.headers };
  headers.host = targetUrl.host;

  const proxyReq = client.request(
    targetUrl,
    {
      method: req.method,
      headers: headers,
    },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on('error', (err) => {
    console.error('[Proxy Error]', err.message);
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ success: false, message: 'API Gateway Unavailable', error: err.message }));
  });

  req.pipe(proxyReq);
}

function resolveStaticFile(pathname) {
  const cleanPath = pathname.replace(/^\/+/, '');
  const candidatePaths = [
    path.join(__dirname, cleanPath),
    path.join(__dirname, 'build', 'web', cleanPath),
    path.join(__dirname, 'frontend', 'build', 'web', cleanPath),
  ];

  for (const p of candidatePaths) {
    if (fs.existsSync(p) && fs.statSync(p).isFile()) {
      return p;
    }
  }

  return null;
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', '*');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url);
  const pathname = decodeURIComponent(parsedUrl.pathname || '/');

  if (pathname.startsWith('/api')) {
    proxyRequest(req, res, LOCAL_API_TARGET);
    return;
  }

  const filePath = resolveStaticFile(pathname === '/' ? 'index.html' : pathname);

  if (filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    const headers = {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
      'Pragma': 'no-cache',
      'Expires': '0',
    };
    if (ext === '.html') {
      headers['Clear-Site-Data'] = '"cache"';
    }
    res.writeHead(200, headers);
    fs.createReadStream(filePath).pipe(res);
  } else {
    const indexPath = path.join(__dirname, 'index.html');
    if (fs.existsSync(indexPath)) {
      res.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-cache, no-store, must-revalidate, max-age=0',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Clear-Site-Data': '"cache"',
      });
      fs.createReadStream(indexPath).pipe(res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
    }
  }
});

server.on('upgrade', (req, socket, head) => {
  const target = net.connect(WS_PORT, WS_HOST, () => {
    const headerLines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
    for (const [k, v] of Object.entries(req.headers)) {
      headerLines.push(`${k}: ${v}`);
    }
    target.write(headerLines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) target.write(head);
    target.pipe(socket);
    socket.pipe(target);
  });
  target.on('error', () => socket.destroy());
  socket.on('error', () => target.destroy());
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`\n======================================================`);
  console.log(`🚑 LifeRoute Emergency User Booking App`);
  console.log(`======================================================`);
  console.log(`✅ User App:   http://localhost:${PORT}`);
  console.log(`🔗 API Target: ${LOCAL_API_TARGET}`);
  console.log(`======================================================\n`);
});
