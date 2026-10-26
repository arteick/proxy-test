# Видимые узлы кристаллов и теней по состоянию Game.
const Props = preload("res://scripts/props.gd")

static func _orb(parent: Node3D, radius: float, height: float, material: Material, pos: Vector3, color: Color, light_range: float, energy: float) -> MeshInstance3D:
	var m := SphereMesh.new(); m.radius = radius; m.height = height
	var mi := Props.mesh(m, material, pos, parent)
	var l := OmniLight3D.new()
	l.light_color = color; l.omni_range = light_range; l.light_energy = energy
	mi.add_child(l)
	return mi

static func spawn_crystals(parent: Node3D, points: Array) -> Array:
	var gem := Props.mat(Color("6fe6ff"), 0.2)
	gem.emission_enabled = true
	gem.emission = Color("6fe6ff")
	gem.emission_energy_multiplier = 2.0
	var out: Array = []
	for c in points:
		out.append(_orb(parent, 0.3, 0.8, gem, Vector3(c.x, 1.0, c.y), Color("6fe6ff"), 5.0, 2.5))
	return out

const WING_FLAP_MOVE := 14.0
const WING_FLAP_IDLE := 3.0

# Красная летучая мышь: тело, уши, два крыла на шарнирах (meta wing_l / wing_r).
static func make_bat(parent: Node3D, pos: Vector3) -> Node3D:
	var red := Props.mat(Color("8a1020"), 0.8)
	red.emission_enabled = true
	red.emission = Color("ff3050")
	red.emission_energy_multiplier = 0.6
	var bat := Node3D.new()
	bat.position = pos
	parent.add_child(bat)
	var body := SphereMesh.new(); body.radius = 0.3; body.height = 0.7
	Props.mesh(body, red, Vector3.ZERO, bat)
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new(); ear.top_radius = 0.0; ear.bottom_radius = 0.1; ear.height = 0.3
		Props.mesh(ear, red, Vector3(sx * 0.14, 0.4, 0), bat)
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * 0.25, 0.05, 0)
		bat.add_child(pivot)
		var wing := BoxMesh.new(); wing.size = Vector3(1.0, 0.05, 0.6)
		Props.mesh(wing, red, Vector3(sx * 0.5, 0, 0), pivot)
		bat.set_meta("wing_l" if sx < 0.0 else "wing_r", pivot)
	var l := OmniLight3D.new()
	l.light_color = Color("ff3050"); l.omni_range = 4.0; l.light_energy = 1.5
	bat.add_child(l)
	return bat

# Взмах крыльями: быстрый в движении, медленный и широкий на месте.
static func flap_angle(t: float, moving: bool) -> float:
	if moving:
		return sin(t * WING_FLAP_MOVE) * 0.7
	return sin(t * WING_FLAP_IDLE) * 0.35

static func animate_bat(bat: Node3D, t: float, moving: bool) -> void:
	var a := flap_angle(t, moving)
	bat.get_meta("wing_l").rotation.z = -a
	bat.get_meta("wing_r").rotation.z = a

static func spawn_enemies(parent: Node3D, points: Array) -> Array:
	var out: Array = []
	for e in points:
		out.append(make_bat(parent, Vector3(e.x, 1.0, e.y)))
	return out
