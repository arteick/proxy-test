extends Node3D
const Move = preload("res://scripts/move.gd")
const Fireball = preload("res://scripts/fireball.gd")
const Explosion = preload("res://scripts/explosion.gd")
const Trail = preload("res://scripts/trail.gd")
signal exploded(at: Vector3)
# Заклинания: огненный шар (накопление, полёт, отмена), взрывы и выжженные пятна.

var hero: Node3D
var cam: Camera3D
var ball: Fireball # шар, который копится над головой
var ball_node: Node3D
var flying: Array = [] # [Fireball, Node3D, Trail, Node3D шлейфа]
var explosions: Array = [] # [Explosion, Node3D]
var scorches: Array = []
var ball_pool: Array = [] # узлы шара с OmniLight не удаляются (смена числа источников вешает веб): паркуются и берутся снова
const BALL_POOL := 4
var boom_seed := 1
var hit_test: Callable # (Vector3) -> bool: шар коснулся врага
var ball_blocked := false # после отмены ждём отпускания ЛКМ

func setup(hero_: Node3D, cam_: Camera3D) -> void:
	hero = hero_
	cam = cam_
	for i in BALL_POOL:
		_release_ball(Fireball.make_node(self))

func _acquire_ball() -> Node3D:
	return ball_pool.pop_back() if not ball_pool.is_empty() else Fireball.make_node(self)

func _release_ball(n: Node3D) -> void:
	n.position = Vector3(0, -500, 0)
	n.get_meta("light").light_energy = 0.001
	ball_pool.append(n)

func charging() -> bool:
	return ball != null and ball.state == "charging"

# Во сколько раз замедлить героя, пока копится шар.
func speed_mult() -> float:
	return Fireball.speed_mult(ball)

# Угол поворота героя лицом к курсору.
func aim_yaw() -> float:
	var aim := Fireball.aim_target(hero.position, _cursor_ground(hero.position)) - hero.position
	return atan2(-aim.x, -aim.z)

func update(dt: float, t: float, zoom: float, can_cast: bool) -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var ms := Move.marker_scale(zoom)
	_update_fireball(dt, t, ms, lmb, rmb, can_cast)
	_update_explosions(dt, ms)

func _update_fireball(dt: float, t: float, ms: float, lmb: bool, rmb: bool, can_cast: bool) -> void:
	if not lmb:
		ball_blocked = false
	if ball == null and lmb and not rmb and not ball_blocked and can_cast:
		ball = Fireball.new()
		ball_node = _acquire_ball()
	if ball != null:
		ball.update(dt, lmb, rmb)
		ball.pos = hero.position + Vector3(0, 3.7 * ms, 0)
		if ball.state == "fading":
			ball_blocked = true
		if ball.state == "flying":
			var from := hero.position + Vector3(0, 3.7 * ms, 0)
			var target := Fireball.aim_target(hero.position, _cursor_ground(hero.position))
			var fwd := (target - hero.position) * Vector3(1, 0, 1)
			ball.launch(from + fwd.normalized() * 0.8, target)
			flying.append([ball, ball_node, Trail.new(), Trail.make_node(self)])
			ball = null
		elif ball.state == "gone":
			_release_ball(ball_node)
			ball = null
		else:
			Fireball.apply(ball_node, ball, ms, t)
	for k in range(flying.size() - 1, -1, -1): # с конца: удаление без копии массива
		var f: Array = flying[k]
		f[0].update(dt, false, false)
		if f[0].state == "flying" and hit_test.is_valid() and hit_test.call(f[0].pos):
			f[0].state = "exploded" # попал в мышь по пути — взрыв на месте
		var live: bool = f[0].state == "flying"
		f[2].update(dt, f[0].pos, live)
		Trail.apply(f[3], f[2], ms)
		if f[0].state == "exploded":
			_explode(f[0].pos)
		if f[0].state == "exploded" or f[0].state == "gone":
			if not ball_pool.has(f[1]): # шлейф живёт ещё ~0.5 с — узел шара возвращаем один раз
				_release_ball(f[1])
		else:
			Fireball.apply(f[1], f[0], ms, t)
		if not live:
			f[0].state = "gone" if f[0].state == "exploded" else f[0].state
			if f[2].parts.is_empty():
				f[3].queue_free()
				flying.remove_at(k)

# Точка земли (y=0) под курсором; если луч не доходит до земли — прямо перед героем.
func _cursor_ground(fallback: Vector3) -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	return hit if hit != null else fallback

func _explode(at: Vector3) -> void:
	exploded.emit(at)
	boom_seed += 1
	var ex := Explosion.make(at, boom_seed)
	explosions.append([ex, Explosion.make_node(self, ex)])
	scorches.append(Explosion.make_scorch(self, at, boom_seed))
	if scorches.size() > Explosion.SCORCH_MAX:
		scorches.pop_front().queue_free()

func _update_explosions(dt: float, ms: float) -> void:
	for k in range(explosions.size() - 1, -1, -1):
		var e: Array = explosions[k]
		e[0].update(dt)
		if e[0].done():
			e[1].queue_free()
			explosions.remove_at(k)
		else:
			Explosion.apply(e[1], e[0], ms)
