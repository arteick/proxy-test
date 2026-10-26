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
		out.append(_orb(parent, 0.3, 0.8, gem, Vector3(c.x, 1.0, c.y), Color("6fe6ff"), 8.0, 2.5))
	return out

static func spawn_enemies(parent: Node3D, points: Array) -> Array:
	var shade := Props.mat(Color("1a0c14"), 0.9)
	shade.emission_enabled = true
	shade.emission = Color("ff3050")
	var out: Array = []
	for e in points:
		out.append(_orb(parent, 0.55, 1.1, shade, Vector3(e.x, 1.0, e.y), Color("ff3050"), 6.0, 1.5))
	return out
