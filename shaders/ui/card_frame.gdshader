shader_type canvas_item;
// Dark slate tarot card with a double gold filigree border and corner studs.
uniform vec4 accent : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float hover = 0.0;
uniform vec2 size = vec2(300.0, 470.0);
uniform bool back = false;
uniform float dim = 0.0;
uniform float burn = 0.0;
uniform float flare = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float box(vec2 p, vec2 b, float r) { vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
void fragment() {
	vec2 p = (UV - 0.5) * size;
	float outer = box(p, size * 0.5, 14.0);
	if (outer > 0.0) { discard; }
	vec3 slate = mix(vec3(0.05, 0.045, 0.05), vec3(0.11, 0.09, 0.09), n(UV * 9.0) * 0.6 + n(UV * 40.0) * 0.4);
	slate += accent.rgb * 0.12 * (1.0 - smoothstep(0.0, 0.55, length(UV - vec2(0.5, 0.36))));
	vec3 gold = mix(vec3(0.55, 0.38, 0.16), vec3(1.0, 0.85, 0.5), 0.5 + 0.5 * sin(p.x * 0.05 + p.y * 0.03));
	float b1 = 1.0 - smoothstep(1.0, 2.2, abs(box(p, size * 0.5 - 9.0, 10.0)));
	float b2 = 1.0 - smoothstep(0.6, 1.6, abs(box(p, size * 0.5 - 17.0, 6.0)));
	vec2 c = abs(p) - (size * 0.5 - 17.0);
	float stud = 1.0 - smoothstep(4.0, 5.5, length(c));
	float frame = max(max(b1, b2 * 0.8), stud);
	if (back) {
		// Card back: ember sun with rays inside a diamond lattice.
		vec2 q = p / (size.y * 0.5);
		float rr = length(q);
		float ang = atan(q.y, q.x);
		float rays = smoothstep(0.75, 1.0, cos(ang * 12.0)) * smoothstep(0.62, 0.3, rr) * step(0.2, rr);
		float sun = 1.0 - smoothstep(0.16, 0.18, rr);
		float ring = 1.0 - smoothstep(0.004, 0.012, abs(rr - 0.24));
		float ring2 = 1.0 - smoothstep(0.004, 0.012, abs(rr - 0.66));
		vec2 g = fract((p * 0.045) * mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071))) - 0.5;
		float lattice = (1.0 - smoothstep(0.02, 0.05, min(abs(g.x), abs(g.y)))) * step(0.68, rr);
		slate = mix(vec3(0.16, 0.04, 0.03), vec3(0.25, 0.07, 0.04), n(UV * 6.0));
		slate = mix(slate, gold * 0.9, clamp(rays + sun + ring + ring2 + lattice * 0.6, 0.0, 1.0));
		slate += vec3(1.0, 0.45, 0.1) * sun * 0.6;
	}
	vec3 col = mix(slate, gold, frame);
	col *= 1.0 - dim * 0.65;
	// Claimed: a golden flare washing over the card.
	col += vec3(1.0, 0.75, 0.35) * flare * (0.6 + 0.4 * n(UV * 12.0 + TIME));
	// Rejected: the card burns away from the edges with a glowing rim.
	if (burn > 0.0) {
		float b = n(UV * 7.0) * 0.6 + n(UV * 19.0) * 0.4;
		float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)) * 2.2;
		float t = b * 0.55 + edge * 0.45;
		if (t < burn * 1.1 - 0.05) { discard; }
		float rim = 1.0 - smoothstep(0.0, 0.07, t - (burn * 1.1 - 0.05));
		col = mix(col * (1.0 - burn * 0.6), vec3(1.0, 0.45, 0.1) * 2.5, rim * step(0.001, burn));
	}
	col += accent.rgb * hover * 0.5 * (1.0 - smoothstep(0.0, 6.0, abs(outer + 3.0)));
	COLOR = vec4(col, 1.0);
}
