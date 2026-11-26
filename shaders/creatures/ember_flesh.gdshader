shader_type spatial;
#include "res://shaders/common/noise.gdshaderinc"
// Charred basalt-like hide split by molten cracks that pulse with heat.

uniform vec3 skin_dark : source_color = vec3(0.045, 0.04, 0.038);
uniform vec3 skin_light : source_color = vec3(0.21, 0.185, 0.17);
uniform vec3 ember : source_color = vec3(1.0, 0.34, 0.07);
uniform float ember_energy = 5.0;
uniform float crack_amount = 0.5;
uniform float crack_scale = 2.4;
uniform float pattern_scale = 1.0;
uniform float hit_flash = 0.0;
uniform float dissolve = 0.0;
uniform float heat = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX * pattern_scale;
}

void fragment() {
	float n = fbm(lp * 2.6);
	float fine = fbm(lp * 14.0);
	vec2 v = voronoi3(lp * crack_scale + n * 0.8);
	float edge = v.y - v.x;
	float region = smoothstep(0.42, 0.62, fbm(lp * 1.1 + 5.0) + crack_amount * 0.35);
	float crack = (1.0 - smoothstep(0.0, 0.07, edge)) * region;
	float glow_halo = (1.0 - smoothstep(0.0, 0.22, edge)) * region;

	vec3 base = mix(skin_dark, skin_light, smoothstep(0.3, 0.75, n));
	base *= 0.75 + 0.45 * fine;
	// Scorched rims around cracks.
	base = mix(base, vec3(0.32, 0.12, 0.05), glow_halo * 0.35);
	ALBEDO = base * (1.0 - crack * 0.9);

	// Bump: plated skin, sunken cracks.
	float bump = n * 0.6 + fine * 0.35 - crack * 0.6;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(bump) * r1 + dFdy(bump) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.5);

	ROUGHNESS = mix(0.42, 0.85, fine);
	SPECULAR = 0.45;
	RIM = 0.35;
	RIM_TINT = 0.6;
	float pulse = 0.72 + 0.28 * sin(TIME * 2.2 + lp.y * 4.0 + n * 6.0);
	EMISSION = ember * (crack * ember_energy * pulse + glow_halo * 0.5) * heat + vec3(1.0, 0.85, 0.7) * hit_flash * 1.5;

	if (dissolve > 0.0) {
		float d = fbm(lp * 5.0 + 11.0);
		if (d < dissolve * 1.05 - 0.02) {
			discard;
		}
		float band = 1.0 - smoothstep(0.0, 0.06, d - dissolve);
		EMISSION += ember * band * 8.0;
	}
}
