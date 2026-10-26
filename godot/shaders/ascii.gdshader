shader_type spatial;
render_mode unshaded, depth_test_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D atlas : filter_linear;
uniform float cell = 10.0;
uniform float n_glyphs = 10.0;
uniform float far_blend = 0.0; // 0 — символы, 1 — дальний вид: плоские насыщенные цвета с контуром

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(sampler2D dt, vec2 uv, mat4 inv_proj) {
	float d = texture(dt, uv).x;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(v.xyz / v.w).z;
}

void fragment() {
	vec2 res = vec2(textureSize(screen_tex, 0));
	vec2 px = SCREEN_UV * res;
	vec2 cell_id = floor(px / cell);
	vec2 local = fract(px / cell);
	vec2 cuv = (cell_id + 0.5) * cell / res;
	vec2 step_uv = vec2(cell) / res;

	vec3 col = texture(screen_tex, cuv).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	lum = pow(clamp(lum * 1.2, 0.0, 1.0), 0.8);
	float idx = floor(lum * (n_glyphs - 1.0) + 0.5);
	float cov = texture(atlas, vec2((idx + local.x) / n_glyphs, local.y)).r;

	// контур по перепаду глубины между соседними ячейками: силуэты читаются и без символов
	float d0 = lin_depth(depth_tex, cuv, INV_PROJECTION_MATRIX);
	float edge = max(max(abs(lin_depth(depth_tex, cuv + vec2(step_uv.x, 0.0), INV_PROJECTION_MATRIX) - d0), abs(lin_depth(depth_tex, cuv - vec2(step_uv.x, 0.0), INV_PROJECTION_MATRIX) - d0)),
		max(abs(lin_depth(depth_tex, cuv + vec2(0.0, step_uv.y), INV_PROJECTION_MATRIX) - d0), abs(lin_depth(depth_tex, cuv - vec2(0.0, step_uv.y), INV_PROJECTION_MATRIX) - d0)));
	float outline = smoothstep(0.6, 1.5, edge);

	// вдали: сплошной цвет с повышенными насыщенностью и контрастом
	float solid = mix(0.05, 0.55, lum);
	float val = mix(cov, solid, far_blend);
	vec3 tint = mix(vec3(1.0), col / max(lum, 0.04), 0.85);
	vec3 outc = tint * val * (0.45 + 1.3 * lum) + col * 0.12;
	// усреднение по ячейке и по соседям: шум пола сглаживается, а значки выделяются локальным контрастом
	vec3 avg = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 o = vec2(float(i % 2) - 0.5, float(i / 2) - 0.5) * 0.5 * step_uv;
		avg += texture(screen_tex, cuv + o).rgb * 0.25;
	}
	vec3 ring = vec3(0.0);
	for (int j = 0; j < 8; j++) {
		float a = float(j) * 0.785398;
		ring += texture(screen_tex, cuv + vec2(cos(a), sin(a)) * step_uv * 2.5).rgb * 0.125;
	}
	vec3 pop = avg + (avg - ring) * 0.5;
	float plum = dot(pop, vec3(0.299, 0.587, 0.114));
	vec3 flat_c = max(mix(vec3(plum), pop, 1.2), 0.0) * 1.1 + 0.02;
	// предметы над полом: глубина отличается от среднего по симметричному кольцу (плоскость пола кольцо гасит)
	float dr = 0.25 * (lin_depth(depth_tex, cuv + vec2(step_uv.x, 0.0) * 2.0, INV_PROJECTION_MATRIX) + lin_depth(depth_tex, cuv - vec2(step_uv.x, 0.0) * 2.0, INV_PROJECTION_MATRIX)
		+ lin_depth(depth_tex, cuv + vec2(0.0, step_uv.y) * 2.0, INV_PROJECTION_MATRIX) + lin_depth(depth_tex, cuv - vec2(0.0, step_uv.y) * 2.0, INV_PROJECTION_MATRIX));
	float obj = smoothstep(0.25, 1.0, abs(d0 - dr));
	flat_c *= mix(0.55, 1.6, obj);
	outc = mix(outc, flat_c, far_blend);
	outc = mix(outc, outc * 0.25, outline * (0.5 + 0.5 * far_blend));
	vec2 q = SCREEN_UV - 0.5;
	outc *= 1.0 - dot(q, q) * 0.5;
	ALBEDO = outc;
}
