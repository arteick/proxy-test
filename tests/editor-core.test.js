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
