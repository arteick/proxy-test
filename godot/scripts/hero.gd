extends Node3D
# Герой-маг: модель целиком в коде и анимация ходьбы. world.gd только двигает узел и вызывает animate().

const CAPE_SEGS := 4
const CAPE_LEN := 0.42

var body := Node3D.new()
var staff := Node3D.new()
var cape_segs: Array = []
var cape_lag := 0.0
var step_phase := 0.0
var amp := 0.0
var prev_face := 0.0
var arm_l := Node3D.new(); var arm_r := Node3D.new()
var leg_l := Node3D.new(); var leg_r := Node3D.new()

func _ready() -> void:
	_build()

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _build() -> void:
	# маг: угловатый силуэт (плечи, прямоугольные конечности), синяя мантия, шляпа, посох в коричневых тонах.
	# body — всё, что наклоняется и покачивается при ходьбе; ноги остаются на земле.
	add_child(body)
	var skin := _mat(Color("e8c9a0"), 0.7)
	var robe := _mat(Color("2a4fc4"), 0.7)
	var robe_dark := _mat(Color("1b2f7a"), 0.75)
	var wood := _mat(Color("6b4423"), 0.85)
	var wood_dark := _mat(Color("4a2e15"), 0.9)
	var wood_light := _mat(Color("8f6236"), 0.8)
	var skirt := CylinderMesh.new(); skirt.top_radius = 0.3; skirt.bottom_radius = 0.62; skirt.height = 1.5
	skirt.radial_segments = 8
	_mesh(skirt, robe, Vector3(0, 0.8, 0), body)
	# торс: широкие плечи, узкая талия
	_mesh(_box(Vector3(0.74, 0.5, 0.42)), robe, Vector3(0, 1.72, 0), body)
	_mesh(_box(Vector3(0.52, 0.45, 0.36)), robe_dark, Vector3(0, 1.32, 0), body)
	_mesh(_box(Vector3(0.56, 0.1, 0.4)), wood_dark, Vector3(0, 1.12, 0), body)
	# голова: куб с носом и бородой
	_mesh(_box(Vector3(0.38, 0.44, 0.38)), skin, Vector3(0, 2.18, 0), body)
	_mesh(_box(Vector3(0.1, 0.12, 0.12)), skin, Vector3(0, 2.14, -0.24), body)
	var beard := PrismMesh.new(); beard.size = Vector3(0.34, 0.4, 0.1)
	var bd := _mesh(beard, _mat(Color("d8d8e0"), 0.9), Vector3(0, 1.95, -0.2), body)
	bd.rotation.x = PI
	var brim := CylinderMesh.new(); brim.top_radius = 0.5; brim.bottom_radius = 0.5; brim.height = 0.06
	brim.radial_segments = 8
	_mesh(brim, robe_dark, Vector3(0, 2.42, 0), body)
	var hat := CylinderMesh.new(); hat.top_radius = 0.0; hat.bottom_radius = 0.32; hat.height = 0.8
	hat.radial_segments = 6
	var hat_mi := _mesh(hat, robe, Vector3(0, 2.84, 0), body)
	hat_mi.rotation.x = 0.12
	_build_robe_texture(robe, robe_dark)
	var feet := _mat(Color("2b1d12"), 0.9)
	# руки: левая машет, правая держит посох
	for l in [[arm_l, -0.5], [arm_r, 0.5]]:
		var pivot: Node3D = l[0]
		pivot.position = Vector3(l[1], 1.88, 0)
		body.add_child(pivot)
		_mesh(_box(Vector3(0.2, 0.8, 0.2)), robe, Vector3(0, -0.4, 0), pivot)
		_mesh(_box(Vector3(0.14, 0.14, 0.14)), skin, Vector3(0, -0.85, 0), pivot)
	for l in [[leg_l, -0.2], [leg_r, 0.2]]:
		var pivot: Node3D = l[0]
		pivot.position = Vector3(l[1], 0.5, 0)
		add_child(pivot)
		_mesh(_box(Vector3(0.2, 0.55, 0.24)), feet, Vector3(0, -0.22, 0), pivot)
		_mesh(_box(Vector3(0.22, 0.12, 0.34)), feet, Vector3(0, -0.46, -0.05), pivot)
	# посох в правой руке: pivot в кисти, наклон задаётся в _animate
	arm_r.add_child(staff)
	staff.position = Vector3(0, -0.85, 0)
	var shaft := CylinderMesh.new(); shaft.top_radius = 0.04; shaft.bottom_radius = 0.05; shaft.height = 2.45
	shaft.radial_segments = 6
	_mesh(shaft, wood, Vector3(0, 0.225, 0), staff)
	var knob := CylinderMesh.new(); knob.top_radius = 0.07; knob.bottom_radius = 0.07; knob.height = 0.12
	knob.radial_segments = 6
	_mesh(knob, wood_dark, Vector3(0, 0.7, 0), staff)
	_mesh(knob, wood_dark, Vector3(0, -0.7, 0), staff)
	var head_s := SphereMesh.new(); head_s.radius = 0.13; head_s.height = 0.26
	head_s.radial_segments = 8; head_s.rings = 4
	_mesh(head_s, wood_light, Vector3(0, 1.35, 0), staff)
	var claw := TorusMesh.new(); claw.inner_radius = 0.1; claw.outer_radius = 0.17
	claw.rings = 6; claw.ring_segments = 6
	_mesh(claw, wood_dark, Vector3(0, 1.52, 0), staff)

func _build_robe_texture(robe: Material, robe_dark: Material) -> void:
	# «фактура» мантии объёмом: складки и подол вокруг корпуса, воротник, широкие рукава.
	# После ASCII-шейдера разная яркость/наклон граней даёт разные символы, а не один цвет.
	var trim := _mat(Color("d8b44a"), 0.5)
	for i in 12:
		var a := TAU * i / 12.0
		var fold := BoxMesh.new(); fold.size = Vector3(0.1, 1.45, 0.2)
		var f := _mesh(fold, robe_dark if i % 2 else robe, Vector3(sin(a) * 0.5, 0.78, cos(a) * 0.5), body)
		f.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.2)
		var tooth := PrismMesh.new(); tooth.size = Vector3(0.3, 0.22, 0.1)
		var h := _mesh(tooth, trim if i % 3 == 0 else robe_dark, Vector3(sin(a) * 0.66, 0.1, cos(a) * 0.66), body)
		h.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI)
	var hem := TorusMesh.new(); hem.inner_radius = 0.58; hem.outer_radius = 0.68
	hem.rings = 8; hem.ring_segments = 6
	_mesh(hem, trim, Vector3(0, 0.12, 0), body)
	# плащ-шлейф: цепочка сегментов от плеч; каждый следующий — ребёнок предыдущего,
	# поэтому изгиб накапливается и низ виляет сильнее верха (персонаж смотрит в -Z, спина в +Z)
	var parent: Node3D = body
	for j in CAPE_SEGS:
		var seg := Node3D.new()
		seg.position = Vector3(0, 1.92, 0.24) if j == 0 else Vector3(0, -CAPE_LEN, 0)
		parent.add_child(seg)
		var cape := _box(Vector3(0.8 - j * 0.07, CAPE_LEN + 0.02, 0.05))
		_mesh(cape, robe_dark if j % 2 == 0 else robe, Vector3(0, -CAPE_LEN / 2.0, 0), seg)
		cape_segs.append(seg)
		parent = seg
	var collar := TorusMesh.new(); collar.inner_radius = 0.26; collar.outer_radius = 0.42
	collar.rings = 8; collar.ring_segments = 6
	_mesh(collar, trim, Vector3(0, 1.98, 0), body)
	var sash := BoxMesh.new(); sash.size = Vector3(0.14, 1.0, 0.04)
	var sh := _mesh(sash, trim, Vector3(0, 0.95, -0.52), body)
	sh.rotation.x = -0.22
	for side in [-0.5, 0.5]:
		var sleeve := _box(Vector3(0.3, 0.3, 0.3))
		_mesh(sleeve, robe_dark, Vector3(side, 1.88, 0), body)

func animate(dt: float, moving: bool, t: float) -> void:
	var turn := angle_difference(prev_face, rotation.y) / maxf(dt, 0.001)
	prev_face = rotation.y
	var k := 1.0 if moving else 0.0
	amp = lerpf(amp, k, minf(1.0, dt * 8.0))
	step_phase += dt * 9.0 * k
	var s := sin(step_phase)
	var c := cos(step_phase)
	# ноги и левая рука идут в противофазе; корпус кивает на каждом шаге, крутится плечами и кренится
	leg_l.rotation.x = -s * 0.7 * amp; leg_r.rotation.x = s * 0.7 * amp
	arm_l.rotation.x = s * 0.5 * amp
	body.position.y = absf(c) * 0.09 * amp
	body.rotation.x = -0.14 * amp
	body.rotation.y = s * 0.14 * amp
	body.rotation.z = -s * 0.05 * amp
	# правая рука держит посох: вынесена вперёд, посох упирается в землю впереди и качается с шагом
	arm_r.rotation.x = lerpf(-0.3, -0.45, amp)
	var tilt := lerpf(0.05, 0.4 + c * 0.12, amp)
	staff.rotation.x = tilt - arm_r.rotation.x
	# шлейф: пружина по скорости поворота героя (влево-вправо) + волна вдоль ткани при ходьбе
	cape_lag = lerpf(cape_lag, clampf(-turn * 0.06, -0.8, 0.8), minf(1.0, dt * 6.0))
	for i in cape_segs.size():
		var seg: Node3D = cape_segs[i]
		seg.rotation.x = -0.04 - 0.16 * amp
		seg.rotation.y = cape_lag * 0.5 + sin(t * 6.0 - i * 0.9) * 0.16 * amp
		seg.rotation.z = cape_lag * 0.35 + sin(t * 6.0 - i * 0.9 + 1.2) * 0.1 * amp
