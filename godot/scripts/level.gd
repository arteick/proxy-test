# Статичный уровень: земля и колоннада. Возвращает коллайдеры Vector3(x, z, радиус).
const Props = preload("res://scripts/props.gd")

const COLUMNS := 14
const TILE := 16  # пикселей на плитку; плитка = 2 м

# Пол: каменные плиты вдоль колоннады, вокруг трава. Яркость пятнами — шейдер даст разные символы.
static func floor_image() -> Image:
	var n := TILE * 8
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var tx := x / TILE
			var ty := y / TILE
			var h := int(hash(Vector2i(x, y))) & 255
			var th := int(hash(Vector2i(tx, ty))) & 255
			var edge := x % TILE == 0 or y % TILE == 0
			var c: Color
			if (tx + ty) % 3 == 0:
				var v := 0.34 + (th % 24) / 255.0 + (0.0 if edge else (h % 8) / 255.0)
				c = Color(v, v, v * 1.05)
				if edge: c = c.darkened(0.2)
			else:
				var g := 0.24 + (h % 30) / 255.0
				c = Color(g * 0.55, g, g * 0.45)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()  # без мип-уровней мелкий шум пола рябит при движении
	return img

static func build(parent: Node3D) -> Array:
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var floor_mat := Props.mat(Color.WHITE, 0.95)
	floor_mat.albedo_texture = ImageTexture.create_from_image(floor_image())
	floor_mat.uv1_scale = Vector3(200.0 / 16.0, 200.0 / 16.0, 1.0)  # 8 плиток в текстуре = 16 м
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	Props.mesh(plane, floor_mat, Vector3.ZERO, parent)
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

# Руины храма (одни на карту): плита-основание, обломки колонн, кусок стены, упавший барабан.
# Возвращает коллайдеры Vector3(x, z, радиус) для колонн и стены.
const RUINS_POS := Vector3(14.0, 0.0, -22.0)

static func build_ruins(parent: Node3D, origin: Vector3 = RUINS_POS) -> Array:
	var stone := Props.mat(Color("8f9199"), 0.85)
	var colliders: Array = []
	var slab := BoxMesh.new()
	slab.size = Vector3(10, 0.3, 8)
	Props.mesh(slab, stone, origin + Vector3(0, 0.15, 0), parent)
	var step := BoxMesh.new()
	step.size = Vector3(10, 0.15, 1.2)
	Props.mesh(step, stone, origin + Vector3(0, 0.07, 4.6), parent)
	var heights := [3.4, 1.2, 2.2, 0.7, 2.8, 1.6]
	var i := 0
	for sx in [-3.5, 0.0, 3.5]:
		for sz in [-2.8, 2.8]:
			var h: float = heights[i]
			i += 1
			var c := CylinderMesh.new()
			c.top_radius = 0.45; c.bottom_radius = 0.55; c.height = h
			Props.mesh(c, stone, origin + Vector3(sx, 0.3 + h / 2.0, sz), parent)
			colliders.append(Vector3(origin.x + sx, origin.z + sz, 0.6))
	var wall := BoxMesh.new()
	wall.size = Vector3(5.0, 2.2, 0.6)
	Props.mesh(wall, stone, origin + Vector3(0, 0.3 + 1.1, -4.2), parent)
	for wx in [-1.8, 0.0, 1.8]:
		colliders.append(Vector3(origin.x + wx, origin.z - 4.2, 1.0))
	var drum := CylinderMesh.new()
	drum.top_radius = 0.5; drum.bottom_radius = 0.5; drum.height = 1.6
	var d := Props.mesh(drum, stone, origin + Vector3(6.2, 0.5, 1.0), parent)
	d.rotation = Vector3(0, 0.6, PI / 2.0)
	colliders.append(Vector3(origin.x + 6.2, origin.z + 1.0, 0.8))
	return colliders
