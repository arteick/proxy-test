extends Node3D
const Move = preload("res://scripts/move.gd")
const Fireball = preload("res://scripts/fireball.gd")
const Explosion = preload("res://scripts/explosion.gd")
const Trail = preload("res://scripts/trail.gd")
# Заклинания: огненный шар (накопление, полёт, отмена), взрывы и выжженные пятна.

var hero: Node3D
var cam: Camera3D
var ball: Fireball # шар, который копится над головой
var ball_node: Node3D
var flying: Array = [] # [Fireball, Node3D, Trail, Node3D шлейфа]
var explosions: Array = [] # [Explosion, Node3D]
var scorches: Array = []
var boom_seed := 1
var ball_blocked := false # после отмены ждём отпускания ЛКМ

func setup(hero_: Node3D, cam_: Camera3D) -> void:
	hero = hero_
	cam = cam_

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
		ball_node = Fireball.make_node(self)
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
			ball_node.queue_free()
			ball = null
		else:
			Fireball.apply(ball_node, ball, ms, t)
	for f in flying.duplicate():
		f[0].update(dt, false, false)
		var live: bool = f[0].state == "flying"
		f[2].update(dt, f[0].pos, live)
		Trail.apply(f[3], f[2], ms)
		if f[0].state == "exploded":
			_explode(f[0].pos)
			f[1].queue_free()
		elif f[0].state == "gone":
			f[1].queue_free()
		else:
			Fireball.apply(f[1], f[0], ms, t)
		if not live:
			f[0].state = "gone" if f[0].state == "exploded" else f[0].state
			if f[2].parts.is_empty():
				f[3].queue_free()
				flying.erase(f)

# Точка земли (y=0) под курсором; если луч не доходит до земли — прямо перед героем.
func _cursor_ground(fallback: Vector3) -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(mp), cam.project_ray_normal(mp))
	return hit if hit != null else fallback

func _explode(at: Vector3) -> void:
	boom_seed += 1
	var ex := Explosion.make(at, boom_seed)
	explosions.append([ex, Explosion.make_node(self, ex)])
	scorches.append(Explosion.make_scorch(self, at, boom_seed))
	if scorches.size() > Explosion.SCORCH_MAX:
		scorches.pop_front().queue_free()

func _update_explosions(dt: float, ms: float) -> void:
	for e in explosions.duplicate():
		e[0].update(dt)
		if e[0].done():
			e[1].queue_free()
			explosions.erase(e)
		else:
			Explosion.apply(e[1], e[0], ms)
