import test from 'node:test';
import assert from 'node:assert/strict';
import * as ed from '../src/editor-core.js';

test('вставка в несколько курсоров сразу', () => {
  let s = ed.create('a\nb\nc', [1, 3, 5]);
  s = ed.insert(s, ';');
  assert.equal(s.text, 'a;\nb;\nc;');
  assert.deepEqual(s.cursors, [2, 5, 8]);
});

test('Backspace и Delete работают на всех курсорах', () => {
  let s = ed.backspace(ed.create('ab\ncd', [2, 5]));
  assert.equal(s.text, 'a\nc');
  s = ed.del(ed.create('xa\nxb', [0, 3]));
  assert.equal(s.text, 'a\nb');
});

test('Enter на нескольких курсорах', () => {
  const s = ed.insert(ed.create('ab cd', [2, 5]), '\n');
  assert.equal(s.text, 'ab\n cd\n');
  assert.deepEqual(s.cursors, [3, 7]);
});

test('соседние курсоры не ломают Backspace', () => {
  const s = ed.backspace(ed.create('abcd', [2, 3]));
  assert.equal(s.text, 'ad');
  assert.deepEqual(s.cursors, [1]);
});

test('курсор выше/ниже и ввод в одной колонке', () => {
  let s = ed.create('aaa\nbbb\nccc', [1]);
  s = ed.addCursorVertical(s, 1);
  s = ed.addCursorVertical(s, 1);
  assert.equal(s.cursors.length, 3);
  s = ed.insert(s, '_');
  assert.equal(s.text, 'a_aa\nb_bb\nc_cc');
});

test('перемещение и границы', () => {
  let s = ed.create('ab\nc', [0]);
  s = ed.moveHorizontal(s, -1);
  assert.deepEqual(s.cursors, [0]);
  s = ed.moveVertical(ed.create('abc\nd', [3]), 1);
  assert.deepEqual(s.cursors, [5]);
});

test('toPos/toOffset взаимно обратны', () => {
  const t = 'ab\ncde\nf';
  for (let i = 0; i <= t.length; i++) {
    const { line, col } = ed.toPos(t, i);
    assert.equal(ed.toOffset(t, line, col), i);
  }
});

const sel = (s) => s.cursors.map((h, i) => [s.anchors[i], h]);

test('Shift+стрелки выделяют, ввод заменяет выделение', () => {
  let s = ed.create('hello world', [0]);
  s = ed.moveHorizontal(s, 1, true);
  s = ed.moveHorizontal(s, 1, true);
  assert.deepEqual(sel(s), [[0, 2]]);
  s = ed.insert(s, 'J');
  assert.equal(s.text, 'Jllo world');
  assert.deepEqual(sel(s), [[1, 1]]);
});

test('стрелка при выделении сворачивает к краю', () => {
  const s = ed.moveHorizontal(ed.selectAll(ed.create('abc')), -1);
  assert.deepEqual(sel(s), [[0, 0]]);
});

test('Ctrl+←/→ по словам, Ctrl+Backspace/Delete', () => {
  const t = 'foo bar.baz';
  assert.equal(ed.moveWord(ed.create(t, [0]), 1).cursors[0], 3);
  assert.equal(ed.moveWord(ed.create(t, [3]), 1).cursors[0], 7);
  assert.equal(ed.moveWord(ed.create(t, [11]), -1).cursors[0], 8);
  assert.equal(ed.deleteWord(ed.create(t, [7]), -1).text, 'foo .baz');
  assert.equal(ed.deleteWord(ed.create(t, [0]), 1).text, ' bar.baz');
});

test('Home/End и края документа', () => {
  const s = ed.create('a\n  bc', [5]);
  const h = ed.lineHome(s);
  assert.equal(h.cursors[0], 4);
  assert.equal(ed.lineHome(h).cursors[0], 2);
  assert.equal(ed.lineEnd(ed.create('ab\ncd', [0])).cursors[0], 2);
  assert.equal(ed.docEdge(s, -1).cursors[0], 0);
  assert.equal(ed.docEdge(s, 1, true).anchors[0], 5);
});

test('Ctrl+A, копирование и вырезание', () => {
  let s = ed.selectAll(ed.create('ab\ncd'));
  assert.equal(ed.copyText(s), 'ab\ncd');
  s = ed.cut(s);
  assert.equal(s.text, '');
  assert.equal(ed.copyText(ed.create('ab\ncd', [4])), 'cd\n');
  assert.equal(ed.cut(ed.create('ab\ncd', [4])).text, 'ab');
});

test('Tab/Shift+Tab: отступ строк', () => {
  let s = ed.indent(ed.selectAll(ed.create('a\nb')));
  assert.equal(s.text, '  a\n  b');
  s = ed.indent(s, -1);
  assert.equal(s.text, 'a\nb');
});

test('Ctrl+/: комментарий вкл/выкл', () => {
  let s = ed.toggleComment(ed.selectAll(ed.create('a\n  b')));
  assert.equal(s.text, '// a\n//   b');
  s = ed.toggleComment(s);
  assert.equal(s.text, 'a\n  b');
});

test('Alt+↑/↓: сдвиг строк', () => {
  let s = ed.moveLines(ed.create('a\nb\nc', [2]), -1);
  assert.equal(s.text, 'b\na\nc');
  assert.deepEqual(s.cursors, [0]);
  s = ed.moveLines(s, 1);
  assert.equal(s.text, 'a\nb\nc');
  assert.equal(ed.moveLines(ed.create('a\nb', [0]), -1).text, 'a\nb');
});

test('Shift+Alt+↑/↓: дублирование строки', () => {
  let s = ed.copyLines(ed.create('a\nb', [0]), 1);
  assert.equal(s.text, 'a\na\nb');
  assert.deepEqual(s.cursors, [2]);
  s = ed.copyLines(ed.create('a\nb', [3]), -1);
  assert.equal(s.text, 'a\nb\nb');
  assert.deepEqual(s.cursors, [3]);
});

test('Ctrl+Shift+K и Ctrl+Enter', () => {
  assert.equal(ed.deleteLines(ed.create('a\nb\nc', [2])).text, 'a\nc');
  assert.equal(ed.deleteLines(ed.create('a\nb', [2])).text, 'a');
  let s = ed.insertLine(ed.create('  a\nb', [3]), 1);
  assert.equal(s.text, '  a\n  \nb');
  assert.deepEqual(s.cursors, [6]);
  s = ed.insertLine(ed.create('  a', [2]), -1);
  assert.equal(s.text, '  \n  a');
  assert.deepEqual(s.cursors, [2]);
});

test('Ctrl+D: слово, затем следующие вхождения; Ctrl+L: строка', () => {
  let s = ed.selectNext(ed.create('foo x foo', [1]));
  assert.deepEqual(sel(s), [[0, 3]]);
  s = ed.selectNext(s);
  assert.deepEqual(sel(s), [[0, 3], [6, 9]]);
  s = ed.insert(s, 'z');
  assert.equal(s.text, 'z x z');
  assert.deepEqual(sel(ed.selectLines(ed.create('ab\ncd', [4]))), [[3, 5]]);
});

test('двойной клик выбирает слово, перетаскивание расширяет', () => {
  assert.deepEqual(sel(ed.selectWord(ed.create('ab cd'), 4)), [[3, 5]]);
  assert.deepEqual(sel(ed.extendTo(ed.create('abcd', [1]), 3)), [[1, 3]]);
});
