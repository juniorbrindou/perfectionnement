class_name SkyClouds
extends Control
## Nuages qui dérivent lentement dans le ciel ajouté au-dessus de l'image.

const PUFFS := [Vector2(0, 0), Vector2(0.9, -0.35), Vector2(1.8, -0.1), Vector2(2.5, 0.15), Vector2(1.2, 0.25)]
const RADII := [0.8, 1.0, 0.9, 0.6, 0.85]
var _t := 0.0
## Position de départ (fraction de largeur, fraction de hauteur), taille, vitesse (px/s).
var _clouds := [[0.15, 0.35, 22.0, 6.0], [0.62, 0.6, 30.0, 9.0], [0.9, 0.22, 16.0, 4.5]]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if size.y < 20:
		return
	var w := size.x
	for c in _clouds:
		var r: float = c[2] * size.x / 390.0
		var span := w + r * 6
		var x := fposmod(c[0] * w + _t * c[3], span) - r * 3
		var y: float = c[1] * size.y
		for i in PUFFS.size():
			var p: Vector2 = PUFFS[i]
			draw_circle(Vector2(x + p.x * r, y + p.y * r + r * 0.12), RADII[i] * r, Color(0.78, 0.86, 1.0, 0.45))
		for i in PUFFS.size():
			var p: Vector2 = PUFFS[i]
			draw_circle(Vector2(x + p.x * r, y + p.y * r), RADII[i] * r, Color(1, 1, 1, 0.85))
