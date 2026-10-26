// Статический сервер для src/: npm start → http://localhost:8080
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8' };

export const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x').pathname;
  const rel = normalize(url === '/' ? 'index.html' : url).replace(/^([/\\]|\.\.)+/, '');
  try {
    const body = await readFile(join(root, rel));
    res.writeHead(200, { 'content-type': types[extname(rel)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end('Not found');
  }
});

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  server.listen(process.env.PORT ?? 8080, () => console.log('http://localhost:' + (process.env.PORT ?? 8080)));
}
