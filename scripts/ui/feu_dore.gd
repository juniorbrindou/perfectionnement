class_name FeuDore
extends Control
## Carte détruite par le feu doré (choix du 2026-11-24) : la carte est photographiée, puis la
## photo brûle de bas en haut (feu_dore.gdshader) ; des étincelles montent du front de flamme,
## des cendres retombent, une lueur chaude suit le front, et le feu se fait entendre.
##
## Usage : await FeuDore.burn(carte, rayon_des_coins).consumed

signal consumed  ## La carte a fini de brûler (les dernières étincelles retombent encore).

const SHADER := preload("res://scripts/ui/feu_dore.gdshader")
const DURATION := 1.8
const FADE_OUT := 1.6  ## Temps laissé aux dernières étincelles et cendres.

var _target: Control
var _radius := 0.0
var _t := -1.0  ## < 0 tant que la photo n'est pas prise.
var _mat: ShaderMaterial
var _picture: TextureRect
var _sparks: CPUParticles2D
var _ash: CPUParticles2D
var _light: TextureRect


## Brûle target, qui disparaît sous sa propre photo. radius : rayon de ses coins (pixels).
static func burn(target: Control, radius: float = 0.0) -> FeuDore:
	var f := FeuDore.new()
	f._target = target
	f._radius = radius
	target.get_tree().current_scene.add_child(f)
	return f


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 10
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_target):
		queue_free()
		return
	var rect := _target.get_global_rect()
	var vp := get_viewport()
	var img := vp.get_texture().get_image()
	var k := Vector2(img.get_size()) / vp.get_visible_rect().size
	var region := Rect2i(Vector2i((rect.position * k).round()), Vector2i((rect.size * k).round()))
	region = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	global_position = rect.position
	size = rect.size

	_picture = TextureRect.new()
	_picture.texture = ImageTexture.create_from_image(img.get_region(region))
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("noise", _noise())
	_mat.set_shader_parameter("size_px", size)
	_mat.set_shader_parameter("radius_px", _radius)
	_mat.set_shader_parameter("progress", 0.0)
	_picture.material = _mat
	add_child(_picture)

	_light = TextureRect.new()
	_light.texture = _soft_dot(64)
	_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.material = _additive()
	_light.modulate = Color(1.0, 0.55, 0.15, 0.0)
	_light.size = Vector2(size.x * 1.5, size.x * 0.55)
	add_child(_light)

	_sparks = _particles(90, 0.75)
	_sparks.texture = _soft_dot(24)
	_sparks.material = _additive()
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 28
	_sparks.gravity = Vector2(0, -size.y * 0.35)
	_sparks.initial_velocity_min = size.y * 0.25
	_sparks.initial_velocity_max = size.y * 0.6
	_sparks.damping_min = 10
	_sparks.damping_max = 30
	_sparks.scale_amount_min = 0.25
	_sparks.scale_amount_max = 0.6
	_sparks.color_ramp = _ramp([Color(1, 0.97, 0.75, 1), Color(1, 0.62, 0.15, 0.9), Color(0.9, 0.25, 0.05, 0)])
	add_child(_sparks)

	_ash = _particles(26, 1.6)
	_ash.direction = Vector2(0, -1)
	_ash.spread = 70
	_ash.gravity = Vector2(0, size.y * 0.09)
	_ash.initial_velocity_min = size.y * 0.03
	_ash.initial_velocity_max = size.y * 0.09
	_ash.angular_velocity_min = -180
	_ash.angular_velocity_max = 180
	_ash.scale_amount_min = 2.5
	_ash.scale_amount_max = 5.0
	_ash.color_ramp = _ramp([Color(0.2, 0.13, 0.08, 0.9), Color(0.3, 0.25, 0.22, 0.6), Color(0.35, 0.32, 0.3, 0)])
	add_child(_ash)

	# La vraie carte (et son halo) s'efface sous sa photo.
	_target.create_tween().tween_property(_target, "modulate:a", 0.0, 0.25)
	Sound.play("feu", -3.0)
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var p := clampf(_t / DURATION, 0.0, 1.0)
	_mat.set_shader_parameter("progress", p)
	# Hauteur moyenne du front (voir le shader), en fraction de la carte depuis le haut.
	var front := p * 1.3 - 0.1
	var y := clampf(1.0 - (front - 0.17) / 0.78, 0.0, 1.0) * size.y
	var burning := p < 1.0
	for e: CPUParticles2D in [_sparks, _ash]:
		e.position = Vector2(size.x / 2, y)
		e.emitting = burning
	_light.position = Vector2(size.x / 2, y) - _light.size / 2
	_light.modulate.a = (0.55 + 0.15 * sin(_t * 23.0)) * (1.0 - smoothstep(0.85, 1.0, p)) * smoothstep(0.0, 0.08, p)
	if p >= 1.0 and _picture.visible:
		_picture.visible = false
		consumed.emit()
	if _t > DURATION + FADE_OUT:
		queue_free()


func _particles(amount: int, lifetime: float) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = amount
	e.lifetime = lifetime
	e.emitting = false
	e.local_coords = false
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(size.x * 0.47, 5)
	return e


func _noise() -> NoiseTexture2D:
	var fast := FastNoiseLite.new()
	fast.frequency = 0.012
	fast.seed = randi()
	var n := NoiseTexture2D.new()
	n.noise = fast
	n.width = 256
	n.height = 256
	n.seamless = true
	return n


func _soft_dot(px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray(colors)
	return g


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
