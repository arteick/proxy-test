// Название и категория товара по штрихкоду: открытые базы Open Food Facts / Products / Beauty / Pet Food Facts, без ключа.
// «Производитель Товар граммовка»; части, уже входящие в название, не дублируются.
export function pickName(p) {
  return [p.product_name_ru, p.product_name_en, p.product_name, p.generic_name_ru, p.generic_name].map((x) => String(x || '').trim()).find(Boolean) || '';
}

export function pickQuantity(p) {
  const q = String(p.quantity || '').trim();
  if (q) return q;
  return p.product_quantity ? `${p.product_quantity} ${p.product_quantity_unit || 'г'}` : '';
}

export function fullName(p) {
  const name = pickName(p);
  const qty = pickQuantity(p);
  const brand = String(p.brands || '').split(',')[0].trim();
  const has = (part) => name.toLowerCase().includes(part.toLowerCase());
  return [brand && !has(brand) ? brand : '', name, qty && !has(qty) ? qty : ''].filter(Boolean).join(' ');
}

// Базы одного семейства (одинаковый API, без ключа, открытый CORS), по очереди.
export const SOURCES = ['world.openfoodfacts.org', 'world.openproductsfacts.org', 'world.openbeautyfacts.org', 'world.openpetfoodfacts.org'];

async function fromHost(host, code, f) {
  try {
    const r = await f(`https://${host}/api/v2/product/${encodeURIComponent(code)}.json?fields=product_name,product_name_ru,product_name_en,generic_name,generic_name_ru,brands,quantity,product_quantity,product_quantity_unit,categories_tags`);
    if (!r.ok) return null;
    const j = await r.json();
    const p = j.status === 1 && j.product;
    if (!p || !pickName(p)) return null;
    const tags = p.categories_tags || [];
    return { code, name: fullName(p), cat: tags[tags.length - 1] || '' };
  } catch {
    return null;
  }
}

// UPCitemdb, пробный доступ без ключа (лимит ~100 запросов в сутки с адреса); сильнее по западным товарам.
async function fromUpcItemDb(code, f) {
  try {
    const r = await f(`https://api.upcitemdb.com/prod/trial/lookup?upc=${encodeURIComponent(code)}`);
    if (!r.ok) return null;
    const j = await r.json();
    const it = j && j.items && j.items[0];
    const title = it && String(it.title || '').trim();
    if (!title) return null;
    const brand = String(it.brand || '').trim();
    return { code, name: brand && !title.toLowerCase().includes(brand.toLowerCase()) ? `${brand} ${title}` : title, cat: it.category || '' };
  } catch {
    return null;
  }
}

// Локальный кэш: найденное и введённое вручную, чтобы не ходить в сеть дважды.
const KEY = 'shop.names';
export function cacheGet(storage, code) {
  try { return JSON.parse(storage.getItem(KEY) || '{}')[code] || null; } catch { return null; }
}
export function cachePut(storage, p) {
  try {
    const all = JSON.parse(storage.getItem(KEY) || '{}');
    all[p.code] = p;
    storage.setItem(KEY, JSON.stringify(all));
  } catch { /* кэш необязателен */ }
}

export async function lookup(code, f = fetch) {
  for (const host of SOURCES) {
    const res = await fromHost(host, code, f);
    if (res) return res;
  }
  return fromUpcItemDb(code, f);
}
