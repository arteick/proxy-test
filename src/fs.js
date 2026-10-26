// Виртуальная файловая система: дерево директорий и файлов.

const split = (p) => p.split('/').filter(Boolean);

export function createFs(data) {
  return { root: data?.root ?? { type: 'dir', children: {} } };
}

function dirOf(fs, parts) {
  let node = fs.root;
  for (const name of parts) {
    node = node.children[name];
    if (!node || node.type !== 'dir') throw new Error(`Нет директории: ${parts.join('/')}`);
  }
  return node;
}

function checkName(name) {
  if (!name || name === '.' || name === '..' || /[\\]/.test(name)) throw new Error(`Некорректное имя: ${name}`);
}

export function mkdir(fs, path) {
  const parts = split(path);
  const name = parts.pop();
  checkName(name);
  const parent = dirOf(fs, parts);
  if (parent.children[name]) throw new Error(`Уже существует: ${path}`);
  parent.children[name] = { type: 'dir', children: {} };
}

export function createFile(fs, path, content = '') {
  const parts = split(path);
  const name = parts.pop();
  checkName(name);
  const parent = dirOf(fs, parts);
  if (parent.children[name]) throw new Error(`Уже существует: ${path}`);
  parent.children[name] = { type: 'file', content };
}

function nodeAt(fs, path) {
  const parts = split(path);
  const name = parts.pop();
  const node = dirOf(fs, parts).children[name];
  if (!node) throw new Error(`Не найдено: ${path}`);
  return node;
}

export function readFile(fs, path) {
  const n = nodeAt(fs, path);
  if (n.type !== 'file') throw new Error(`Это директория: ${path}`);
  return n.content;
}

export function writeFile(fs, path, content) {
  const n = nodeAt(fs, path);
  if (n.type !== 'file') throw new Error(`Это директория: ${path}`);
  n.content = content;
}

export function isDir(fs, path) {
  return split(path).length === 0 || nodeAt(fs, path).type === 'dir';
}

// Плоский список для отрисовки: директории раньше файлов, по алфавиту.
export function list(fs, path = '') {
  const dir = dirOf(fs, split(path));
  const base = split(path).join('/');
  return Object.entries(dir.children)
    .sort(([an, a], [bn, b]) => (a.type === b.type ? an.localeCompare(bn) : a.type === 'dir' ? -1 : 1))
    .map(([name, n]) => ({ name, path: base ? `${base}/${name}` : name, type: n.type }));
}
