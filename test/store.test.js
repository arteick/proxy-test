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

test('lookup: цепочка баз — берёт первую, где нашёлся товар', async () => {
  const urls = [];
  const f = async (u) => {
    urls.push(u);
    return { ok: true, json: async () => (u.includes('openbeautyfacts') ? { status: 1, product: { product_name: 'Шампунь' } } : { status: 0 }) };
  };
  assert.equal((await lookup('222', f)).name, 'Шампунь');
  assert.equal(urls.length, 3);
});

test('fullName: производитель, товар, граммовка без дублей', async () => {
  const { fullName } = await import('../app/lookup.js');
  assert.equal(fullName({ brands: 'Простоквашино, Данон', product_name: 'Молоко 3,2%', quantity: '930 г' }), 'Простоквашино Молоко 3,2% 930 г');
  assert.equal(fullName({ brands: 'Простоквашино', product_name: 'Простоквашино Молоко 930 г', quantity: '930 г' }), 'Простоквашино Молоко 930 г');
  assert.equal(fullName({ product_name: 'Хлеб' }), 'Хлеб');
});

test('qty: по умолчанию 1, меняется в пределах 1..99, переносится ссылкой', () => {
  let l = s.add([], milk);
  assert.equal(l[0].qty, 1);
  l = s.setQty(l, '111', 3);
  assert.equal(l[0].qty, 3);
  assert.equal(s.setQty(l, '111', 0)[0].qty, 1);
  assert.equal(s.setQty(l, '111', 500)[0].qty, 99);
  assert.equal(s.decode(s.encode(l))[0].qty, 3);
  assert.equal(s.add(l, milk)[0].qty, 3);
});

test('fullName: русское название и граммовка из product_quantity', async () => {
  const { fullName } = await import('../app/lookup.js');
  assert.equal(fullName({ brands: 'Arla', product_name: 'Aktiv Bio Jordbær', product_name_ru: 'Йогурт клубника', product_quantity: '500', product_quantity_unit: 'g' }), 'Arla Йогурт клубника 500 g');
});
