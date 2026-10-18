import * as store from './store.js';
import { lookup } from './lookup.js';
import { canScan, startScan } from './scan.js';

const $ = (id) => document.getElementById(id);
let items = store.load(localStorage);
let mode = 'add';
let stop = () => {};
let busy = false;

function commit(next) {
  items = next;
  store.save(localStorage, items);
  render();
}

function toast(text) {
  $('toast').textContent = text;
  $('toast').hidden = false;
  clearTimeout(toast.t);
  toast.t = setTimeout(() => ($('toast').hidden = true), 3500);
}

function render() {
  $('list').replaceChildren(...items.map((p) => {
    const li = document.createElement('li');
    li.className = p.bought ? 'done' : '';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = p.bought;
    cb.onchange = () => commit(store.toggle(items, p.code));
    const span = document.createElement('span');
    span.textContent = p.name;
    const del = document.createElement('button');
    del.className = 'del';
    del.textContent = '✕';
    del.setAttribute('aria-label', 'Удалить');
    del.onclick = () => commit(store.remove(items, p.code));
    li.append(cb, span, del);
    return li;
  }));
  $('empty').hidden = items.length > 0;
  $('clear').hidden = !items.some((p) => p.bought);
  $('share').hidden = items.length === 0;
}

async function onCode(raw) {
  const code = String(raw).replace(/\D/g, '');
  if (!code || busy) return;
  busy = true;
  try {
    let p = items.find((x) => x.code === code) || (await lookup(code));
    if (!p) {
      const name = prompt(`Товар ${code} не найден в базе. Как назвать?`);
      p = { code, name: (name || '').trim() || `Товар ${code}`, cat: '' };
    }
    if (mode === 'add') {
      if (items.some((x) => x.code === code)) return toast(`Уже в списке: ${p.name}`);
      commit(store.add(items, p));
      return toast(`Добавлено: ${p.name}`);
    }
    const m = store.match(items, p);
    if (m.type === 'exact') {
      if (!m.item.bought) commit(store.toggle(items, code));
      toast(`Нужный продукт, готово ✓ ${m.item.name}`);
    } else if (m.type === 'similar') {
      if (confirm(`Похожий продукт.\nВ списке: ${m.item.name}\nВ руках: ${p.name}\nЗаменить?`)) {
        commit(store.replace(items, m.item.code, p));
        toast(`Заменено: ${p.name}`);
      }
    } else {
      toast(`Нет в списке: ${p.name}`);
    }
  } finally {
    busy = false;
  }
}

async function open(m) {
  mode = m;
  $('hint').textContent = m === 'add' ? 'Наведите камеру на штрихкод — товар попадёт в список' : 'Сканируйте товары в магазине — я отмечу нужные';
  $('scanner').hidden = false;
  try {
    stop = await startScan($('video'), onCode);
  } catch {
    toast('Нет доступа к камере — введите код вручную');
  }
  $('video').hidden = !canScan();
}

$('scan-add').onclick = () => open('add');
$('scan-shop').onclick = () => open('shop');
$('close').onclick = () => { stop(); stop = () => {}; $('scanner').hidden = true; };
$('manual').onsubmit = (e) => { e.preventDefault(); onCode($('code').value); $('code').value = ''; };
$('clear').onclick = () => commit(items.filter((p) => !p.bought));

$('share').onclick = async () => {
  const url = `${location.origin}${location.pathname}#l=${store.encode(items)}`;
  try {
    if (navigator.share) await navigator.share({ title: 'Список покупок', url });
    else { await navigator.clipboard.writeText(url); toast('Ссылка скопирована'); }
  } catch { /* отмена */ }
};

// Открыта ссылка со списком: добавляем его товары к своему.
const shared = new URLSearchParams(location.hash.slice(1)).get('l');
if (shared) {
  const incoming = store.decode(shared);
  history.replaceState(null, '', location.pathname);
  if (incoming.length && confirm(`Получен список: ${incoming.length} товаров. Добавить к вашему?`)) {
    commit(incoming.reduce((acc, p) => store.add(acc, p), items));
  }
}

let installEvent;
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); installEvent = e; $('install').hidden = false; });
$('install').onclick = async () => { if (installEvent) { installEvent.prompt(); installEvent = null; $('install').hidden = true; } };

if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js');
render();
