extends RefCounted
# Огненный шар мага: логика состояний без сцены (тестируется headless) и маленькая модель-вид.
# ЛКМ удержание — раскрутка посоха и рост шара; отпустить — шар летит к курсору (но не дальше MAX_RANGE) и взрывается в точке падения;
# ПКМ при удержании ЛКМ — отмена, шар гаснет.

const CHARGE_TIME := 2.0 # секунд до полного шара
const MIN_CHARGE := 0.15 # меньший шар при отпускании просто гаснет
const FADE_TIME := 1.5
const FLY_SPEED := 6.0 # шар летит медленно
const MAX_RANGE := 14.0 # дальность полёта по земле; курсор дальше — шар падает на границе
const LAND_Y := 0.3 # высота центра шара в точке падения
const SLOW := 0.4 # множитель скорости героя при раскрутке
const MAX_RADIUS := 0.7

var state := "charging" # charging | flying | exploded | fading | gone
var charge := 0.0
var fade := 1.0
var start := Vector3.ZERO
var end := Vector3.ZERO
var dist := 1.0
var travelled := 0.0
var pos := Vector3.ZERO
var dir := Vector3.ZERO

# Герой замедляется, только пока шар копится.
static func speed_mult(ball) -> float:
	return SLOW if ball != null and ball.state == "charging" else 1.0

func radius() -> float:
	return MAX_RADIUS * (0.15 + 0.85 * charge) * fade

# Один шаг. lmb/rmb — кнопки мыши сейчас. Отпускание ЛКМ запускает шар (state -> flying), ПКМ — отмена (fading).
func update(dt: float, lmb: bool, rmb: bool) -> void:
	match state:
		"charging":
			if rmb and lmb:
				state = "fading"
			elif not lmb:
				state = "flying" if charge >= MIN_CHARGE else "gone"
			else:
				charge = minf(1.0, charge + dt / CHARGE_TIME)
		"flying":
			travelled += FLY_SPEED * dt
			if travelled >= dist:
				pos = end
				state = "exploded"
			else:
				pos = start + dir * travelled
		"fading":
			fade -= dt / FADE_TIME
			if fade <= 0.0:
				state = "gone"

# Точка падения: на земле в сторону pt (точка под курсором), не дальше MAX_RANGE от героя; курсор над героем — вперёд (-Z).
static func aim_target(origin: Vector3, pt: Vector3) -> Vector3:
	var d := Vector3(pt.x - origin.x, 0.0, pt.z - origin.z)
	if d.length() < 0.001:
		d = Vector3(0, 0, -1)
	return Vector3(origin.x, 0.0, origin.z) + d.normalized() * minf(d.length(), MAX_RANGE)

# Запуск из точки from в точку падения target (земля): шар по прямой снижается до LAND_Y.
func launch(from: Vector3, target: Vector3) -> void:
	start = from
	pos = from
	end = Vector3(target.x, LAND_Y, target.z)
	dist = maxf(from.distance_to(end), 0.001)
	dir = (end - from) / dist
	travelled = 0.0

static func make_node(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ff7a1a")
	m.emission_enabled = true
	m.emission = Color("ff5a00")
	m.emission_energy_multiplier = 3.0
	var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0
	s.radial_segments = 12; s.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color("ff7a1a")
	l.omni_range = 8.0
	n.add_child(l)
	n.set_meta("light", l)
	parent.add_child(n)
	return n

# scale_k — масштаб героя (Move.marker_scale), чтобы шар не терялся на дальнем виде.
static func apply(n: Node3D, ball, scale_k: float, t: float) -> void:
	var r: float = ball.radius() * scale_k * (1.0 + sin(t * 18.0) * 0.06)
	n.position = ball.pos
	n.scale = Vector3.ONE * maxf(r, 0.001)
	n.get_meta("light").light_energy = 2.5 * ball.fade * (0.3 + 0.7 * ball.charge) / maxf(r, 0.001)
