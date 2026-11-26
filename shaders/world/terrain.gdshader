shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/common/noise.gdshaderinc"

uniform vec3 grass_dark : source_color = vec3(0.11, 0.20, 0.05);
uniform vec3 grass_light : source_color = vec3(0.36, 0.46, 0.14);
uniform vec3 dry_grass : source_color = vec3(0.55, 0.50, 0.26);
uniform vec3 dirt : source_color = vec3(0.30, 0.22, 0.14);
uniform vec3 rock_dark : source_color = vec3(0.24, 0.22, 0.21);
uniform vec3 rock_light : source_color = vec3(0.52, 0.49, 0.45);
uniform vec3 sand : source_color = vec3(0.62, 0.56, 0.42);
uniform vec3 snow : source_color = vec3(0.92, 0.94, 0.98);
uniform float water_level = -2.5;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float height_field(vec2 p) {
	return fbm(vec3(p.x, 0.0, p.y) * 1.3);
}

void fragment() {
	float slope = 1.0 - wnorm.y;
	float big = fbm(wpos * 0.025);
	float mid = fbm(wpos * 0.18);
	float fine = fbm(wpos * 1.6);

	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, big));
	grass = mix(grass, dry_grass, smoothstep(0.55, 0.75, mid) * 0.5);
	grass *= 0.8 + 0.4 * fine;

	float strata = fbm(vec3(wpos.x * 0.1, wpos.y * 1.2, wpos.z * 0.1));
	vec3 rock = mix(rock_dark, rock_light, strata) * (0.75 + 0.5 * fine);

	vec3 col = grass;
	float dirt_w = smoothstep(0.58, 0.7, fbm(wpos * 0.04 + 7.0)) * 0.8;
	col = mix(col, dirt * (0.8 + 0.4 * fine), dirt_w);
	float rock_w = smoothstep(0.22, 0.42, slope + (mid - 0.5) * 0.25);
	col = mix(col, rock, rock_w);
	float sand_w = 1.0 - smoothstep(water_level + 0.3, water_level + 1.4 + mid, wpos.y);
	col = mix(col, sand * (0.85 + 0.3 * fine), sand_w);
	float snow_w = smoothstep(48.0, 58.0, wpos.y + mid * 10.0) * (1.0 - smoothstep(0.45, 0.7, slope));
	col = mix(col, snow, snow_w);

	// Cheap detail bump from fine noise (screen-space derivatives).
	float bump = fine * (0.6 + rock_w * 1.2);
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dbx = dFdx(bump);
	float dby = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dbx * r1 + dby * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.35);

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.75, rock_w) - snow_w * 0.3;
	SPECULAR = 0.35;
}
