extends Node3D
# Сцена целиком в коде: колонны, персонаж, свет, камера и ASCII-постобработка.

const FAR := 60.0

var cam: Camera3D
var key: OmniLight3D
var hero := Node3D.new()
var arm_l := Node3D.new(); var arm_r := Node3D.new()
var leg_l := Node3D.new(); var leg_r := Node3D.new()
var zoom := 1.0
var t := 0.0

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
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("7080b8")
	env.environment.ambient_light_energy = 0.5
	add_child(env)

	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	_mesh(plane, _mat(Color("3c424e"), 0.9), Vector3.ZERO)

	var stone := _mat(Color("a8aab3"), 0.8)
	for i in 14:
		var h := 2.0 + (i % 4) * 1.2
		var c := CylinderMesh.new()
		c.top_radius = 0.5; c.bottom_radius = 0.6; c.height = h
		_mesh(c, stone, Vector3((1 if i % 2 else -1) * 4.5, h / 2.0, -i * 4.5))

	_build_hero()

	key = OmniLight3D.new()
	key.light_color = Color("ffc680")
	key.omni_range = 40.0
	key.light_energy = 6.0
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("5aa0ff")
	rim.omni_range = 30.0
	rim.light_energy = 3.0
	rim.position = Vector3(-3, 2.5, -5)
	add_child(rim)

	cam = Camera3D.new()
	cam.far = FAR
	cam.fov = 50.0
	add_child(cam)
	_build_ascii_pass()

func _build_hero() -> void:
	add_child(hero)
	var skin := _mat(Color("e8c9a0"), 0.7)
	var cloth := _mat(Color("3d7bd9"), 0.6)
	var dark := _mat(Color("35394a"), 0.7)
	var body := CapsuleMesh.new(); body.radius = 0.38; body.height = 1.46
	_mesh(body, cloth, Vector3(0, 1.35, 0), hero)
	var head := SphereMesh.new(); head.radius = 0.32; head.height = 0.64
	_mesh(head, skin, Vector3(0, 2.15, 0), hero)
	var hat := CylinderMesh.new(); hat.top_radius = 0.0; hat.bottom_radius = 0.36; hat.height = 0.5
	_mesh(hat, dark, Vector3(0, 2.6, 0), hero)
	for l in [[arm_l, skin, -0.5, 1.75], [arm_r, skin, 0.5, 1.75],
			[leg_l, dark, -0.2, 0.9], [leg_r, dark, 0.2, 0.9]]:
		var pivot: Node3D = l[0]
		pivot.position = Vector3(l[2], l[3], 0)
		hero.add_child(pivot)
		var cap := CapsuleMesh.new(); cap.radius = 0.11; cap.height = 0.82
		_mesh(cap, l[1], Vector3(0, -0.4, 0), pivot)

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

func _process(dt: float) -> void:
	t += dt
	var m := get_viewport().get_mouse_position() / Vector2(get_viewport().get_visible_rect().size)
	var swing := sin(t * 3.0) * 0.6
	arm_l.rotation.x = swing; arm_r.rotation.x = -swing
	leg_l.rotation.x = -swing; leg_r.rotation.x = swing
	hero.position.y = absf(sin(t * 3.0)) * 0.06
	hero.rotation.y = sin(t * 0.4) * 0.5
	key.position = Vector3((m.x - 0.5) * 12.0, 1.2 + (1.0 - m.y) * 5.0, 2.0 + sin(t * 0.7))
	cam.position = Vector3(0, 2.0 * zoom, 4.6 * zoom)
	cam.look_at(Vector3(0, 1.5, -3))
