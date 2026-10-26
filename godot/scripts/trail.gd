extends RefCounted
# Шлейф огненного шара: ASCII-искры остаются в воздухе вдоль пути и быстро гаснут.
# Логика без сцены (тестируется headless) + узлы Label3D.

const LIFE := 0.45 # секунд жизни искры
const STEP := 0.25 # расстояние между искрами вдоль полёта
const MAX_PARTS := 40
const CHARS := ["*", "+", ":", ".", "'", "`", "~", "o"]
const COLORS := [Color("ffd23a"), Color("ff9a1a"), Color("ff6a10"), Color("d63c08")]

var parts: Array = [] # {pos, age, ch, col}
var last := Vector3.ZERO
var started := false
var n := 0

# Добавляет искры вдоль отрезка от прошлой позиции до pos, затем старит все.
func update(dt: float, pos: Vector3, emit: bool) -> void:
	for p in parts:
		p.age += dt
	parts = parts.filter(func(p): return p.age < LIFE)
	if not emit:
		return
	if not started:
		started = true
		last = pos
	var d := pos - last
	var dist := d.length()
	while dist >= STEP and parts.size() < MAX_PARTS:
		last += d.normalized() * STEP
		dist -= STEP
		n += 1
		parts.append({"pos": last + Vector3(sin(n * 12.9) * 0.15, sin(n * 7.3) * 0.15, cos(n * 5.1) * 0.15),
			"age": 0.0, "ch": CHARS[n % CHARS.size()], "col": COLORS[(n * 3) % COLORS.size()]})
		d = pos - last

static func alpha(p) -> float:
	return clampf(1.0 - p.age / LIFE, 0.0, 1.0)

# Узел-контейнер; Label3D создаются по мере появления искр.
static func make_node(parent: Node3D) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	return node

static func apply(node: Node3D, tr, scale_k: float) -> void:
	while node.get_child_count() < tr.parts.size():
		var l := Label3D.new()
		l.font_size = 48
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.add_child(l)
	for i in node.get_child_count():
		var l: Label3D = node.get_child(i)
		if i >= tr.parts.size():
			l.visible = false
			continue
		var p = tr.parts[i]
		l.visible = true
		l.text = p.ch
		l.position = p.pos
		l.scale = Vector3.ONE * scale_k * (0.6 + 0.4 * alpha(p))
		l.modulate = p.col
		l.modulate.a = alpha(p)
