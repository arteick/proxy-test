# Статичный уровень: земля и колоннада. Возвращает коллайдеры Vector3(x, z, радиус).
const Props = preload("res://scripts/props.gd")

const COLUMNS := 14

static func build(parent: Node3D) -> Array:
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	Props.mesh(plane, Props.mat(Color("3c424e"), 0.9), Vector3.ZERO, parent)
	var stone := Props.mat(Color("a8aab3"), 0.8)
	var colliders: Array = []
	for i in COLUMNS:
		var h := 2.0 + (i % 4) * 1.2
		var c := CylinderMesh.new()
		c.top_radius = 0.5; c.bottom_radius = 0.6; c.height = h
		var cx := (1 if i % 2 else -1) * 4.5
		var cz := -i * 4.5
		Props.mesh(c, stone, Vector3(cx, h / 2.0, cz), parent)
		colliders.append(Vector3(cx, cz, 0.6))
	return colliders
