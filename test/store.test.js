import test from 'node:test';
import assert from 'node:assert/strict';
import * as s from '../app/store.js';
import { lookup } from '../app/lookup.js';

const milk = { code: '111', name: 'Молоко Простоквашино 3,2%', cat: 'en:milks' };
const milk2 = { code: '222', name: 'Молоко Домик в деревне', cat: 'en:milks' };
const bread = { code: '333', name: 'Хлеб Бородинский', cat: 'en:breads' };

test('add: без дублей по коду, пустой код игнорируется', () => {
  let l = s.add([], milk);
  l = s.add(l, milk);
  assert.equal(l.length, 1);
  assert.equal(l[0].bought, false);
  assert.deepEqual(s.add(l, { code: '', name: 'x' }), l);
});

test('remove и toggle', () => {
  let l = s.add(s.add([], milk), bread);
  l = s.toggle(l, '111');
  assert.equal(l.find((x) => x.code === '111').bought, true);
  l = s.remove(l, '111');
  assert.deepEqual(l.map((x) => x.code), ['333']);
});

test('encode/decode: ссылка переносит список, покупки сбрасываются', () => {
  const l = s.toggle(s.add(s.add([], milk), bread), '111');
  const str = s.encode(l);
  assert.match(str, /^[A-Za-z0-9_-]+$/);
  const back = s.decode(str);
  assert.deepEqual(back.map((x) => [x.code, x.name, x.cat]), l.map((x) => [x.code, x.name, x.cat]));
  assert.ok(back.every((x) => x.bought === false));
});

test('decode: мусор даёт пустой список', () => {
  assert.deepEqual(s.decode('%%%'), []);
  assert.deepEqual(s.decode(''), []);
  assert.deepEqual(s.decode(Buffer.from('{"a":1}').toString('base64url')), []);
});

test('match: точный по коду', () => {
  const l = s.add([], milk);
  assert.deepEqual(s.match(l, milk), { type: 'exact', item: l[0] });
});

test('match: похожий по категории, затем по слову названия', () => {
  const l = s.add(s.add([], milk), bread);
  assert.equal(s.match(l, milk2).type, 'similar');
  assert.equal(s.match(l, milk2).item.code, '111');
  const noCat = { code: '444', name: 'Хлеб белый нарезной', cat: '' };
  assert.equal(s.match(l, noCat).item.code, '333');
});

test('match: нет в списке; купленное не предлагается', () => {
  const l = s.toggle(s.add([], milk), '111');
  assert.deepEqual(s.match(l, bread), { type: 'none' });
  assert.deepEqual(s.match(l, milk2), { type: 'none' });
  assert.equal(s.match(l, milk).type, 'exact');
});

test('replace: подставляет отсканированный товар и отмечает купленным', () => {
  const l = s.replace(s.add([], milk), '111', milk2);
  assert.deepEqual(l.map((x) => [x.code, x.bought]), [['222', true]]);
});

test('load/save', () => {
  const mem = { getItem() { return this.v ?? null; }, setItem(_, x) { this.v = x; } };
  assert.deepEqual(s.load(mem), []);
  s.save(mem, s.add([], milk));
  assert.equal(s.load(mem)[0].code, '111');
});

test('lookup: Open Food Facts, неизвестный код, сбой сети', async () => {
  const ok = async () => ({ ok: true, json: async () => ({ status: 1, product: { product_name: 'Молоко', categories_tags: ['en:dairies', 'en:milks'] } }) });
  assert.deepEqual(await lookup('111', ok), { code: '111', name: 'Молоко', cat: 'en:milks' });
  const none = async () => ({ ok: true, json: async () => ({ status: 0 }) });
  assert.equal(await lookup('111', none), null);
  const boom = async () => { throw new Error('offline'); };
  assert.equal(await lookup('111', boom), null);
});
