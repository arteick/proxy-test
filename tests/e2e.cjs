// Браузерная проверка (вручную): PORT=8099 node src/server.js & node tests/e2e.cjs
const { chromium } = require('playwright');
(async () => {
const b = await chromium.launch();
const p = await b.newPage();
const errs = [];
p.on('pageerror', (e) => errs.push(e.message));
await p.goto('http://localhost:8099/');
await p.click('text=main.js');
await p.click('.line:nth-child(1) .text');
await p.keyboard.press('Home');
await p.keyboard.press('Control+Alt+ArrowDown');
await p.keyboard.press('Control+Alt+ArrowDown');
await p.keyboard.type('// ');
const t = await p.$$eval('.line .text', (n) => n.map((x) => x.textContent));
console.log(JSON.stringify(t.slice(0, 3)), errs);
// папка и файл в ней
p.on('dialog', (d) => d.accept(d.message().includes('папки') ? 'lib' : 'x.js'));
await p.click('#newDir'); await p.click('#newFile');
console.log(await p.$$eval('.item', (n) => n.map((x) => x.textContent)));
await b.close();
})();
