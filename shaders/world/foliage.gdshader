shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/common/noise.gdshaderinc"

uniform vec3 leaf_dark : source_color = vec3(0.07, 0.16, 0.04);
uniform vec3 leaf_light : source_color = vec3(0.36, 0.50, 0.12);
uniform bool pine = false;
uniform float wind = 1.0;

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float hgt = max(VERTEX.y - 1.5, 0.0);
	float sway = sin(TIME * 1.1 + origin.x * 0.2 + origin.z * 0.13) * 0.015 * hgt * wind;
	float flutter = sin(TIME * 4.0 + w.x * 2.0 + w.y * 3.0) * 0.03 * COLOR.r * wind;
	VERTEX.x += sway + flutter;
	VERTEX.z += sway * 0.6;
	wpos = w;
}

float leaf_pattern(vec2 uv) {
	vec2 g = uv * 3.2;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float m = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 o = hash22(id + n);
			vec2 p = n + o - f;
			float a = hash21(id + n) * 6.283;
			mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
			p = r * p;
			float d = length(p * vec2(1.0, 2.1));
			m = max(m, 1.0 - smoothstep(0.34, 0.38, d));
		}
	}
	return m;
}

float pine_pattern(vec2 uv) {
	float across = abs(uv.y - 0.5) * 2.0;
	float shape = step(across, (1.0 - uv.x) * 0.92 + 0.08);
	float needles = step(0.4, fract(uv.x * 26.0 - across * 4.0));
	float spine = step(across, 0.07);
	return shape * max(needles, spine);
}

void fragment() {
	float a;
	if (pine) {
		a = pine_pattern(UV);
	} else {
		a = leaf_pattern(UV) * (1.0 - smoothstep(0.36, 0.5, length(UV - 0.5)));
	}
	a = max(a, 1.0 - COLOR.a);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float v = fbm(wpos * 0.6);
	vec3 c = mix(leaf_dark, leaf_light, clamp(COLOR.r * 0.85 + (v - 0.5) * 0.5, 0.0, 1.0));
	if (COLOR.a < 0.5) {
		// Solid canopy core: leafy clumps instead of a smooth dark ball.
		float lp = pine ? pine_pattern(fract(wpos.xz * 0.9 + wpos.y * 0.3)) : leaf_pattern(wpos.xz * 0.7 + vec2(wpos.y * 0.45));
		c *= 0.8 + 0.5 * lp;
	}
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.7;
	AO = COLOR.a < 0.5 ? 0.85 : mix(0.35, 1.0, COLOR.r);
	AO_LIGHT_AFFECT = 0.6;
}
