extends Node3D
# Окружение и свет: полусферное небо/земля, тёплый ключевой свет за курсором, холодный контровой.

const KEY_ENERGY := 6.0

var key: OmniLight3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("070910")
	# полусферный свет как в Three.js-прототипе: небо 7080b8 сверху, земля 2a2018 снизу
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("7080b8")
	sky_mat.sky_horizon_color = Color("4a5070")
	sky_mat.ground_horizon_color = Color("4a5070")
	sky_mat.ground_bottom_color = Color("2a2018")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.tonemap_exposure = 1.0
	add_child(env)

	key = OmniLight3D.new()
	key.light_color = Color("ffc680")
	key.omni_range = 40.0
	key.light_energy = KEY_ENERGY
	key.omni_attenuation = 1.4
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("5aa0ff")
	rim.omni_range = 30.0
	rim.light_energy = 3.0
	rim.omni_attenuation = 1.4
	rim.position = Vector3(-3, 2.5, -5)
	add_child(rim)

# Вспышка при ударе.
func flash() -> void:
	key.light_energy = 14.0

# base — позиция героя, m — курсор в долях экрана (0..1), t — время.
func follow(base: Vector3, m: Vector2, t: float, dt: float) -> void:
	key.position = base + Vector3((m.x - 0.5) * 12.0, 1.2 + (1.0 - m.y) * 5.0, 2.0 + sin(t * 0.7))
	key.light_energy = lerpf(key.light_energy, KEY_ENERGY, minf(1.0, dt * 5.0))
