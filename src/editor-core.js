// Ядро редактора: текст + несколько курсоров с выделениями.
// state.cursors — позиции курсоров (head), state.anchors — начала выделений
// (равны курсору, если выделения нет). Все правки применяются ко всем курсорам.

const clamp = (v, max) => Math.max(0, Math.min(max, v));

function mk(text, pairs) {
  const byHead = new Map();
  for (const p of pairs) {
    const h = clamp(p.h, text.length);
    byHead.set(h, { a: clamp(p.a, text.length), h });
  }
  const list = [...byHead.values()].sort((x, y) => x.h - y.h);
  return { text, cursors: list.map((p) => p.h), anchors: list.map((p) => p.a) };
}

const pairsOf = (s) => s.cursors.map((h, i) => ({ a: s.anchors?.[i] ?? h, h }));

export function create(text = '', cursors = [0]) {
  return mk(text, cursors.map((c) => ({ a: c, h: c })));
}

export function toPos(text, offset) {
  const before = text.slice(0, offset);
  const line = before.split('\n').length - 1;
  return { line, col: offset - (before.lastIndexOf('\n') + 1) };
}

export function toOffset(text, line, col) {
  const lines = text.split('\n');
  const l = Math.max(0, Math.min(lines.length - 1, line));
  let off = 0;
  for (let i = 0; i < l; i++) off += lines[i].length + 1;
  return off + Math.max(0, Math.min(lines[l].length, col));
}

const lineStarts = (text) => {
  const st = [0];
  for (let i = 0; i < text.length; i++) if (text[i] === '\n') st.push(i + 1);
  return st;
};

// Непересекающиеся диапазоны правки: выделения (слитые) и пустые курсоры.
function spans(state) {
  const raw = pairsOf(state).map((p) => ({ from: Math.min(p.a, p.h), to: Math.max(p.a, p.h) }));
  raw.sort((x, y) => x.from - y.from || x.to - y.to);
  const out = [];
  for (const r of raw) {
    const last = out[out.length - 1];
    if (last && (r.from < last.to || (r.from === last.from && r.to === last.to))) last.to = Math.max(last.to, r.to);
    else out.push({ ...r });
  }
  return out;
}

// edits: непересекающиеся {from, to, text, cur?}, по возрастанию from.
function applyEdits(state, edits) {
  let out = '';
  let prev = 0;
  let shift = 0;
  const pairs = [];
  for (const e of edits) {
    out += state.text.slice(prev, e.from) + e.text;
    const c = e.from + (e.cur ?? e.text.length) + shift;
    pairs.push({ a: c, h: c });
    shift += e.text.length - (e.to - e.from);
    prev = e.to;
  }
  out += state.text.slice(prev);
  return mk(out, pairs);
}

// Новая позиция старой точки p после edits (выделения при этом сохраняются).
function mapPos(edits, p) {
  let shift = 0;
  for (const e of edits) {
    if (e.to <= p) shift += e.text.length - (e.to - e.from);
    else if (e.from < p) return e.from + shift + e.text.length;
    else break;
  }
  return p + shift;
}

function applyLineEdits(state, edits) {
  let out = '';
  let prev = 0;
  for (const e of edits) { out += state.text.slice(prev, e.from) + e.text; prev = e.to; }
  out += state.text.slice(prev);
  return mk(out, pairsOf(state).map((p) => ({ a: mapPos(edits, p.a), h: mapPos(edits, p.h) })));
}

export function insert(state, str) {
  return applyEdits(state, spans(state).map((r) => ({ ...r, text: str })));
}

export function backspace(state) {
  return applyEdits(state, spans(state).map((r) => (r.from < r.to ? { ...r, text: '' } : { from: Math.max(0, r.from - 1), to: r.to, text: '' })));
}

export function del(state) {
  const n = state.text.length;
  return applyEdits(state, spans(state).map((r) => (r.from < r.to ? { ...r, text: '' } : { from: r.from, to: Math.min(n, r.to + 1), text: '' })));
}

// ---- слова ----
const kind = (ch) => (/[\p{L}\p{N}_]/u.test(ch) ? 'w' : /[ \t]/.test(ch) ? 's' : ch === '\n' ? 'n' : 'p');

export function wordEdge(text, i, dir) {
  if (dir > 0) {
    if (text[i] === '\n') return i + 1;
    while (i < text.length && kind(text[i]) === 's') i++;
    if (i >= text.length || text[i] === '\n') return i;
    const k = kind(text[i]);
    while (i < text.length && kind(text[i]) === k) i++;
    return i;
  }
  if (text[i - 1] === '\n') return i - 1;
  while (i > 0 && kind(text[i - 1]) === 's') i--;
  if (i === 0 || text[i - 1] === '\n') return i;
  const k = kind(text[i - 1]);
  while (i > 0 && kind(text[i - 1]) === k) i--;
  return i;
}

function wordAt(text, off) {
  let a = off;
  let b = off;
  while (a > 0 && kind(text[a - 1]) === 'w') a--;
  while (b < text.length && kind(text[b]) === 'w') b++;
  return [a, b];
}

// ---- перемещение ----
// fn(head, pair) -> новая позиция; extend — сохранить якорь (Shift).
function moveBy(state, fn, extend) {
  return mk(state.text, pairsOf(state).map((p) => {
    const h = fn(p.h, p);
    return { a: extend ? p.a : h, h };
  }));
}

export function moveHorizontal(state, dir, extend = false) {
  return mk(state.text, pairsOf(state).map((p) => {
    if (!extend && p.a !== p.h) { const x = dir < 0 ? Math.min(p.a, p.h) : Math.max(p.a, p.h); return { a: x, h: x }; }
    const h = clamp(p.h + dir, state.text.length);
    return { a: extend ? p.a : h, h };
  }));
}

export function moveWord(state, dir, extend = false) {
  return moveBy(state, (h) => wordEdge(state.text, h, dir), extend);
}

export function moveVertical(state, dir, extend = false, lines = 1) {
  return moveBy(state, (h) => {
    const { line, col } = toPos(state.text, h);
    return toOffset(state.text, line + dir * lines, col);
  }, extend);
}

// Home: сначала к первому непробельному символу, повторно — к началу строки.
export function lineHome(state, extend = false) {
  return moveBy(state, (h) => {
    const { line, col } = toPos(state.text, h);
    const t = state.text.split('\n')[line];
    const first = t.length - t.trimStart().length;
    return toOffset(state.text, line, col === first ? 0 : first);
  }, extend);
}

export function lineEnd(state, extend = false) {
  return moveBy(state, (h) => toOffset(state.text, toPos(state.text, h).line, Infinity), extend);
}

export function docEdge(state, dir, extend = false) {
  return moveBy(state, () => (dir < 0 ? 0 : state.text.length), extend);
}

// ---- выделение ----
export function selectAll(state) {
  return mk(state.text, [{ a: 0, h: state.text.length }]);
}

export function selectWord(state, offset) {
  const [a, b] = wordAt(state.text, offset);
  return mk(state.text, [{ a, h: b }]);
}

export function selectLines(state) {
  const st = lineStarts(state.text);
  return mk(state.text, linesTouched(state, st).map(([s, e]) => ({
    a: st[s],
    h: e + 1 < st.length ? st[e + 1] : state.text.length,
  })));
}

// Ctrl+D: выделить слово, затем добавить следующее такое же вхождение.
export function selectNext(state) {
  const pairs = pairsOf(state);
  const last = pairs[pairs.length - 1];
  if (last.a === last.h) {
    const [a, b] = wordAt(state.text, last.h);
    return a === b ? state : mk(state.text, [...pairs.slice(0, -1), { a, h: b }]);
  }
  const from = Math.min(last.a, last.h);
  const to = Math.max(last.a, last.h);
  const needle = state.text.slice(from, to);
  const taken = new Set(pairs.map((p) => Math.min(p.a, p.h)));
  let i = state.text.indexOf(needle, to);
  if (i < 0) i = state.text.indexOf(needle);
  if (i < 0 || taken.has(i)) return state;
  return mk(state.text, [...pairs, { a: i, h: i + needle.length }]);
}

export function extendTo(state, offset) {
  const pairs = pairsOf(state);
  pairs[pairs.length - 1].h = offset;
  return mk(state.text, pairs);
}

export function hasSelection(state) {
  return state.cursors.some((h, i) => state.anchors[i] !== h);
}

// Текст для копирования: выделения; без выделения — строки с курсорами.
export function copyText(state) {
  if (hasSelection(state)) return spans(state).filter((r) => r.from < r.to).map((r) => state.text.slice(r.from, r.to)).join('\n');
  const lines = state.text.split('\n');
  return linesTouched(state).map(([s, e]) => lines.slice(s, e + 1).join('\n') + '\n').join('');
}

export function cut(state) {
  return hasSelection(state) ? backspace(state) : deleteLines(state);
}

export function addCursorVertical(state, dir) {
  const added = state.cursors.map((c) => {
    const { line, col } = toPos(state.text, c);
    return toOffset(state.text, line + dir, col);
  });
  return mk(state.text, [...pairsOf(state), ...added.map((c) => ({ a: c, h: c }))]);
}

export function addCursorAt(state, offset) {
  return mk(state.text, [...pairsOf(state), { a: offset, h: offset }]);
}

export function setCursor(state, offset) {
  return mk(state.text, [{ a: offset, h: offset }]);
}

// Esc: один курсор без выделения.
export function collapse(state) {
  const h = state.cursors[0];
  return mk(state.text, [{ a: h, h }]);
}

// ---- удаление слов ----
export function deleteWord(state, dir) {
  return applyEdits(state, spans(state).map((r) => {
    if (r.from < r.to) return { ...r, text: '' };
    return dir < 0
      ? { from: wordEdge(state.text, r.from, -1), to: r.to, text: '' }
      : { from: r.from, to: wordEdge(state.text, r.to, 1), text: '' };
  }));
}

// ---- строки ----
// Группы подряд идущих строк, затронутых курсорами/выделениями: [[с, по], ...].
function linesTouched(state, st = lineStarts(state.text)) {
  const lineOf = (off) => { let l = 0; while (l + 1 < st.length && st[l + 1] <= off) l++; return l; };
  const set = new Set();
  for (const r of spans(state)) {
    const l1 = lineOf(r.from);
    let l2 = lineOf(r.to);
    if (r.to > r.from && r.to === st[l2] && l2 > l1) l2--;
    for (let l = l1; l <= l2; l++) set.add(l);
  }
  const groups = [];
  for (const l of [...set].sort((x, y) => x - y)) {
    const g = groups[groups.length - 1];
    if (g && g[1] === l - 1) g[1] = l; else groups.push([l, l]);
  }
  return groups;
}

export function indent(state, dir = 1) {
  const st = lineStarts(state.text);
  const edits = [];
  for (const [s, e] of linesTouched(state, st)) {
    for (let l = s; l <= e; l++) {
      if (dir > 0) edits.push({ from: st[l], to: st[l], text: '  ' });
      else {
        const m = /^( {1,2}|\t)/.exec(state.text.slice(st[l], st[l] + 2));
        if (m) edits.push({ from: st[l], to: st[l] + m[0].length, text: '' });
      }
    }
  }
  return applyLineEdits(state, edits);
}

// Ctrl+/: переключить комментарий «//» на затронутых строках.
export function toggleComment(state) {
  const st = lineStarts(state.text);
  const lines = state.text.split('\n');
  const ids = linesTouched(state, st).flatMap(([s, e]) => Array.from({ length: e - s + 1 }, (_, i) => s + i));
  const real = ids.filter((l) => lines[l].trim());
  const target = real.length ? real : ids;
  const edits = [];
  if (real.length && real.every((l) => /^\s*\/\//.test(lines[l]))) {
    for (const l of target) {
      const m = /^(\s*)\/\/ ?/.exec(lines[l]);
      edits.push({ from: st[l] + m[1].length, to: st[l] + m[0].length, text: '' });
    }
  } else {
    const col = Math.min(...target.map((l) => lines[l].length - lines[l].trimStart().length));
    for (const l of target) edits.push({ from: st[l] + Math.min(col, lines[l].length), to: st[l] + Math.min(col, lines[l].length), text: '// ' });
  }
  return applyLineEdits(state, edits);
}

// Alt+↑/↓: сдвинуть затронутые строки.
export function moveLines(state, dir) {
  const st = lineStarts(state.text);
  const groups = linesTouched(state, st);
  const items = state.text.split('\n').map((t, id) => ({ t, id }));
  for (const [s0, e0] of dir < 0 ? groups : [...groups].reverse()) {
    const s = items.findIndex((x) => x.id === s0);
    const e = items.findIndex((x) => x.id === e0);
    if (dir < 0 && s > 0) items.splice(e, 0, items.splice(s - 1, 1)[0]);
    else if (dir > 0 && e < items.length - 1) items.splice(s, 0, items.splice(e + 1, 1)[0]);
  }
  const text = items.map((x) => x.t).join('\n');
  const ns = lineStarts(text);
  const map = (off) => {
    const { line, col } = toPos(state.text, off);
    return ns[items.findIndex((x) => x.id === line)] + col;
  };
  return mk(text, pairsOf(state).map((p) => ({ a: map(p.a), h: map(p.h) })));
}

// Shift+Alt+↑/↓: дублировать затронутые строки (курсор остаётся выше/уходит на копию).
export function copyLines(state, dir) {
  const st = lineStarts(state.text);
  const groups = linesTouched(state, st);
  const ends = (e) => (e + 1 < st.length ? st[e + 1] - 1 : state.text.length);
  let out = '';
  let prev = 0;
  const bounds = [];
  let shift = 0;
  for (const [s, e] of groups) {
    const block = state.text.slice(st[s], ends(e));
    out += state.text.slice(prev, st[s]) + block + '\n';
    bounds.push({ from: st[s], to: ends(e), len: block.length + 1, shift });
    shift += block.length + 1;
    prev = st[s];
  }
  out += state.text.slice(prev);
  const map = (off) => {
    const b = bounds.find((x) => off >= x.from && off <= x.to);
    return off + b.shift + (dir > 0 ? b.len : 0);
  };
  return mk(out, pairsOf(state).map((p) => ({ a: map(p.a), h: map(p.h) })));
}

// Ctrl+Shift+K
export function deleteLines(state) {
  const st = lineStarts(state.text);
  return applyEdits(state, linesTouched(state, st).map(([s, e]) => {
    const last = e + 1 >= st.length;
    return { from: last && s > 0 ? st[s] - 1 : st[s], to: last ? state.text.length : st[e + 1], text: '' };
  }));
}

// Ctrl+Enter / Ctrl+Shift+Enter: новая строка под/над текущей (с отступом).
export function insertLine(state, dir) {
  const st = lineStarts(state.text);
  const lines = state.text.split('\n');
  return applyEdits(state, linesTouched(state, st).map(([s, e]) => {
    const ind = /^\s*/.exec(lines[dir > 0 ? e : s])[0];
    if (dir > 0) {
      const at = e + 1 < st.length ? st[e + 1] - 1 : state.text.length;
      return { from: at, to: at, text: '\n' + ind };
    }
    return { from: st[s], to: st[s], text: ind + '\n', cur: ind.length };
  }));
}
