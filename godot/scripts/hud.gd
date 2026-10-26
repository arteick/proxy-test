# Текст HUD без зависимости от сцены (тестируется headless).
const Game = preload("res://scripts/game.gd")

static func text(game: Game, hero: Vector3) -> String:
	var hp := maxi(game.hp, 0)
	var line := "Кристаллы %d/%d   Жизни %s   %d с" % [game.score, Game.CRYSTALS, "♥".repeat(hp) + "·".repeat(Game.HP_MAX - hp), int(game.time)]
	if game.state == "win":
		return line + "\n\nПобеда! R — заново"
	if game.state == "lose":
		return line + "\n\nТени взяли своё. R — заново"
	var best := INF
	for c in game.crystals:
		best = minf(best, c.distance_to(Vector2(hero.x, hero.z)))
	line += "\nБлижайший кристалл: %d м (вперёд, по -Z)" % int(best)
	return line + "\nWASD — ход, мышь (после клика) или Q/E — камера, Esc — отпустить"

static func make_label() -> Label:
	var l := Label.new()
	l.position = Vector2(16, 12)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("ffe9b0"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
