import * as store from './store.js';

const $ = (id) => document.getElementById(id);
let tasks = store.load(localStorage);
let mode = 'all';

function commit(next) {
  tasks = next;
  store.save(localStorage, tasks);
  render();
}

function render() {
  const shown = store.filter(tasks, mode);
  $('list').replaceChildren(...shown.map((t) => {
    const li = document.createElement('li');
    li.className = t.done ? 'done' : '';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = t.done;
    cb.onchange = () => commit(store.toggle(tasks, t.id));
    const span = document.createElement('span');
    span.textContent = t.text;
    const del = document.createElement('button');
    del.className = 'del';
    del.textContent = '✕';
    del.setAttribute('aria-label', 'Удалить');
    del.onclick = () => commit(store.remove(tasks, t.id));
    li.append(cb, span, del);
    return li;
  }));
  $('empty').hidden = shown.length > 0;
  $('clear').hidden = !tasks.some((t) => t.done);
  document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('on', b.dataset.mode === mode));
}

$('form').onsubmit = (e) => {
  e.preventDefault();
  commit(store.add(tasks, $('text').value));
  $('text').value = '';
};
document.querySelectorAll('#tabs button').forEach((b) => (b.onclick = () => { mode = b.dataset.mode; render(); }));
$('clear').onclick = () => commit(store.clearDone(tasks));

let prompt;
window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); prompt = e; $('install').hidden = false; });
$('install').onclick = async () => { if (prompt) { prompt.prompt(); prompt = null; $('install').hidden = true; } };

if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js');
render();
