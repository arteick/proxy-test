// Название и категория товара по штрихкоду: открытая база Open Food Facts, без ключа.
export async function lookup(code, f = fetch) {
  try {
    const r = await f(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json?fields=product_name,categories_tags`);
    if (!r.ok) return null;
    const j = await r.json();
    const p = j.status === 1 && j.product;
    if (!p || !p.product_name) return null;
    const tags = p.categories_tags || [];
    return { code, name: p.product_name, cat: tags[tags.length - 1] || '' };
  } catch {
    return null;
  }
}
