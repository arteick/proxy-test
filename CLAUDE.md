# Правила проекта
- Структура: src/ — код, tests/ — тесты, docs/ — документация и память (MEMORY.md), docs/chat/ — история диалога с ботом.
- Тесты: npm test (node --test).
- Проект пока пустой: база под новый проект. Стек и команды запуска добавить, когда появятся.
- Стек: Godot 4.3 (GDScript, GL Compatibility, экспорт Web) в godot/. Тесты логики: godot --headless --path godot -s tests/run.gd (CI: godot.yml). npm test — только старый веб-прототип в src/.
