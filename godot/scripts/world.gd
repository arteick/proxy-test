extends Node3D
const Move = preload("res://scripts/move.gd")
const Game = preload("res://scripts/game.gd")
const Hero = preload("res://scripts/hero.gd")
const Hud = preload("res://scripts/hud.gd")
const Level = preload("res://scripts/level.gd")
const Actors = preload("res://scripts/actors.gd")
const Lighting = preload("res://scripts/lighting.gd")
const Spells = preload("res://scripts/spells.gd")
const Postfx = preload("res://scripts/postfx.gd")
const Dash = preload("res://scripts/dash.gd")
const Campfire = preload("res://scripts/campfire.gd")
const Prewarm = preload("res://scripts/prewarm.gd")
# Сцена целиком в коде: колонны, персонаж, свет, камера и ASCII-постобработка.

const FAR := 60.0
const SPEED := 5.0
const HERO_R := 0.45

var colliders: Array = []
var yaw := 0.0
var moving := false

var cam: Camera3D
var light := Lighting.new()
var hero := Hero.new()
var zoom := Move.ZOOM_FIXED
var t := 0.0
var game: Game
var crystal_nodes: Array = []
var enemy_nodes: Array = []
var hud: Label
var ascii_mat: ShaderMaterial
var marker := Move.marker_scale(Move.ZOOM_FIXED) # масштаб значков, считается один раз (зум фиксирован)
var last_hud := ""
var run_seed := 1
var spells := Spells.new()
var dash := Dash.new()
var fire := Campfire.new()
var fire_node: Node3D
var warm: Node3D
var warm_frames := Prewarm.FRAMES

func _ready() -> void:
	colliders = Level.build(self) + Level.build_ruins(self)
	add_child(hero)
	add_child(light)

	cam = Camera3D.new()
	cam.far = FAR
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = Move.ortho_size(zoom)
	add_child(cam)
	ascii_mat = Postfx.build(self, cam)
	ascii_mat.set_shader_parameter("far_blend", Move.far_blend(zoom))
	fire_node = Campfire.make_node(self)
	add_child(spells)
	spells.setup(hero, cam)
	spells.exploded.connect(_on_explosion)
	spells.hit_test = func(p: Vector3) -> bool: return game.state == "play" and game.ball_hit(Vector2(p.x, p.z)) >= 0
	hud = Hud.make_label()
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	warm = Prewarm.make_node(hero)
	_new_game()

func _new_game() -> void:
	for n in crystal_nodes + enemy_nodes:
		n.queue_free()
	game = Game.new(run_seed)
	run_seed += 1
	hero.position = Vector3.ZERO
	dash = Dash.new()
	crystal_nodes = Actors.spawn_crystals(self, game.crystals)
	enemy_nodes = Actors.spawn_enemies(self, game.enemies)

func _on_explosion(at: Vector3) -> void:
	if game.state != "play":
		return
	for i in game.blast(Vector2(at.x, at.z)):
		enemy_nodes[i].queue_free()
		enemy_nodes.remove_at(i)
		light.flash()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_R:
		_new_game()

func _update_game(dt: float) -> void:
	game.dodging = dash.active()
	var ev := game.update(hero.position, dt)
	# кристаллы подбираются по порядку удаления с конца: пересобираем узлы по совпадению позиции
	while crystal_nodes.size() > game.crystals.size():
		for i in crystal_nodes.size():
			var p: Vector3 = crystal_nodes[i].position
			if not game.crystals.has(Vector2(p.x, p.z)):
				crystal_nodes[i].queue_free()
				crystal_nodes.remove_at(i)
				break
	for i in crystal_nodes.size():
		crystal_nodes[i].position.y = 1.0 + sin(t * 2.0 + i) * 0.15
		crystal_nodes[i].rotation.y = t
		crystal_nodes[i].scale = Vector3.ONE * marker
	for i in enemy_nodes.size():
		var prev: Vector3 = enemy_nodes[i].position
		var np := Vector3(game.enemies[i].x, 1.0 + sin(t * 3.0 + i) * 0.2, game.enemies[i].y)
		var flying := Vector2(np.x - prev.x, np.z - prev.z).length() > 0.0005
		enemy_nodes[i].position = np
		if flying:
			enemy_nodes[i].rotation.y = atan2(-(np.x - prev.x), -(np.z - prev.z))
		Actors.animate_bat(enemy_nodes[i], t + i, flying)
		enemy_nodes[i].scale = Vector3.ONE * marker
	if ev.has("hurt"):
		light.flash()
	var txt := Hud.text(game, hero.position, dash.charge())
	if txt != last_hud: # Label пересчитывает раскладку при каждой записи текста
		last_hud = txt
		hud.text = txt

func _process(dt: float) -> void:
	t += dt
	if warm:
		warm_frames -= 1
		if warm_frames <= 0:
			warm.queue_free()
			warm = null
	yaw += (float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))) * 1.8 * dt
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	spells.update(dt, t, zoom, game.state == "play")
	fire.update(dt)
	Campfire.apply(fire_node, fire, t, marker)
	var dir := Move.wish_dir(wasd, yaw) if game.state == "play" else Vector3.ZERO
	moving = dir != Vector3.ZERO
	dash.update(dt)
	if game.state == "play" and Input.is_physical_key_pressed(KEY_SHIFT):
		var facing := Vector3(-sin(hero.rotation.y), 0.0, -cos(hero.rotation.y))
		dash.start(dir if moving else facing)
	if dash.active():
		hero.position = Move.step(hero.position, dash.dir, Dash.SPEED, dt, HERO_R, colliders)
	elif moving:
		hero.position = Move.step(hero.position, dir, SPEED * spells.speed_mult(), dt, HERO_R, colliders)
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 12.0))
	if spells.charging():
		hero.rotation.y = lerp_angle(hero.rotation.y, spells.aim_yaw(), minf(1.0, dt * 12.0)) # лицом к курсору
	hero.casting = spells.charging()
	hero.animate(dt, moving, t)
	var base := hero.position
	var m := get_viewport().get_mouse_position() / Vector2(get_viewport().get_visible_rect().size)
	light.follow(base, m, t, dt)
	cam.position = Move.top_down_cam(base, yaw, zoom)
	cam.look_at(base)
	hero.scale = Vector3.ONE * marker
	_update_game(dt)
