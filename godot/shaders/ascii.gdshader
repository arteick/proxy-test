shader_type spatial;
render_mode unshaded, depth_test_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D atlas : filter_linear;
uniform float cell = 10.0;
uniform float n_glyphs = 10.0;
uniform float fade_near = 10.0;
uniform float fade_far = 36.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 res = vec2(textureSize(screen_tex, 0));
	vec2 px = SCREEN_UV * res;
	vec2 cell_id = floor(px / cell);
	vec2 local = fract(px / cell);
	vec2 cuv = (cell_id + 0.5) * cell / res;

	vec3 col = texture(screen_tex, cuv).rgb;
	float d = texture(depth_tex, cuv).x;
	vec4 v = INV_PROJECTION_MATRIX * vec4(cuv * 2.0 - 1.0, d, 1.0);
	float dist = -(v.xyz / v.w).z;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	lum = pow(clamp(lum * 1.2, 0.0, 1.0), 0.8);
	float idx = floor(lum * (n_glyphs - 1.0) + 0.5);
	float cov = texture(atlas, vec2((idx + local.x) / n_glyphs, local.y)).r;

	float fade = smoothstep(fade_near, fade_far, dist);
	float solid = mix(0.05, 0.55, lum); // вдали символ растворяется в сплошной цвет
	float val = mix(cov, solid, fade);
	vec3 tint = mix(vec3(1.0), col / max(lum, 0.04), 0.85);
	vec3 outc = tint * val * (0.35 + 1.1 * lum) + col * 0.10;
	vec2 q = SCREEN_UV - 0.5;
	outc *= 1.0 - dot(q, q) * 0.9;
	ALBEDO = outc;
}
