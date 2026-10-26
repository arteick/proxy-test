# Статичный уровень: земля и колоннада. Возвращает коллайдеры Vector3(x, z, радиус).
const Props = preload("res://scripts/props.gd")

const COLUMNS := 14
const TILE := 16  # пикселей на плитку; плитка = 2 м

# Пол: каменные плиты вдоль колоннады, вокруг трава. Яркость пятнами — шейдер даст разные символы.
static func floor_image() -> Image:
	var n := TILE * 8
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var tx := x / TILE
			var ty := y / TILE
			var h := int(hash(Vector2i(x, y))) & 255
			var th := int(hash(Vector2i(tx, ty))) & 255
			var edge := x % TILE == 0 or y % TILE == 0
			var c: Color
			if (tx + ty) % 3 == 0:
				var v := 0.40 + (th % 40) / 255.0 + (0.0 if edge else (h % 20) / 255.0)
				c = Color(v, v, v * 1.05)
				if edge: c = c.darkened(0.35)
			else:
				var g := 0.30 + (h % 90) / 255.0
				c = Color(g * 0.55, g, g * 0.45)
			img.set_pixel(x, y, c)
	return img

static func build(parent: Node3D) -> Array:
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var floor_mat := Props.mat(Color.WHITE, 0.95)
	floor_mat.albedo_texture = ImageTexture.create_from_image(floor_image())
	floor_mat.uv1_scale = Vector3(200.0 / 16.0, 200.0 / 16.0, 1.0)  # 8 плиток в текстуре = 16 м
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
