extends RefCounted
const Explosion = preload("res://scripts/explosion.gd")
const Trail = preload("res://scripts/trail.gd")
const Campfire = preload("res://scripts/campfire.gd")
# Прогрев: все символы Label3D (взрыв, шлейф, костёр) рисуются один раз при старте —
# иначе растеризация глифов и компиляция шейдера дают разовое замирание на первом взрыве.

const FRAMES := 3

# Уникальные символы всех эффектов.
static func chars() -> String:
	var all: Array = Explosion.CHARS + Trail.CHARS + Campfire.SMOKE_CHARS
	for row in Campfire.ROW_CHARS:
		all += row
	var out := ""
	for c in all:
		if not out.contains(c):
			out += c
	return out

# Узел с метками тех же параметров, что в эффектах; прозрачность <1 — чтобы собрать и прозрачный вариант шейдера.
static func make_node(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	var s := chars()
	for i in s.length():
		var l := Label3D.new()
		l.text = s[i]
		l.font_size = 48
		l.pixel_size = 0.01
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate.a = 0.5
		l.position = Vector3(i * 0.2, 0, 0)
		n.add_child(l)
	parent.add_child(n)
	return n
