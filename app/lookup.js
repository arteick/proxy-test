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

export async function lookup(code, f = fetch) {
  for (const host of SOURCES) {
    const res = await fromHost(host, code, f);
    if (res) return res;
  }
  return null;
}
