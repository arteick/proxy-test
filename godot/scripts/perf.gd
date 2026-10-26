# Счётчик кадров для HUD: FPS и худший кадр за окно (видно, где именно игра замирает).

const WINDOW := 1.0

var frames := 0
var acc := 0.0
var worst := 0.0
var fps := 0
var peak_ms := 0

# delta — реальное время кадра (до ограничения dt).
func update(delta: float) -> void:
	frames += 1
	acc += delta
	worst = maxf(worst, delta)
	if acc >= WINDOW:
		fps = roundi(frames / acc)
		peak_ms = roundi(worst * 1000.0)
		frames = 0
		acc = 0.0
		worst = 0.0

func text() -> String:
	return "%d к/с, пик %d мс" % [fps, peak_ms]
