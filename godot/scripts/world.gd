extends Node3D
const Ascii = preload("res://scripts/ascii.gd")
const Move = preload("res://scripts/move.gd")
const Game = preload("res://scripts/game.gd")
const Hero = preload("res://scripts/hero.gd")
const Hud = preload("res://scripts/hud.gd")
const Level = preload("res://scripts/level.gd")
const Actors = preload("res://scripts/actors.gd")
const Lighting = preload("res://scripts/lighting.gd")
# Сцена целиком в коде: колонны, персонаж, свет, камера и ASCII-постобработка.

const FAR := 60.0
const SPEED := 5.0
const HERO_R := 0.45
const MOUSE_SENS := 0.004

var colliders: Array = []
var yaw := 0.0
var moving := false

var cam: Camera3D
var light := Lighting.new()
var hero := Hero.new()
var pitch := Move.TOP_PITCH
var zoom := 1.0
var t := 0.0
var game: Game
var crystal_nodes: Array = []
var enemy_nodes: Array = []
var hud: Label
var ascii_mat: ShaderMaterial
var run_seed := 1

func _ready() -> void:
	colliders = Level.build(self)
	add_child(hero)
	add_child(light)

	cam = Camera3D.new()
	cam.far = FAR
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = Move.ortho_size(zoom)
	add_child(cam)
	_build_ascii_pass()
	hud = Hud.make_label()
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	_new_game()

func _new_game() -> void:
	for n in crystal_nodes + enemy_nodes:
		n.queue_free()
	game = Game.new(run_seed)
	run_seed += 1
	hero.position = Vector3.ZERO
	crystal_nodes = Actors.spawn_crystals(self, game.crystals)
	enemy_nodes = Actors.spawn_enemies(self, game.enemies)

func _build_ascii_pass() -> void:
	var atlas_vp: SubViewport = SubViewport.new()
	atlas_vp.set_script(load("res://scripts/atlas.gd"))
	add_child(atlas_vp)
	var mat := ShaderMaterial.new()
	ascii_mat = mat
	mat.shader = load("res://shaders/ascii.gdshader")
	mat.set_shader_parameter("atlas", atlas_vp.get_texture())
	mat.set_shader_parameter("n_glyphs", float(Ascii.RAMP.length()))
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	cam.add_child(mi)

func _input(e: InputEvent) -> void:
	# вид сверху: наклон фиксирован, мышь камеру не крутит; колесо — масштаб
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(Move.ZOOM_MAX, zoom * 1.08)
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(Move.ZOOM_MIN, zoom * 0.93)

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_R:
		_new_game()

func _update_game(dt: float) -> void:
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
		crystal_nodes[i].scale = Vector3.ONE * Move.marker_scale(zoom)
	for i in enemy_nodes.size():
		var prev: Vector3 = enemy_nodes[i].position
		var np := Vector3(game.enemies[i].x, 1.0 + sin(t * 3.0 + i) * 0.2, game.enemies[i].y)
		var flying := Vector2(np.x - prev.x, np.z - prev.z).length() > 0.0005
		enemy_nodes[i].position = np
		if flying:
			enemy_nodes[i].rotation.y = atan2(-(np.x - prev.x), -(np.z - prev.z))
		Actors.animate_bat(enemy_nodes[i], t + i, flying)
		enemy_nodes[i].scale = Vector3.ONE * Move.marker_scale(zoom)
	if ev.has("hurt"):
		light.flash()
	hud.text = Hud.text(game, hero.position)

func _process(dt: float) -> void:
	t += dt
	yaw += (float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))) * 1.8 * dt
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	var dir := Move.wish_dir(wasd, yaw) if game.state == "play" else Vector3.ZERO
	moving = dir != Vector3.ZERO
	if moving:
		hero.position = Move.step(hero.position, dir, SPEED, dt, HERO_R, colliders)
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 12.0))
	hero.animate(dt, moving, t)
	var base := hero.position
	var m := get_viewport().get_mouse_position() / Vector2(get_viewport().get_visible_rect().size)
	light.follow(base, m, t, dt)
	cam.position = Move.top_down_cam(base, yaw, zoom)
	cam.look_at(base)
	cam.size = Move.ortho_size(zoom)
	ascii_mat.set_shader_parameter("far_blend", Move.far_blend(zoom))
	var ms := Move.marker_scale(zoom)
	hero.scale = Vector3.ONE * ms
	_update_game(dt)
