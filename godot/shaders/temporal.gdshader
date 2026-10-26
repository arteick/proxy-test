shader_type canvas_item;
// Временное сглаживание: новый кадр смешивается с прошлым результатом (keep — доля прошлого).

uniform sampler2D cur : filter_nearest;
uniform sampler2D prev : filter_nearest;
uniform float keep = 0.0;

void fragment() {
	COLOR = vec4(mix(texture(cur, UV).rgb, texture(prev, UV).rgb, keep), 1.0);
}
