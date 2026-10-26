extends RefCounted
const Props = preload("res://scripts/props.gd")
# Костёр: пламя из ASCII-символов извивается (сдвиг растёт с высотой, фаза бежит вверх),
# дым — по одной частице за раз, поднимается на один символ над разными местами костра.
# Логика без сцены (тестируется headless) + узлы Label3D, дрова и мерцающий свет.

const POS := Vector3(2.5, 0.0, -3.0)
const HALF := [2, 2, 1, 0] # половина ширины ряда пламени (в ячейках); ряды снизу вверх
const CELL_W := 0.2
const ROW_H := 0.3
const ROW_CHARS := [["#", "@", "%"], ["&", "8", "*"], ["^", "*", "~"], ["'", "`", "^"]]
const ROW_COLORS := [Color("d63c08"), Color("ff6a10"), Color("ff9a1a"), Color("ffd23a")]
const SMOKE_CHARS := [".", "'", ",", "`", "°"]
const SMOKE_COLOR := Color("9a9aa2")
const SMOKE_LIFE := 1.0
const SMOKE_RISE := 0.35 # один символ вверх
const SMOKE_GAP := 0.7 # пауза между частицами: пока одна жива, второй нет
const SMOKE_BASE_Y := 1.25
const FIRST_LABEL := 8 # метки идут после дров (2 полена + 6 камней)

var smoke: Dictionary = {} # {x, age, ch} или пусто
var wait := 0.3
var n := 0

# Ячейки пламени в момент t: {pos, ch, col, on}. Края языков мерцают, середина горит всегда.
static func cells(t: float) -> Array:
	var out: Array = []
	for r in HALF.size():
		var sway := sin(t * 4.5 - r * 1.1) * 0.06 * (r + 1) + sin(t * 2.3 - r * 0.7) * 0.04 * r
		for c in range(-HALF[r], HALF[r] + 1):
			var chars: Array = ROW_CHARS[r]
			out.append({
				"pos": Vector3(c * CELL_W + sway, 0.3 + r * ROW_H, 0.0),
				"ch": chars[int(floor(t * 8.0 + c * 3 + r)) % chars.size()],
				"col": ROW_COLORS[r],
				"on": c == 0 or sin(t * 9.0 + r * 2.3 + c * 4.1) > -0.1 + 0.1 * r})
	return out

func update(dt: float) -> void:
	if not smoke.is_empty():
		smoke.age += dt
		if smoke.age >= SMOKE_LIFE:
			smoke = {}
			wait = SMOKE_GAP
		return
	wait -= dt
	if wait <= 0.0:
		n += 1
		smoke = {"x": sin(n * 12.9) * 0.4, "age": 0.0, "ch": SMOKE_CHARS[n % SMOKE_CHARS.size()]}

# Положение частицы дыма (или null) и её непрозрачность.
func smoke_pos():
	if smoke.is_empty():
		return null
	return Vector3(smoke.x, SMOKE_BASE_Y + SMOKE_RISE * smoke.age / SMOKE_LIFE, 0.0)

func smoke_alpha() -> float:
	return 0.0 if smoke.is_empty() else 0.8 * (1.0 - smoke.age / SMOKE_LIFE)

static func _label() -> Label3D:
	var l := Label3D.new()
	l.font_size = 48
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l

# Дрова, камни, свет и метки (14 ячеек пламени + 1 дым + свет последним ребёнком).
static func make_node(parent: Node3D, at: Vector3 = POS) -> Node3D:
	var node := Node3D.new()
	node.position = at
	var wood := Props.mat(Color("4a2e1a"), 0.9)
	for a in [0.5, -0.5]:
		var log := CylinderMesh.new()
		log.top_radius = 0.09; log.bottom_radius = 0.09; log.height = 0.9
		Props.mesh(log, wood, Vector3(0, 0.12, 0), node).rotation = Vector3(PI / 2.0, 0, a)
	var stone := Props.mat(Color("8f9199"), 0.85)
	for i in 6:
		var s := SphereMesh.new()
		s.radius = 0.14; s.height = 0.22
		var ang := i * TAU / 6.0
		Props.mesh(s, stone, Vector3(cos(ang) * 0.6, 0.08, sin(ang) * 0.6), node)
	for i in cell_count() + 1: # ячейки пламени + дым
		node.add_child(_label())
	var light := OmniLight3D.new()
	light.light_color = Color("ff8a30")
	light.omni_range = 9.0
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 0.9, 0)
	node.add_child(light)
	parent.add_child(node)
	return node

static func cell_count() -> int:
	var k := 0
	for h in HALF:
		k += 2 * h + 1
	return k

static func apply(node: Node3D, cf, t: float, scale_k: float) -> void:
	node.scale = Vector3.ONE * scale_k
	var cs := cells(t)
	for i in cs.size():
		var l: Label3D = node.get_child(FIRST_LABEL + i)
		l.visible = cs[i].on
		l.position = cs[i].pos
		l.text = cs[i].ch
		l.modulate = cs[i].col
	var sp: Label3D = node.get_child(FIRST_LABEL + cs.size())
	var p = cf.smoke_pos()
	sp.visible = p != null
	if p != null:
		sp.position = p
		sp.text = cf.smoke.ch
		sp.modulate = Color(SMOKE_COLOR, cf.smoke_alpha())
	var light: OmniLight3D = node.get_child(node.get_child_count() - 1)
	light.light_energy = 2.6 + sin(t * 13.0) * 0.5 + sin(t * 7.3) * 0.4
