# PROGRESS
- 2026-10-26: ASCII-прототип (Three.js): сцена, персонаж, шейдер-постобработка, затухание символов по глубине. npm test 2/2; headless-скриншот проверен. Pages workflow восстановлен.
- 2026-10-26: каркас Godot 4.3 в godot/ (проект, сцена, ASCII-шейдер, атлас, тесты логики, workflow godot.yml). НЕ запускалось: Godot в песочнице нет. npm test 2/2 (старый код). Проверит CI.
- 2026-10-26: CI godot.yml первый прогон упал на тестах (Identifier "Ascii" not declared). Исправлено preload-константами. Добавлены scripts/move.gd (wish_dir, resolve, step) + 5 тестов, WASD и следящая камера в world.gd. Godot локально нет; итог CI — в Actions (прогон на коммите «управление героем»).
- 2026-10-26: CI: тесты логики зелёные (на коммите до WASD), экспорт Web чинился: копирование шаблонов в ~/.local/share/godot и полный export_presets.cfg. Итог последнего прогона не подтверждён.
