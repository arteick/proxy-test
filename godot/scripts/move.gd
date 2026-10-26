# Логика движения героя без зависимости от сцены (тестируется headless).

# Вектор желаемого движения по плоскости XZ: wasd — ввод (x вправо, y вперёд), yaw — поворот камеры.
static func wish_dir(wasd: Vector2, yaw: float) -> Vector3:
	if wasd == Vector2.ZERO:
		return Vector3.ZERO
	var v := wasd.normalized()
	return Vector3(v.x, 0.0, -v.y).rotated(Vector3.UP, yaw)

# Выталкивает точку из круглых препятствий: Vector3(x, z, радиус).
static func resolve(pos: Vector3, hero_r: float, colliders: Array) -> Vector3:
	for c in colliders:
		var d := Vector2(pos.x - c.x, pos.z - c.y)
		var min_d: float = c.z + hero_r
		if d.length() < min_d:
			d = d.normalized() if d.length() > 0.0001 else Vector2.RIGHT
			pos.x = c.x + d.x * min_d
			pos.z = c.y + d.y * min_d
	return pos

static func step(pos: Vector3, dir: Vector3, speed: float, dt: float, hero_r: float, colliders: Array) -> Vector3:
	return resolve(pos + dir * speed * dt, hero_r, colliders)
