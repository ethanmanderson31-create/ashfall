shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.07, 0.15, 0.03);
uniform vec3 tip_color : source_color = vec3(0.38, 0.50, 0.16);
uniform vec3 dry_tip : source_color = vec3(0.60, 0.56, 0.28);
uniform float wind_strength = 0.22;

varying float vh;
varying vec3 wp;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y;
	float gust = sin(TIME * 0.6 + world.x * 0.04 + world.z * 0.03) * 0.5 + 0.5;
	float w = sin(TIME * 1.8 + world.x * 0.35 + world.z * 0.2) * 0.6 + sin(TIME * 3.3 + world.x * 0.9) * 0.2;
	float bend = (w + gust) * wind_strength * h * h;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.5;
	vh = h;
	wp = world;
	NORMAL = mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7);
}

void fragment() {
	float n = fract(sin(dot(floor(wp.xz * 0.12), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 tip = mix(tip_color, dry_tip, n * 0.55);
	ALBEDO = mix(base_color, tip, smoothstep(0.0, 1.0, vh)) * COLOR.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.3, 0.38, 0.12) * vh;
	AO = mix(0.4, 1.0, vh);
	AO_LIGHT_AFFECT = 0.5;
}
