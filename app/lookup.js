// Название и категория товара по штрихкоду: открытая база Open Food Facts, без ключа.
// «Производитель Товар граммовка»; части, уже входящие в название, не дублируются.
export function fullName({ brands, product_name: name, quantity }) {
  const brand = String(brands || '').split(',')[0].trim();
  const qty = String(quantity || '').trim();
  const has = (part) => name.toLowerCase().includes(part.toLowerCase());
  return [brand && !has(brand) ? brand : '', name.trim(), qty && !has(qty) ? qty : ''].filter(Boolean).join(' ');
}

export async function lookup(code, f = fetch) {
  try {
    const r = await f(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json?fields=product_name,brands,quantity,categories_tags`);
    if (!r.ok) return null;
    const j = await r.json();
    const p = j.status === 1 && j.product;
    if (!p || !p.product_name) return null;
    const tags = p.categories_tags || [];
    return { code, name: fullName(p), cat: tags[tags.length - 1] || '' };
  } catch {
    return null;
  }
}
