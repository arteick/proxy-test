// Название и категория товара по штрихкоду: открытая база Open Food Facts, без ключа.
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

export async function lookup(code, f = fetch) {
  try {
    const r = await f(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json?fields=product_name,product_name_ru,product_name_en,generic_name,generic_name_ru,brands,quantity,product_quantity,product_quantity_unit,categories_tags`);
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
