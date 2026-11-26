shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;

uniform vec3 deep : source_color = vec3(0.02, 0.08, 0.10);
uniform vec3 shallow : source_color = vec3(0.10, 0.30, 0.30);
uniform vec3 foam : source_color = vec3(0.85, 0.9, 0.9);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_grad(vec2 p) {
	vec2 g = vec2(0.0);
	vec2 dirs[5] = vec2[](vec2(0.83, 0.55), vec2(-0.41, 0.91), vec2(0.97, -0.24), vec2(-0.7, -0.71), vec2(0.2, 0.98));
	float fr[5] = float[](0.37, 0.61, 1.13, 1.87, 2.71);
	for (int i = 0; i < 5; i++) {
		float ph = dot(p, dirs[i]) * fr[i] + TIME * (0.8 + float(i) * 0.37);
		g += dirs[i] * cos(ph) * (0.5 / (1.0 + float(i)));
	}
	return g;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	v.xyz /= v.w;
	float dd = clamp((VERTEX.z - v.z), 0.0, 20.0);
	float t = smoothstep(0.0, 4.0, dd);
	vec2 g = wave_grad(wp.xz) * (1.0 - smoothstep(20.0, 90.0, length(VERTEX)));
	NORMAL_MAP = normalize(vec3(g.x * 0.15 + 0.5, g.y * 0.15 + 0.5, 1.0));
	NORMAL_MAP_DEPTH = 1.0;
	float f = 1.0 - smoothstep(0.0, 0.5, dd);
	ALBEDO = mix(mix(shallow, deep, t), foam, f * 0.6);
	ALPHA = clamp(0.55 + t * 0.4 + f * 0.3, 0.0, 0.96);
	ROUGHNESS = 0.04;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
