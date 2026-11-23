// Carte détruite : elle se désagrège selon un bruit, avec un liseré doré (scripts/ui/duel_match.gd).
shader_type canvas_item;

uniform sampler2D noise;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.82, 0.32, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float n = texture(noise, UV).r;
	float t = progress * 1.25 - 0.12;
	if (n < t) {
		discard;
	}
	float e = smoothstep(t, t + 0.07, n);
	COLOR = vec4(mix(edge_color.rgb * 1.6, c.rgb, e), c.a);
}
