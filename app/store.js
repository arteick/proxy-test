// Логика задач без привязки к браузеру: тестируется на Node.
export const KEY = 'tasks.v1';

export function load(storage) {
  try {
    const list = JSON.parse(storage.getItem(KEY) || '[]');
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

export function save(storage, tasks) {
  storage.setItem(KEY, JSON.stringify(tasks));
}

export function add(tasks, text, now = Date.now()) {
  const t = String(text ?? '').trim();
  if (!t) return tasks;
  return [{ id: `${now}-${tasks.length}`, text: t, done: false }, ...tasks];
}

export function toggle(tasks, id) {
  return tasks.map((x) => (x.id === id ? { ...x, done: !x.done } : x));
}

export function remove(tasks, id) {
  return tasks.filter((x) => x.id !== id);
}

export function clearDone(tasks) {
  return tasks.filter((x) => !x.done);
}

export function filter(tasks, mode) {
  if (mode === 'active') return tasks.filter((x) => !x.done);
  if (mode === 'done') return tasks.filter((x) => x.done);
  return tasks;
}
