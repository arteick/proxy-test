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
  undoStack = []; redoStack = []; lastKind = '';
  state = ed.create(vfs.readFile(fs, path));
  renderEditor();
  $('input').focus();
}

function renderEditor() {
  const box = $('editor');
  $('tab').textContent = current ?? 'Файл не выбран';
  if (current === null) return;
  const lines = state.text.split('\n');
  const starts = [];
  let acc = 0;
  for (const l of lines) { starts.push(acc); acc += l.length + 1; }
  const marks = lines.map(() => ({ cur: [], sel: [] }));
  state.cursors.forEach((h, i) => {
    const { line, col } = ed.toPos(state.text, h);
    marks[line].cur.push(col);
    const from = Math.min(h, state.anchors[i]);
    const to = Math.max(h, state.anchors[i]);
    for (let l = 0; l < lines.length; l++) {
      const s = Math.max(from, starts[l]);
      const e = Math.min(to, starts[l] + lines[l].length);
      if (e > s) marks[l].sel.push([s - starts[l], e - starts[l]]);
    }
  });
  box.textContent = '';
  lines.forEach((text, i) => {
    const m = marks[i];
    const row = document.createElement('div');
    row.className = 'line' + (m.cur.length ? ' has-cursor' : '');
    const num = document.createElement('span');
    num.className = 'num';
    num.textContent = i + 1;
    const t = document.createElement('span');
    t.className = 'text';
    t.dataset.line = i;
    const cuts = new Set([0, text.length, ...m.cur, ...m.sel.flat()]);
    const pts = [...cuts].sort((x, y) => x - y);
    for (let k = 0; k < pts.length; k++) {
      const at = pts[k];
      for (const c of m.cur) if (c === at) { const cur = document.createElement('i'); cur.className = 'cur'; t.append(cur); }
      const end = pts[k + 1];
      if (end === undefined) break;
      const piece = text.slice(at, end);
      if (m.sel.some(([s, e]) => s <= at && e >= end)) {
        const sp = document.createElement('span');
        sp.className = 'sel';
        sp.textContent = piece;
        t.append(sp);
      } else t.append(document.createTextNode(piece));
    }
    if (!text) t.append(document.createTextNode('​'));
    row.append(num, t);
    box.append(row);
  });
  box.querySelector('.cur')?.scrollIntoView({ block: 'nearest' });
}

let undoStack = [];
let redoStack = [];
let lastKind = '';

function update(next, kind = '') {
  // подряд идущий набор символов — один шаг отмены
  if (!(kind && kind === lastKind)) undoStack.push(state);
  if (undoStack.length > 500) undoStack.shift();
  redoStack = [];
  lastKind = kind;
  state = next;
  vfs.writeFile(fs, current, state.text);
  save();
  renderEditor();
}

function moveOnly(next) { state = next; lastKind = ''; renderEditor(); }

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

let dragging = false;

$('editor').addEventListener('mousedown', (e) => {
  e.preventDefault();
  if (current === null) return;
  $('input').focus();
  let o = offsetFromPoint(e.clientX, e.clientY);
  if (o === null) o = state.text.length;
  if (e.detail >= 3) return moveOnly(ed.selectLines(ed.setCursor(state, o)));
  if (e.detail === 2) return moveOnly(ed.selectWord(state, o));
  dragging = true;
  if (e.altKey) moveOnly(ed.addCursorAt(state, o));
  else if (e.shiftKey) moveOnly(ed.extendTo(state, o));
  else moveOnly(ed.setCursor(state, o));
});
document.addEventListener('mousemove', (e) => {
  if (!dragging || !(e.buttons & 1)) { dragging = false; return; }
  const o = offsetFromPoint(e.clientX, e.clientY);
  if (o !== null && o !== state.cursors.at(-1)) moveOnly(ed.extendTo(state, o));
});
document.addEventListener('mouseup', () => { dragging = false; });

function copyToClipboard(text) {
  navigator.clipboard?.writeText(text).catch(() => {});
}

function undo() {
  if (!undoStack.length) return;
  redoStack.push(state);
  state = undoStack.pop();
  lastKind = '';
  vfs.writeFile(fs, current, state.text);
  save();
  renderEditor();
}

function redo() {
  if (!redoStack.length) return;
  undoStack.push(state);
  state = redoStack.pop();
  lastKind = '';
  vfs.writeFile(fs, current, state.text);
  save();
  renderEditor();
}

$('input').addEventListener('keydown', (e) => {
  if (current === null || e.isComposing) return;
  const k = e.key;
  const code = e.code;
  const mod = e.ctrlKey || e.metaKey;
  const { shiftKey: shift, altKey: alt } = e;
  let handled = true;
  if (mod && alt && (k === 'ArrowUp' || k === 'ArrowDown')) moveOnly(ed.addCursorVertical(state, k === 'ArrowUp' ? -1 : 1));
  else if (alt && !mod && (k === 'ArrowUp' || k === 'ArrowDown')) update(shift ? ed.copyLines(state, k === 'ArrowUp' ? -1 : 1) : ed.moveLines(state, k === 'ArrowUp' ? -1 : 1));
  else if (mod && code === 'KeyZ') (shift ? redo : undo)();
  else if (mod && code === 'KeyY') redo();
  else if (mod && code === 'KeyA') moveOnly(ed.selectAll(state));
  else if (mod && code === 'KeyC') copyToClipboard(ed.copyText(state));
  else if (mod && code === 'KeyX') { copyToClipboard(ed.copyText(state)); update(ed.cut(state)); }
  else if (mod && code === 'KeyV') handled = false; // вставка придёт событием input
  else if (mod && code === 'KeyS') save();
  else if (mod && code === 'KeyD') moveOnly(ed.selectNext(state));
  else if (mod && code === 'KeyL') moveOnly(ed.selectLines(state));
  else if (mod && code === 'Slash') update(ed.toggleComment(state));
  else if (mod && code === 'BracketRight') update(ed.indent(state, 1));
  else if (mod && code === 'BracketLeft') update(ed.indent(state, -1));
  else if (mod && shift && code === 'KeyK') update(ed.deleteLines(state));
  else if (mod && k === 'Enter') update(ed.insertLine(state, shift ? -1 : 1));
  else if (mod && k === 'Home') moveOnly(ed.docEdge(state, -1, shift));
  else if (mod && k === 'End') moveOnly(ed.docEdge(state, 1, shift));
  else if (mod && k === 'ArrowLeft') moveOnly(ed.moveWord(state, -1, shift));
  else if (mod && k === 'ArrowRight') moveOnly(ed.moveWord(state, 1, shift));
  else if (mod && k === 'Backspace') update(ed.deleteWord(state, -1));
  else if (mod && k === 'Delete') update(ed.deleteWord(state, 1));
  else if (mod || alt) handled = false;
  else if (k === 'Escape') moveOnly(ed.collapse(state));
  else if (k === 'ArrowLeft') moveOnly(ed.moveHorizontal(state, -1, shift));
  else if (k === 'ArrowRight') moveOnly(ed.moveHorizontal(state, 1, shift));
  else if (k === 'ArrowUp') moveOnly(ed.moveVertical(state, -1, shift));
  else if (k === 'ArrowDown') moveOnly(ed.moveVertical(state, 1, shift));
  else if (k === 'PageUp') moveOnly(ed.moveVertical(state, -1, shift, 20));
  else if (k === 'PageDown') moveOnly(ed.moveVertical(state, 1, shift, 20));
  else if (k === 'Home') moveOnly(ed.lineHome(state, shift));
  else if (k === 'End') moveOnly(ed.lineEnd(state, shift));
  else if (k === 'Backspace') update(ed.backspace(state), 'del');
  else if (k === 'Delete') update(ed.del(state), 'del');
  else if (k === 'Enter') update(ed.insert(state, '\n'));
  else if (k === 'Tab') {
    const multi = ed.hasSelection(state) && ed.copyText(state).includes('\n');
    update(shift || multi ? ed.indent(state, shift ? -1 : 1) : ed.insert(state, '  '));
  } else handled = false;
  if (handled) e.preventDefault();
});

// Печатаемый ввод (включая IME и вставку) приходит через input.
$('input').addEventListener('input', (e) => {
  const v = e.target.value;
  e.target.value = '';
  if (current !== null && v) update(ed.insert(state, v.replace(/\r\n?/g, '\n')), v.length === 1 ? 'type' : '');
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
