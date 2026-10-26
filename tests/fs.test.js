import test from 'node:test';
import assert from 'node:assert/strict';
import * as fs from '../src/fs.js';

test('директории, вложенные файлы, чтение и запись', () => {
  const f = fs.createFs();
  fs.mkdir(f, 'src');
  fs.mkdir(f, 'src/lib');
  fs.createFile(f, 'src/lib/a.js', 'x');
  fs.writeFile(f, 'src/lib/a.js', 'y');
  assert.equal(fs.readFile(f, 'src/lib/a.js'), 'y');
  assert.deepEqual(fs.list(f, 'src').map((e) => e.path), ['src/lib']);
});

test('ошибки: нет родителя, дубликат, плохое имя', () => {
  const f = fs.createFs();
  assert.throws(() => fs.createFile(f, 'no/a.js'));
  fs.createFile(f, 'a.js');
  assert.throws(() => fs.createFile(f, 'a.js'));
  assert.throws(() => fs.mkdir(f, '..'));
});

test('директории идут перед файлами', () => {
  const f = fs.createFs();
  fs.createFile(f, 'a.txt');
  fs.mkdir(f, 'z');
  assert.deepEqual(fs.list(f).map((e) => e.name), ['z', 'a.txt']);
});

test('сериализация через JSON', () => {
  const f = fs.createFs();
  fs.createFile(f, 'a', 'q');
  const g = fs.createFs(JSON.parse(JSON.stringify(f)));
  assert.equal(fs.readFile(g, 'a'), 'q');
});
