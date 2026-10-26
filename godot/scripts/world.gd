extends Node3D
const Ascii = preload("res://scripts/ascii.gd")
const Move = preload("res://scripts/move.gd")
const Game = preload("res://scripts/game.gd")
# Сцена целиком в коде: колонны, персонаж, свет, камера и ASCII-постобработка.

const FAR := 60.0
const SPEED := 5.0
const HERO_R := 0.45

var colliders: Array = []
var yaw := 0.0
var moving := false

var cam: Camera3D
var key: OmniLight3D
var hero := Node3D.new()
var arm_l := Node3D.new(); var arm_r := Node3D.new()
var leg_l := Node3D.new(); var leg_r := Node3D.new()
var zoom := 1.0
var t := 0.0
var game: Game
var crystal_nodes: Array = []
var enemy_nodes: Array = []
var hud: Label
var run_seed := 1

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("070910")
	# полусферный свет как в Three.js-прототипе: небо 7080b8 сверху, земля 2a2018 снизу
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7080b8")
	sky_mat.sky_horizon_color = Color("4a5070")
	sky_mat.ground_horizon_color = Color("4a5070")
	sky_mat.ground_bottom_color = Color("2a2018")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.tonemap_exposure = 1.0
	add_child(env)

	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	_mesh(plane, _mat(Color("3c424e"), 0.9), Vector3.ZERO)

	var stone := _mat(Color("a8aab3"), 0.8)
	for i in 14:
		var h := 2.0 + (i % 4) * 1.2
		var c := CylinderMesh.new()
		c.top_radius = 0.5; c.bottom_radius = 0.6; c.height = h
		var cx := (1 if i % 2 else -1) * 4.5
		var cz := -i * 4.5
		_mesh(c, stone, Vector3(cx, h / 2.0, cz))
		colliders.append(Vector3(cx, cz, 0.6))

	_build_hero()

	key = OmniLight3D.new()
	key.light_color = Color("ffc680")
	key.omni_range = 40.0
	key.light_energy = 6.0
	key.omni_attenuation = 1.4
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("5aa0ff")
	rim.omni_range = 30.0
	rim.light_energy = 3.0
	rim.omni_attenuation = 1.4
	rim.position = Vector3(-3, 2.5, -5)
	add_child(rim)

	cam = Camera3D.new()
	cam.far = FAR
	cam.fov = 50.0
	add_child(cam)
	_build_ascii_pass()
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("ffe9b0"))
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	_new_game()

func _new_game() -> void:
	for n in crystal_nodes + enemy_nodes:
		n.queue_free()
	crystal_nodes.clear(); enemy_nodes.clear()
	game = Game.new(run_seed)
	run_seed += 1
	hero.position = Vector3.ZERO
	var gem := _mat(Color("6fe6ff"), 0.2)
	gem.emission_enabled = true
	gem.emission = Color("6fe6ff")
	gem.emission_energy_multiplier = 2.0
	var shade := _mat(Color("1a0c14"), 0.9)
	shade.emission_enabled = true
	shade.emission = Color("ff3050")
	for c in game.crystals:
		var m := SphereMesh.new(); m.radius = 0.3; m.height = 0.8
		var mi := _mesh(m, gem, Vector3(c.x, 1.0, c.y))
		var l := OmniLight3D.new()
		l.light_color = Color("6fe6ff"); l.omni_range = 8.0; l.light_energy = 2.5
		mi.add_child(l)
		crystal_nodes.append(mi)
	for e in game.enemies:
		var m := SphereMesh.new(); m.radius = 0.55; m.height = 1.1
		var mi := _mesh(m, shade, Vector3(e.x, 1.0, e.y))
		var l := OmniLight3D.new()
		l.light_color = Color("ff3050"); l.omni_range = 6.0; l.light_energy = 1.5
		mi.add_child(l)
		enemy_nodes.append(mi)

func _build_hero() -> void:
	# маг: синяя мантия, остроконечная шляпа, посох в коричневых тонах
	add_child(hero)
	var skin := _mat(Color("e8c9a0"), 0.7)
	var robe := _mat(Color("2a4fc4"), 0.7)
	var robe_dark := _mat(Color("1b2f7a"), 0.75)
	var wood := _mat(Color("6b4423"), 0.85)
	var wood_dark := _mat(Color("4a2e15"), 0.9)
	var wood_light := _mat(Color("8f6236"), 0.8)
	var skirt := CylinderMesh.new(); skirt.top_radius = 0.3; skirt.bottom_radius = 0.62; skirt.height = 1.5
	_mesh(skirt, robe, Vector3(0, 0.8, 0), hero)
	var torso := CapsuleMesh.new(); torso.radius = 0.34; torso.height = 0.9
	_mesh(torso, robe, Vector3(0, 1.6, 0), hero)
	var belt := CylinderMesh.new(); belt.top_radius = 0.36; belt.bottom_radius = 0.36; belt.height = 0.1
	_mesh(belt, wood_dark, Vector3(0, 1.3, 0), hero)
	var head := SphereMesh.new(); head.radius = 0.3; head.height = 0.6
	_mesh(head, skin, Vector3(0, 2.15, 0), hero)
	var brim := CylinderMesh.new(); brim.top_radius = 0.5; brim.bottom_radius = 0.5; brim.height = 0.06
	_mesh(brim, robe_dark, Vector3(0, 2.38, 0), hero)
	var hat := CylinderMesh.new(); hat.top_radius = 0.0; hat.bottom_radius = 0.34; hat.height = 0.75
	_mesh(hat, robe, Vector3(0, 2.78, 0), hero)
	var feet := _mat(Color("2b1d12"), 0.9)
	for l in [[arm_l, robe, -0.45, 1.8], [arm_r, robe, 0.45, 1.8]]:
		var pivot: Node3D = l[0]
		pivot.position = Vector3(l[2], l[3], 0)
		hero.add_child(pivot)
		var cap := CapsuleMesh.new(); cap.radius = 0.12; cap.height = 0.82
		_mesh(cap, l[1], Vector3(0, -0.4, 0), pivot)
		var hand := SphereMesh.new(); hand.radius = 0.1; hand.height = 0.2
		_mesh(hand, skin, Vector3(0, -0.85, 0), pivot)
	for l in [[leg_l, -0.2], [leg_r, 0.2]]:
		var pivot: Node3D = l[0]
		pivot.position = Vector3(l[1], 0.3, 0)
		hero.add_child(pivot)
		var boot := CapsuleMesh.new(); boot.radius = 0.12; boot.height = 0.5
		_mesh(boot, feet, Vector3(0, -0.1, 0), pivot)
	# посох в правой руке: древко, утолщения и навершие
	var shaft := CylinderMesh.new(); shaft.top_radius = 0.04; shaft.bottom_radius = 0.05; shaft.height = 2.6
	_mesh(shaft, wood, Vector3(0, -0.1, -0.05), arm_r)
	var knob := CylinderMesh.new(); knob.top_radius = 0.07; knob.bottom_radius = 0.07; knob.height = 0.12
	_mesh(knob, wood_dark, Vector3(0, 0.55, -0.05), arm_r)
	_mesh(knob, wood_dark, Vector3(0, -0.8, -0.05), arm_r)
	var head_s := SphereMesh.new(); head_s.radius = 0.13; head_s.height = 0.26
	_mesh(head_s, wood_light, Vector3(0, 1.28, -0.05), arm_r)
	var claw := TorusMesh.new(); claw.inner_radius = 0.1; claw.outer_radius = 0.17
	_mesh(claw, wood_dark, Vector3(0, 1.45, -0.05), arm_r)

func _build_ascii_pass() -> void:
	var atlas_vp: SubViewport = SubViewport.new()
	atlas_vp.set_script(load("res://scripts/atlas.gd"))
	add_child(atlas_vp)
	var mat := ShaderMaterial.new()
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
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(2.2, zoom * 1.06)
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(0.5, zoom * 0.94)

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
	for i in enemy_nodes.size():
		enemy_nodes[i].position = Vector3(game.enemies[i].x, 1.0 + sin(t * 3.0 + i) * 0.2, game.enemies[i].y)
	if ev.has("hurt"):
		key.light_energy = 14.0
	key.light_energy = lerpf(key.light_energy, 6.0, minf(1.0, dt * 5.0))
	var line := "Кристаллы %d/%d   Жизни %s   %d с" % [game.score, Game.CRYSTALS, "♥".repeat(maxi(game.hp, 0)) + "·".repeat(Game.HP_MAX - maxi(game.hp, 0)), int(game.time)]
	if game.state == "win":
		line += "\n\nПобеда! R — заново"
	elif game.state == "lose":
		line += "\n\nТени взяли своё. R — заново"
	else:
		var best := INF
		for c in game.crystals:
			best = minf(best, c.distance_to(Vector2(hero.position.x, hero.position.z)))
		line += "\nБлижайший кристалл: %d м (вперёд, по -Z)" % int(best)
		line += "\nWASD (любая раскладка) — ход, Q/E — поворот камеры, колесо — масштаб"
	hud.text = line

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
	var swing := sin(t * 9.0) * 0.6 if moving else 0.0
	arm_l.rotation.x = swing; arm_r.rotation.x = -swing
	leg_l.rotation.x = -swing; leg_r.rotation.x = swing
	var base := hero.position
	var m := get_viewport().get_mouse_position() / Vector2(get_viewport().get_visible_rect().size)
	key.position = base + Vector3((m.x - 0.5) * 12.0, 1.2 + (1.0 - m.y) * 5.0, 2.0 + sin(t * 0.7))
	cam.position = base + Vector3(0, 2.0 * zoom + 1.0, 4.6 * zoom).rotated(Vector3.UP, yaw)
	cam.look_at(base + Vector3(0, 1.5, 0))
	_update_game(dt)
