# Камера для зрелищности: плавное следование за героем и тряска от взрывов и ударов (логика без сцены, тестируется headless).

const FOLLOW := 6.0 # скорость догоняния героя, 1/с
const SHAKE_DECAY := 3.0 # затухание тряски, 1/с
const SHAKE_MAX := 0.35 # предел смещения камеры, м

var focus := Vector3.ZERO
var shake := 0.0

func snap(p: Vector3) -> void:
	focus = p
	shake = 0.0

func kick(power: float) -> void:
	shake = minf(shake + power, 1.0)

# Возвращает точку, на которую смотрит камера; t — время для фазы тряски.
func update(target: Vector3, dt: float, t: float) -> Vector3:
	focus = focus.lerp(target, minf(1.0, dt * FOLLOW))
	shake = maxf(0.0, shake - dt * SHAKE_DECAY)
	var s := shake * shake * SHAKE_MAX
	return focus + Vector3(sin(t * 53.0), 0.0, cos(t * 47.0)) * s
