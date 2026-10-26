# Правила игры без зависимости от сцены (тестируется headless).
# Цель: собрать все кристаллы, не дав теням отнять все жизни.

const CRYSTALS := 8
const ENEMIES := 3
const PICK_R := 1.0
const HIT_R := 0.9
const SEE_R := 12.0
const ENEMY_SPEED := 3.0
const HP_MAX := 3
const INVULN := 1.2

var crystals: Array = []   # Vector2(x, z)
var enemies: Array = []    # Vector2(x, z)
var homes: Array = []      # где тень стоит, пока героя не видно
var hp := HP_MAX
var score := 0
var time := 0.0
var hurt_cd := 0.0
var state := "play"        # play | win | lose

func _init(seed_value: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in CRYSTALS:
		var z := -6.0 - (i + rng.randf()) * (54.0 / CRYSTALS)
		crystals.append(Vector2(rng.randf_range(-3.0, 3.0), z))
	for i in ENEMIES:
		var z := -14.0 - i * 18.0 - rng.randf() * 6.0
		enemies.append(Vector2(rng.randf_range(-3.0, 3.0), z))
	homes = enemies.duplicate()

# Один тик. hero — позиция героя (Vector3). Возвращает события: "pick", "hurt", "win", "lose".
func update(hero: Vector3, dt: float) -> Array:
	var ev: Array = []
	if state != "play":
		return ev
	time += dt
	hurt_cd = maxf(0.0, hurt_cd - dt)
	var h := Vector2(hero.x, hero.z)
	for i in range(crystals.size() - 1, -1, -1):
		if crystals[i].distance_to(h) < PICK_R:
			crystals.remove_at(i)
			score += 1
			ev.append("pick")
	for i in enemies.size():
		var e: Vector2 = enemies[i]
		var target: Vector2 = h if e.distance_to(h) < SEE_R else homes[i]
		enemies[i] = e.move_toward(target, ENEMY_SPEED * dt)
		if enemies[i].distance_to(h) < HIT_R and hurt_cd == 0.0:
			hp -= 1
			hurt_cd = INVULN
			ev.append("hurt")
	if hp <= 0:
		state = "lose"
		ev.append("lose")
	elif crystals.is_empty():
		state = "win"
		ev.append("win")
	return ev
