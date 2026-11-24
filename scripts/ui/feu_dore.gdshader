// Carte détruite par le feu doré (scripts/ui/feu_dore.gd) : le front de flamme monte du bas,
// irrégulier ; devant lui le parchemin roussit, se carbonise, puis une bordure de braises
// brille avant que le reste ne disparaisse.
shader_type canvas_item;

uniform sampler2D noise : repeat_enable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0 : intacte ; 1 : consumée
uniform vec2 size_px = vec2(300.0, 500.0);            // taille de la carte, pour ses coins arrondis
uniform float radius_px = 12.0;

float rounded_box(vec2 uv) {
	vec2 p = (uv - 0.5) * size_px;
	vec2 q = abs(p) - (size_px * 0.5 - vec2(radius_px));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius_px;
}

void fragment() {
	if (rounded_box(UV) > 0.0) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV);
	vec2 nuv = UV * vec2(1.0, size_px.y / size_px.x) * 0.8;
	float n = texture(noise, nuv).r * 0.7 + texture(noise, nuv * 3.1 + vec2(0.37, 0.11)).r * 0.3;
	// Hauteur à laquelle ce point brûle : le bas d'abord, avec des langues irrégulières.
	float h = (1.0 - UV.y) * 0.78 + n * 0.34;
	float front = progress * 1.3 - 0.1;
	float d = h - front;
	if (d < 0.0) {
		discard;
	}
	vec3 col = c.rgb;
	float scorch = 1.0 - smoothstep(0.03, 0.17, d);
	col = mix(col, col * vec3(0.62, 0.42, 0.24), scorch * 0.85);
	float char_zone = 1.0 - smoothstep(0.016, 0.05, d);
	col = mix(col, vec3(0.13, 0.06, 0.03), char_zone);
	float glow = 1.0 - smoothstep(0.0, 0.024, d);
	vec3 ember = mix(vec3(1.0, 0.96, 0.62), vec3(1.0, 0.48, 0.08), smoothstep(0.0, 0.024, d));
	col = mix(col, ember * 1.3, glow);
	COLOR = vec4(col, c.a);
}
