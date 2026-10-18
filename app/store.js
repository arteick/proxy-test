// Логика списка покупок без привязки к браузеру: тестируется на Node.
export const KEY = 'products.v1';

export function load(storage) {
  try {
    const list = JSON.parse(storage.getItem(KEY) || '[]');
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

export function save(storage, items) {
  storage.setItem(KEY, JSON.stringify(items));
}

export function add(items, p) {
  const code = String(p?.code ?? '').trim();
  if (!code || items.some((x) => x.code === code)) return items;
  return [{ code, name: String(p.name || `Товар ${code}`), cat: p.cat || '', bought: false }, ...items];
}

export function remove(items, code) {
  return items.filter((x) => x.code !== code);
}

export function toggle(items, code) {
  return items.map((x) => (x.code === code ? { ...x, bought: !x.bought } : x));
}

// Список в строку для ссылки (без отметок «куплено»).
export function encode(items) {
  const rows = items.map((x) => [x.code, x.name, x.cat]);
  const bin = String.fromCharCode(...new TextEncoder().encode(JSON.stringify(rows)));
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function decode(str) {
  try {
    const bin = atob(String(str).replace(/-/g, '+').replace(/_/g, '/'));
    const rows = JSON.parse(new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0))));
    if (!Array.isArray(rows)) return [];
    return rows.filter((r) => Array.isArray(r) && r[0]).map((r) => ({ code: String(r[0]), name: String(r[1] ?? ''), cat: String(r[2] ?? ''), bought: false }));
  } catch {
    return [];
  }
}

const words = (name) => String(name).toLowerCase().split(/[^\p{L}\p{N}]+/u).filter((w) => w.length >= 4);

// Что делать с отсканированным в магазине товаром.
export function match(items, p) {
  const exact = items.find((x) => x.code === p.code);
  if (exact) return { type: 'exact', item: exact };
  const open = items.filter((x) => !x.bought);
  const byCat = p.cat && open.find((x) => x.cat === p.cat);
  if (byCat) return { type: 'similar', item: byCat };
  const w = words(p.name);
  const byWord = open.find((x) => words(x.name).some((y) => w.includes(y)));
  return byWord ? { type: 'similar', item: byWord } : { type: 'none' };
}

export function replace(items, code, p) {
  return items.map((x) => (x.code === code ? { code: p.code, name: p.name, cat: p.cat || '', bought: true } : x));
}
