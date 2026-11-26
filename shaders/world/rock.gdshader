shader_type spatial;
#include "res://shaders/common/noise.gdshaderinc"

uniform vec3 base_a : source_color = vec3(0.46, 0.44, 0.41);
uniform vec3 base_b : source_color = vec3(0.22, 0.21, 0.20);
uniform vec3 moss : source_color = vec3(0.17, 0.27, 0.07);
uniform float moss_amount = 0.75;
uniform float scale = 0.8;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm(wp * scale);
	float n2 = fbm(wp * scale * 6.0);
	float cracks = smoothstep(0.02, 0.0, abs(fbm(wp * scale * 2.0) - 0.5) - 0.01);
	vec3 c = mix(base_b, base_a, smoothstep(0.3, 0.7, n)) * (0.88 + 0.24 * n2);
	c *= 1.0 - cracks * 0.3;
	float m = smoothstep(0.5, 0.85, wn.y + (n - 0.5) * 0.6) * moss_amount;
	c = mix(c, moss * (0.7 + 0.6 * n2), m);

	float bump = n2 + cracks * 0.3;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(bump) * r1 + dFdy(bump) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.25);

	ALBEDO = c;
	ROUGHNESS = mix(0.8, 0.95, m);
	SPECULAR = 0.35;
}
