extends RefCounted
# Мини-взрыв при падении шара: горстка ASCII-символов разлетается в стороны (цвета как пол), на земле остаётся выжженное пятно.
# Логика частиц без сцены (тестируется headless) + узлы Label3D и пятно из тёмных дисков.

const COUNT := 16
const LIFE := 1.0
const GRAVITY := 14.0
const GROUND_Y := 0.1
const CHARS := ["*", ":", ".", "'", "`", ",", "+", "o"]
const COLORS := [Color("b0b2ba"), Color("8f9199"), Color("4c8c3c"), Color("3a6f2e")] # камень и трава, как в Level.floor_image
const SCORCH_MAX := 24 # старые пятна исчезают, чтобы не копились

var age := 0.0
var parts: Array = [] # {pos, vel, ch, col}

static func make(center: Vector3, seed_v: int) -> RefCounted:
	var ex = load("res://scripts/explosion.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in COUNT:
		var a := rng.randf() * TAU
		var sp := rng.randf_range(2.0, 5.0)
		ex.parts.append({
			"pos": center + Vector3(0, 0.2, 0),
			"vel": Vector3(cos(a) * sp, rng.randf_range(3.0, 6.0), sin(a) * sp),
			"ch": CHARS[rng.randi() % CHARS.size()],
			"col": COLORS[rng.randi() % COLORS.size()]})
	return ex

func update(dt: float) -> void:
	age += dt
	for p in parts:
		if p.pos.y <= GROUND_Y and p.vel.y <= 0.0:
			p.vel = p.vel * maxf(0.0, 1.0 - 8.0 * dt) # упал на землю — скользит и останавливается
			p.vel.y = 0.0
		else:
			p.vel.y -= GRAVITY * dt
		p.pos += p.vel * dt
		p.pos.y = maxf(p.pos.y, GROUND_Y)

func done() -> bool:
	return age >= LIFE

# Непрозрачность символов: первую половину полная, затем гаснут.
func alpha() -> float:
	return clampf((LIFE - age) / (LIFE * 0.5), 0.0, 1.0)

# Диски пятна: Vector3(смещение x, смещение z, радиус) — несколько перекрывающихся кругов, чтобы край был неровным.
static func scorch_discs(seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = [Vector3(0, 0, 1.3)]
	for i in 4:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.4, 0.9)
		out.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.5, 0.9)))
	return out

# Узел с символами; scale_k — масштаб героя (Move.marker_scale), чтобы символы не терялись на дальнем виде.
static func make_node(parent: Node3D, ex) -> Node3D:
	var n := Node3D.new()
	for p in ex.parts:
		var l := Label3D.new()
		l.text = p.ch
		l.font_size = 48
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = p.col
		n.add_child(l)
	parent.add_child(n)
	return n

static func apply(n: Node3D, ex, scale_k: float) -> void:
	var a: float = ex.alpha()
	for i in ex.parts.size():
		var l: Label3D = n.get_child(i)
		l.position = ex.parts[i].pos
		l.scale = Vector3.ONE * scale_k
		l.modulate.a = a

# Выжженное пятно на земле: тёмные плоские диски чуть выше пола (разная высота — без мерцания).
static func make_scorch(parent: Node3D, center: Vector3, seed_v: int) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(center.x, 0.0, center.z)
	var discs := scorch_discs(seed_v)
	for i in discs.size():
		var d: Vector3 = discs[i]
		var c := CylinderMesh.new()
		c.top_radius = d.z; c.bottom_radius = d.z; c.height = 0.01
		c.radial_segments = 14; c.rings = 1
		var m := StandardMaterial3D.new()
		var v := 0.03 + 0.03 * float(i % 3)
		m.albedo_color = Color(v, v * 0.9, v * 0.85)
		m.roughness = 1.0
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = m
		mi.position = Vector3(d.x, 0.02 + 0.004 * i, d.y)
		n.add_child(mi)
	parent.add_child(n)
	return n
