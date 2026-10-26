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

# Шаг режется на куски не длиннее MAX_STEP, иначе при просадке кадров (или рывке) герой проскакивает колонну насквозь.
const MAX_STEP := 0.25
static func step(pos: Vector3, dir: Vector3, speed: float, dt: float, hero_r: float, colliders: Array) -> Vector3:
	var n := maxi(1, ceili(speed * dt / MAX_STEP))
	for i in n:
		pos = resolve(pos + dir * speed * dt / n, hero_r, colliders)
	return pos

# Точка внутри какого-нибудь препятствия (для шара: взрыв о колонну).
static func blocked(p: Vector3, colliders: Array) -> bool:
	for c in colliders:
		if Vector2(p.x - c.x, p.z - c.y).length() < c.z:
			return true
	return false

# Поворот камеры от движения мыши: rel — сдвиг в пикселях, pitch ограничен, чтобы камера не уходила под землю и за зенит.
const PITCH_MIN := -0.15
const PITCH_MAX := 1.2
static func look(yaw: float, pitch: float, rel: Vector2, sens: float) -> Vector2:
	return Vector2(yaw - rel.x * sens, clampf(pitch + rel.y * sens, PITCH_MIN, PITCH_MAX))

# Вид сверху, почти двумерный: ортографическая камера под ~70° (перспективы нет, масштаб одинаков по всему экрану), W — вверх экрана.
const TOP_PITCH := 1.2
const TOP_DIST := 30.0
const ORTHO_SIZE := 16.0  # высота кадра в метрах при zoom = 1
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.5
const ZOOM_FIXED := 1.02  # фиксированный масштаб: на 15% ближе прежнего 1.2 — текстуры крупнее
static func top_down_cam(base: Vector3, yaw: float, _zoom: float = 1.0) -> Vector3:
	return base + Vector3(0, 0, TOP_DIST).rotated(Vector3.RIGHT, -TOP_PITCH).rotated(Vector3.UP, yaw)

static func ortho_size(zoom: float) -> float:
	return ORTHO_SIZE * clampf(zoom, ZOOM_MIN, ZOOM_MAX)

# Во сколько раз увеличить героя, кристаллы и тени, чтобы на дальнем масштабе они оставались читаемыми значками.
static func marker_scale(zoom: float) -> float:
	return maxf(1.0, zoom * 0.9)

# 0 вблизи (символы), 1 на дальнем масштабе (плоские цвета с контуром).
static func far_blend(zoom: float) -> float:
	return smoothstep(1.4, 2.6, zoom)
