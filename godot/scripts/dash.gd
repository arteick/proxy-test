# Рывок мага без зависимости от сцены (тестируется headless): короткий бросок с неуязвимостью и перезарядкой.

const DURATION := 0.2
const SPEED := 16.0
const COOLDOWN := 1.6

var time_left := 0.0
var cooldown := 0.0
var dir := Vector3.ZERO

func ready() -> bool:
	return time_left <= 0.0 and cooldown <= 0.0

func active() -> bool:
	return time_left > 0.0

# Запускает рывок в направлении d (плоскость XZ). false — рано или направление нулевое.
func start(d: Vector3) -> bool:
	d.y = 0.0
	if not ready() or d.length() < 0.001:
		return false
	dir = d.normalized()
	time_left = DURATION
	cooldown = COOLDOWN
	return true

func update(dt: float) -> void:
	time_left = maxf(0.0, time_left - dt)
	if not active():
		cooldown = maxf(0.0, cooldown - dt)

# Доля готовности 0..1 для HUD.
func charge() -> float:
	return 1.0 - cooldown / COOLDOWN
