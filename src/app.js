import * as ed from './editor-core.js';
import * as vfs from './fs.js';

const KEY = 'online-editor-fs';
const $ = (id) => document.getElementById(id);

let fs;
try { fs = vfs.createFs(JSON.parse(localStorage.getItem(KEY))); } catch { fs = vfs.createFs(); }
if (vfs.list(fs).length === 0) {
  vfs.mkdir(fs, 'src');
  vfs.createFile(fs, 'src/main.js', 'console.log("Привет!");\nconsole.log("Привет!");\nconsole.log("Привет!");\n');
  vfs.createFile(fs, 'README.md', '# Проект\n');
}

let current = null;   // путь открытого файла
let target = '';      // выбранная директория (куда создавать)
let state = ed.create('');
const open = new Set(['src']);

const save = () => { try { localStorage.setItem(KEY, JSON.stringify(fs)); } catch {} };

function renderTree() {
  const tree = $('tree');
  tree.textContent = '';
  const walk = (path, depth) => {
    for (const e of vfs.list(fs, path)) {
      const div = document.createElement('div');
      div.className = 'item' + (e.path === current ? ' active' : '') + (e.path === target ? ' target' : '');
      div.style.paddingLeft = 8 + depth * 14 + 'px';
      div.textContent = (e.type === 'dir' ? (open.has(e.path) ? '▾ 📁 ' : '▸ 📁 ') : '📄 ') + e.name;
      div.onclick = () => {
        if (e.type === 'dir') {
          open.has(e.path) ? open.delete(e.path) : open.add(e.path);
          target = e.path;
        } else {
          openFile(e.path);
          target = e.path.split('/').slice(0, -1).join('/');
        }
        renderTree();
      };
      tree.append(div);
      if (e.type === 'dir' && open.has(e.path)) walk(e.path, depth + 1);
    }
  };
  walk('', 0);
}

function openFile(path) {
  current = path;
  state = ed.create(vfs.readFile(fs, path));
  renderEditor();
  $('input').focus();
}

function renderEditor() {
  const box = $('editor');
  $('tab').textContent = current ?? 'Файл не выбран';
  if (current === null) return;
  const lines = state.text.split('\n');
  const byLine = lines.map(() => []);
  for (const c of state.cursors) {
    const { line, col } = ed.toPos(state.text, c);
    byLine[line].push(col);
  }
  box.textContent = '';
  lines.forEach((text, i) => {
    const row = document.createElement('div');
    row.className = 'line' + (byLine[i].length ? ' has-cursor' : '');
    const num = document.createElement('span');
    num.className = 'num';
    num.textContent = i + 1;
    const t = document.createElement('span');
    t.className = 'text';
    t.dataset.line = i;
    let prev = 0;
    for (const col of byLine[i]) {
      t.append(document.createTextNode(text.slice(prev, col)));
      const cur = document.createElement('i');
      cur.className = 'cur';
      t.append(cur);
      prev = col;
    }
    t.append(document.createTextNode(text.slice(prev) || (byLine[i].length ? '' : '​')));
    row.append(num, t);
    box.append(row);
  });
}

function update(next) {
  state = next;
  vfs.writeFile(fs, current, state.text);
  save();
  renderEditor();
}

function moveOnly(next) { state = next; renderEditor(); }

// Смещение в тексте по точке клика.
function offsetFromPoint(x, y) {
  const pos = document.caretPositionFromPoint?.(x, y);
  let node, off;
  if (pos) { node = pos.offsetNode; off = pos.offset; }
  else {
    const r = document.caretRangeFromPoint?.(x, y);
    if (!r) return null;
    node = r.startContainer; off = r.startOffset;
  }
  const el = (node.nodeType === 3 ? node.parentElement : node)?.closest?.('.text');
  if (!el) return null;
  const range = document.createRange();
  range.setStart(el, 0);
  range.setEnd(node, node.nodeType === 3 ? off : 0);
  const col = range.toString().replace(/​/g, '').length;
  return ed.toOffset(state.text, Number(el.dataset.line), col);
}

$('editor').addEventListener('mousedown', (e) => {
  e.preventDefault();
  if (current === null) return;
  $('input').focus();
  let o = offsetFromPoint(e.clientX, e.clientY);
  if (o === null) o = state.text.length;
  moveOnly(e.altKey ? ed.addCursorAt(state, o) : ed.setCursor(state, o));
});

$('input').addEventListener('keydown', (e) => {
  if (current === null || e.isComposing) return;
  const k = e.key;
  let handled = true;
  if (e.ctrlKey && e.altKey && (k === 'ArrowUp' || k === 'ArrowDown')) moveOnly(ed.addCursorVertical(state, k === 'ArrowUp' ? -1 : 1));
  else if (k === 'Escape') moveOnly(ed.collapse(state));
  else if (k === 'ArrowLeft') moveOnly(ed.moveHorizontal(state, -1));
  else if (k === 'ArrowRight') moveOnly(ed.moveHorizontal(state, 1));
  else if (k === 'ArrowUp') moveOnly(ed.moveVertical(state, -1));
  else if (k === 'ArrowDown') moveOnly(ed.moveVertical(state, 1));
  else if (k === 'Backspace') update(ed.backspace(state));
  else if (k === 'Delete') update(ed.del(state));
  else if (k === 'Enter') update(ed.insert(state, '\n'));
  else if (k === 'Tab') update(ed.insert(state, '  '));
  else handled = false;
  if (handled) e.preventDefault();
});

// Печатаемый ввод (включая IME и вставку) приходит через input.
$('input').addEventListener('input', (e) => {
  const v = e.target.value;
  e.target.value = '';
  if (current !== null && v) update(ed.insert(state, v.replace(/\r\n?/g, '\n')));
});

function create(kind) {
  const name = prompt(kind === 'dir' ? 'Имя папки' : 'Имя файла');
  if (!name) return;
  const path = (target ? target + '/' : '') + name.trim();
  try {
    if (kind === 'dir') { vfs.mkdir(fs, path); open.add(path); target = path; }
    else { vfs.createFile(fs, path); open.add(target); save(); renderTree(); openFile(path); return; }
    save();
  } catch (err) { alert(err.message); }
  renderTree();
}
$('newFile').onclick = () => create('file');
$('newDir').onclick = () => create('dir');

renderTree();
