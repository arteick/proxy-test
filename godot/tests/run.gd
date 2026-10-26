extends SceneTree
const Ascii = preload("res://scripts/ascii.gd")
const Move = preload("res://scripts/move.gd")
# Запуск: godot --headless --path godot -s tests/run.gd

var fails := 0

func check(ok: bool, name: String) -> void:
	print(("ok   " if ok else "FAIL ") + name)
	if not ok: fails += 1

func _init() -> void:
	check(Ascii.glyph_index(0.0) == 0, "яркость 0 -> пробел")
	check(Ascii.glyph_index(1.0) == Ascii.RAMP.length() - 1, "яркость 1 -> самый плотный")
	check(Ascii.glyph_index(-5.0) == 0 and Ascii.glyph_index(7.0) == Ascii.RAMP.length() - 1, "клэмп")
	check(Ascii.glyph_index(0.5) > Ascii.glyph_index(0.2), "монотонность")
	check(Ascii.cell_fade(1, 5, 20) == 0.0 and Ascii.cell_fade(50, 5, 20) == 1.0, "затухание: края")
	check(Ascii.cell_fade(12, 5, 20) > Ascii.cell_fade(8, 5, 20), "затухание растёт с расстоянием")
	check(Move.wish_dir(Vector2.ZERO, 0.0) == Vector3.ZERO, "движение: нет ввода")
	check(Move.wish_dir(Vector2(0, 1), 0.0).is_equal_approx(Vector3(0, 0, -1)), "движение: W идёт вперёд (-Z)")
	check(Move.wish_dir(Vector2(1, 1), 0.0).length() > 0.99 and Move.wish_dir(Vector2(1, 1), 0.0).length() < 1.01, "движение: диагональ нормализована")
	var wall := [Vector3(0, 0, 1.0)]
	var p := Move.step(Vector3(0, 0, 3), Vector3(0, 0, -1), 2.0, 1.0, 0.5, wall)
	check(p.z >= 1.5 - 0.001, "коллизия: не заходит в колонну")
	check(Move.step(Vector3(5, 0, 5), Vector3(1, 0, 0), 2.0, 0.5, 0.5, wall).x == 6.0, "движение без препятствий")
	quit(1 if fails else 0)
