shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Soft additive light column: bright through the core, fading toward the
// silhouette edges and at both ends, so it never reads as a flat card.

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.3);
uniform float energy = 1.6;
uniform float alpha = 0.0;

void fragment() {
	float core = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	float ends = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	ALBEDO = color * energy;
	ALPHA = alpha * core * ends;
}
