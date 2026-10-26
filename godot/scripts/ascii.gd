
# от пустого к плотному: 70 разных ASCII-символов (классическая шкала плотности)
const RAMP := " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"

static func glyph_index(lum: float, n: int = RAMP.length()) -> int:
	return roundi(clampf(lum, 0.0, 1.0) * (n - 1))

# 0 вблизи (символы видны), 1 вдали (сплошной цвет)
static func cell_fade(dist: float, near: float, far: float) -> float:
	return smoothstep(near, far, dist)
