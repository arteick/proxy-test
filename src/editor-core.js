// Ядро редактора: текст + несколько курсоров (смещения в строке текста).
// Все правки применяются ко всем курсорам одновременно.

export function create(text = '', cursors = [0]) {
  return { text, cursors: normalize(cursors, text.length) };
}

function normalize(cursors, max) {
  const set = new Set(cursors.map((c) => Math.max(0, Math.min(max, c))));
  return [...set].sort((a, b) => a - b);
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

// edits: непересекающиеся {from, to, text}, по возрастанию from.
function applyEdits(state, edits) {
  let out = '';
  let prev = 0;
  let shift = 0;
  const cursors = [];
  for (const e of edits) {
    out += state.text.slice(prev, e.from) + e.text;
    cursors.push(e.from + e.text.length + shift);
    shift += e.text.length - (e.to - e.from);
    prev = e.to;
  }
  out += state.text.slice(prev);
  return { text: out, cursors: normalize(cursors, out.length) };
}

export function insert(state, str) {
  return applyEdits(state, state.cursors.map((c) => ({ from: c, to: c, text: str })));
}

export function backspace(state) {
  return applyEdits(
    state,
    state.cursors.map((c) => ({ from: Math.max(0, c - 1), to: c, text: '' })),
  );
}

export function del(state) {
  const n = state.text.length;
  return applyEdits(
    state,
    state.cursors.map((c) => ({ from: c, to: Math.min(n, c + 1), text: '' })),
  );
}

export function moveHorizontal(state, dir) {
  return { ...state, cursors: normalize(state.cursors.map((c) => c + dir), state.text.length) };
}

export function moveVertical(state, dir) {
  const cursors = state.cursors.map((c) => {
    const { line, col } = toPos(state.text, c);
    return toOffset(state.text, line + dir, col);
  });
  return { ...state, cursors: normalize(cursors, state.text.length) };
}

// Добавить курсор строкой выше/ниже каждого существующего (в той же колонке).
export function addCursorVertical(state, dir) {
  const added = state.cursors.map((c) => {
    const { line, col } = toPos(state.text, c);
    return toOffset(state.text, line + dir, col);
  });
  return { ...state, cursors: normalize([...state.cursors, ...added], state.text.length) };
}

export function addCursorAt(state, offset) {
  return { ...state, cursors: normalize([...state.cursors, offset], state.text.length) };
}

export function setCursor(state, offset) {
  return { ...state, cursors: normalize([offset], state.text.length) };
}

export function collapse(state) {
  return { ...state, cursors: state.cursors.slice(0, 1) };
}
