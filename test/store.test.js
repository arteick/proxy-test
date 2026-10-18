import test from 'node:test';
import assert from 'node:assert/strict';
import * as s from '../app/store.js';

const mem = (v) => ({ v, getItem() { return this.v ?? null; }, setItem(_, x) { this.v = x; } });

test('add обрезает пробелы и игнорирует пустое', () => {
  assert.deepEqual(s.add([], '   '), []);
  const t = s.add([], '  купить хлеб ', 1);
  assert.equal(t[0].text, 'купить хлеб');
  assert.equal(t[0].done, false);
});
test('toggle, remove, clearDone, filter', () => {
  let t = s.add(s.add([], 'a', 1), 'b', 2);
  t = s.toggle(t, t.find((x) => x.text === 'a').id);
  assert.equal(s.filter(t, 'done').length, 1);
  assert.equal(s.filter(t, 'active').length, 1);
  assert.equal(s.clearDone(t).length, 1);
  assert.equal(s.remove(t, t[0].id).length, 1);
});
test('id уникальны при одинаковом времени', () => {
  const t = s.add(s.add([], 'a', 5), 'b', 5);
  assert.notEqual(t[0].id, t[1].id);
});
test('save/load и битые данные', () => {
  const st = mem();
  s.save(st, s.add([], 'x', 1));
  assert.equal(s.load(st)[0].text, 'x');
  assert.deepEqual(s.load(mem('{oops')), []);
  assert.deepEqual(s.load(mem('{"a":1}')), []);
});
test('манифест и service worker согласованы', async () => {
  const fs = await import('node:fs');
  const m = JSON.parse(fs.readFileSync('app/manifest.webmanifest', 'utf8'));
  assert.equal(m.display, 'standalone');
  for (const i of m.icons) assert.ok(fs.existsSync(`app/${i.src}`), i.src);
  const sw = fs.readFileSync('app/sw.js', 'utf8');
  for (const f of ['index.html', 'app.js', 'store.js', 'style.css']) assert.ok(sw.includes(f), f);
});
