const Ascii = preload("res://scripts/ascii.gd")
# ASCII-постобработка: полноэкранный квад на камере с шейдером, атлас символов — в SubViewport.

# Добавляет проход к камере и возвращает материал (параметры шейдера меняются на лету).
static func build(parent: Node, cam: Camera3D) -> ShaderMaterial:
	var atlas_vp: SubViewport = SubViewport.new()
	atlas_vp.set_script(load("res://scripts/atlas.gd"))
	parent.add_child(atlas_vp)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ascii.gdshader")
	mat.set_shader_parameter("atlas", atlas_vp.get_texture())
	mat.set_shader_parameter("n_glyphs", float(Ascii.RAMP.length()))
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	quad.flip_faces = true
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	cam.add_child(mi)
	return mat
