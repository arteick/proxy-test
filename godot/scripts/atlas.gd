extends SubViewport
# Рисует строку RAMP в одну текстуру-атлас: по одной ячейке G×G на символ.

const G := 32

func _ready() -> void:
	size = Vector2i(G * Ascii.RAMP.length(), G)
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Control.new()
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color.BLACK)
		var font := ThemeDB.fallback_font
		for i in Ascii.RAMP.length():
			var w := font.get_char_size(Ascii.RAMP.unicode_at(i), int(G * 0.9)).x
			canvas.draw_char(font, Vector2(i * G + (G - w) / 2.0, G * 0.82),
				Ascii.RAMP[i], int(G * 0.9), Color.WHITE))
	add_child(canvas)
	canvas.queue_redraw()
