// Reflet de l'animation de démarrage (scripts/ui/splash.gd) : une bande de lumière inclinée à 105°
// glisse sur l'enseigne, visible seulement là où l'enseigne est opaque (masque = sa transparence).
// center : position du milieu de la bande, en largeurs de l'enseigne (-1,5 → 2,5, comme le
// dégradé de 300 % de docs/maquettes/splash.html).
shader_type canvas_item;
render_mode blend_add;

uniform float center = -1.5;

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	// 105° : la bande penche ; l'enseigne est environ deux fois plus large que haute.
	float x = UV.x + (0.5 - UV.y) * 0.14;
	float d = abs(x - center) / 0.3;
	float band = clamp(1.0 - d, 0.0, 1.0);
	COLOR = vec4(vec3(1.0, 0.98, 0.86) * band * 0.85 * mask, 1.0);
}
