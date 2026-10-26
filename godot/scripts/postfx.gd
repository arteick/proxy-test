extends RefCounted
const Ascii = preload("res://scripts/ascii.gd")
# ASCII-постобработка: 3D с шейдером рисуется в SubViewport (атлас символов — в другом), затем два вьюпорта-«истории» сглаживают кадры во времени.

const TAU := 0.06 # постоянная времени сглаживания, с

var ascii: ShaderMaterial
var hist: ShaderMaterial # смешивание текущего кадра с прошлым
var copy: ShaderMaterial # копия результата для следующего кадра
var scene_vp: SubViewport
var history: Array = [] # SubViewport'ы истории (размер = размеру окна)

# Доля прошлого кадра: не зависит от частоты кадров.
static func keep(dt: float) -> float:
	return exp(-dt / TAU)

# Переносит камеру в SubViewport с общим миром, добавляет ASCII-проход и вывод со сглаживанием.
func build(parent: Node3D, cam: Camera3D) -> void:
	var root := parent.get_viewport()
	root.disable_3d = true # 3D рисует только scene_vp
	var atlas_vp: SubViewport = SubViewport.new()
	atlas_vp.set_script(load("res://scripts/atlas.gd"))
	parent.add_child(atlas_vp)
	scene_vp = SubViewport.new()
	scene_vp.world_3d = parent.get_world_3d()
	parent.add_child(scene_vp)
	cam.reparent(scene_vp, false)
	ascii = ShaderMaterial.new()
	ascii.shader = load("res://shaders/ascii.gdshader")
	ascii.set_shader_parameter("atlas", atlas_vp.get_texture())
	ascii.set_shader_parameter("n_glyphs", float(Ascii.RAMP.length()))
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = ascii
	mi.extra_cull_margin = 16384.0
	cam.add_child(mi)

	var shader: Shader = load("res://shaders/temporal.gdshader")
	var a := _history_vp(parent, shader)
	var b := _history_vp(parent, shader)
	hist = a[1]
	copy = b[1]
	hist.set_shader_parameter("cur", scene_vp.get_texture())
	hist.set_shader_parameter("prev", b[0].get_texture())
	copy.set_shader_parameter("cur", a[0].get_texture())
	copy.set_shader_parameter("prev", a[0].get_texture())
	copy.set_shader_parameter("keep", 0.0)
	var layer := CanvasLayer.new()
	layer.layer = -1 # под HUD
	var out := TextureRect.new()
	out.texture = a[0].get_texture()
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	out.stretch_mode = TextureRect.STRETCH_SCALE
	out.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(out)
	parent.add_child(layer)
	history = [a[0], b[0]]
	root.size_changed.connect(_resize.bind(root))
	_resize(root)

func _history_vp(parent: Node, shader: Shader) -> Array:
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var m := ShaderMaterial.new()
	m.shader = shader
	var r := ColorRect.new()
	r.material = m
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(r)
	parent.add_child(vp)
	return [vp, m]

func _resize(root: Viewport) -> void:
	var s := Vector2i(root.get_visible_rect().size)
	scene_vp.size = s
	for vp in history:
		vp.size = s

# Каждый кадр: сколько прошлого кадра сохранить.
func update(dt: float) -> void:
	hist.set_shader_parameter("keep", keep(dt))
