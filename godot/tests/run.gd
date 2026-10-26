extends SceneTree
const Ascii = preload("res://scripts/ascii.gd")
const Move = preload("res://scripts/move.gd")
const Game = preload("res://scripts/game.gd")
const Hero = preload("res://scripts/hero.gd")
const Hud = preload("res://scripts/hud.gd")
const Level = preload("res://scripts/level.gd")
const Actors = preload("res://scripts/actors.gd")
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
	var tc := Move.top_down_cam(Vector3.ZERO, 0.0, 1.0)
	check(tc.y > 12.0 and tc.z > 0.0 and tc.z < 3.0, "камера: вид сверху, почти над героем")
	var lk := Move.look(0.0, 0.5, Vector2(100, 0), 0.01)
	check(is_equal_approx(lk.x, -1.0) and is_equal_approx(lk.y, 0.5), "камера: мышь вправо поворачивает yaw")
	check(is_equal_approx(Move.look(0.0, 0.5, Vector2(0, 1000), 0.01).y, Move.PITCH_MAX) and is_equal_approx(Move.look(0.0, 0.5, Vector2(0, -1000), 0.01).y, Move.PITCH_MIN), "камера: наклон ограничен")
	var g := Game.new(7)
	check(g.crystals.size() == Game.CRYSTALS and g.enemies.size() == Game.ENEMIES, "игра: старт, кристаллы и тени")
	check(Game.new(7).crystals == g.crystals and Game.new(8).crystals != g.crystals, "игра: seed детерминирован")
	var c0: Vector2 = g.crystals[0]
	g.enemies = [Vector2(500, 500)]
	g.homes = g.enemies.duplicate()
	var ev := g.update(Vector3(c0.x, 0, c0.y), 0.016)
	check(ev.has("pick") and g.score == 1 and g.crystals.size() == Game.CRYSTALS - 1, "игра: подбор кристалла")
	g.enemies = [Vector2(0, 0)]
	g.homes = g.enemies.duplicate()
	var far_hero := Vector3(0, 0, 8)
	g.update(far_hero, 1.0)
	check(g.enemies[0].y > 2.0 and g.enemies[0].y < 4.0, "игра: тень идёт к герою со своей скоростью")
	g.enemies = [Vector2(0, 8)]
	check(g.update(far_hero, 0.016).has("hurt") and g.hp == Game.HP_MAX - 1, "игра: касание тени отнимает жизнь")
	g.update(far_hero, 0.016)
	check(g.hp == Game.HP_MAX - 1, "игра: неуязвимость после удара")
	g.hp = 1; g.hurt_cd = 0.0
	check(g.update(far_hero, 0.016).has("lose") and g.state == "lose", "игра: поражение")
	check(g.update(far_hero, 1.0).is_empty(), "игра: после конца события не идут")
	var w := Game.new(3)
	w.enemies = []; w.homes = []
	var evs: Array = []
	for c in w.crystals.duplicate():
		evs = w.update(Vector3(c.x, 0, c.y), 0.016)
	check(w.state == "win" and evs.has("win"), "игра: победа после последнего кристалла")
	var hero := Hero.new()
	hero._ready()
	check(hero.cape_segs.size() == Hero.CAPE_SEGS and hero.get_child_count() > 2, "герой: модель собирается")
	hero.animate(0.1, true, 0.1)
	check(hero.amp > 0.0 and hero.staff.rotation.x != 0.0, "герой: анимация ходьбы двигает суставы")
	var gh := Game.new(1)
	var txt := Hud.text(gh, Vector3.ZERO)
	check(txt.contains("Кристаллы 0/8") and txt.contains("♥♥♥") and txt.contains("Ближайший"), "HUD: счёт, жизни, подсказка")
	gh.state = "win"
	check(Hud.text(gh, Vector3.ZERO).contains("Победа"), "HUD: победа")
	gh.state = "lose"; gh.hp = 0
	check(Hud.text(gh, Vector3.ZERO).contains("Тени взяли") and Hud.text(gh, Vector3.ZERO).contains("···"), "HUD: поражение, жизни не уходят в минус")
	var root := Node3D.new()
	var fi := Level.floor_image()
	check(fi.get_width() == Level.TILE * 8 and fi.get_pixel(5, 5) != fi.get_pixel(40, 40), "пол: текстура с вариацией")
	check(Level.build(root).size() == Level.COLUMNS and root.get_child_count() == Level.COLUMNS + 1, "уровень: колонны и коллайдеры")
	check(Actors.spawn_crystals(root, Game.new(2).crystals).size() == Game.CRYSTALS and Actors.spawn_enemies(root, Game.new(2).enemies).size() == Game.ENEMIES, "узлы: кристаллы и тени")
	root.free()
	quit(1 if fails else 0)
