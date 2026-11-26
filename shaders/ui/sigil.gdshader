shader_type canvas_item;
// Procedural branch sigils: 0 Gunslinger (sight ring), 1 Blademaster (crossed axes), 2 Warden (shield).
uniform int kind = 0;
uniform vec4 col : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 1.0;
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * t); }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = 10.0;
	float r = length(p);
	d = min(d, abs(r - 0.92));
	if (kind == 0) {
		d = min(d, abs(r - 0.55));
		d = min(d, seg(p, vec2(0.0, 0.2), vec2(0.0, 0.8)));
		d = min(d, seg(p, vec2(0.0, -0.2), vec2(0.0, -0.8)));
		d = min(d, seg(p, vec2(0.2, 0.0), vec2(0.8, 0.0)));
		d = min(d, seg(p, vec2(-0.2, 0.0), vec2(-0.8, 0.0)));
		d = min(d, max(r - 0.08, 0.0));
	} else if (kind == 1) {
		d = min(d, seg(p, vec2(-0.6, 0.65), vec2(0.6, -0.65)));
		d = min(d, seg(p, vec2(0.6, 0.65), vec2(-0.6, -0.65)));
		vec2 q = vec2(abs(p.x), p.y);
		d = min(d, abs(length(q - vec2(0.62, 0.62)) - 0.2) + max(0.0, (q.x + q.y) - 1.25) * 3.0);
		d = min(d, abs(length(q - vec2(0.62, 0.62)) - 0.2) );
	} else {
		float sy = p.y < 0.0 ? abs(p.x) * 0.9 + (-p.y) * 0.75 : max(abs(p.x), 0.0);
		float shield = p.y > 0.55 ? abs(p.y - 0.55) + max(abs(p.x) - 0.55, 0.0) : abs(sy - 0.55);
		d = min(d, shield);
		d = min(d, seg(p, vec2(0.0, 0.45), vec2(0.0, -0.5)));
		d = min(d, seg(p, vec2(-0.35, 0.15), vec2(0.35, 0.15)));
	}
	float line = 1.0 - smoothstep(0.035, 0.06, d);
	float halo = (1.0 - smoothstep(0.0, 0.3, d)) * 0.5 * (1.0 - smoothstep(0.8, 1.0, r));
	vec3 c = col.rgb * (1.1 + min(intensity, 1.2) * 0.6);
	COLOR = vec4(c, line + halo * intensity);
}
