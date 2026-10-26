extends SceneTree
const Ascii = preload("res://scripts/ascii.gd")
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
	quit(1 if fails else 0)
