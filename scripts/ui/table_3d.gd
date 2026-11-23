class_name Table3D
extends Node3D
## Le plateau : table d'acacia, tapis bleu de nuit bordé d'étoffe tissée,
## éclairé comme par une lampe à huile. La main du joueur qui tient le téléphone
## est en bas, celle de l'autre en haut.

signal card_tapped(card: Card3D)

const BOTTOM_Z := 2.55
const TOP_Z := -2.75
const CENTER := Vector3(0, 0.05, -0.15)
const SPACING := 1.22

var _cards := {}  ## CardInPlay → Card3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = UiTheme.NIGHT
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9d2ff")
	env.environment.ambient_light_energy = 0.3
	add_child(env)

	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(deg_to_rad(-70), deg_to_rad(20), 0)
	moon.light_color = Color("d9e0ff")
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	add_child(moon)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.4, 4.2, 0.2)
	lamp.light_color = Color("ffc978")
	lamp.light_energy = 2.4
	lamp.omni_range = 11.0
	lamp.omni_attenuation = 1.4
	add_child(lamp)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50
	cam.position = Vector3(0, 8.2, 3.4)
	add_child(cam)
	cam.look_at(Vector3(0, 0, -0.5))

	var wood := MeshInstance3D.new()
	wood.mesh = Card3D._plane(Vector2(30, 30))
	var wood_mat := Card3D._material(Color.WHITE)
	wood_mat.albedo_texture = _wood_texture()
	wood_mat.uv1_scale = Vector3(7, 7, 1)
	wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wood.material_override = wood_mat
	wood.position.y = -0.03
	add_child(wood)

	var runner := MeshInstance3D.new()
	runner.mesh = Card3D._plane(Vector2(6.6, 8.8))
	runner.material_override = Card3D._material(UiTheme.NIGHT_SOFT)
	runner.position = Vector3(0, -0.02, -0.1)
	add_child(runner)
	for side in [-1, 1]:
		var hem := MeshInstance3D.new()
		hem.mesh = Card3D._plane(Vector2(0.42, 8.8))
		var hem_mat := Card3D._material(Color.WHITE)
		hem_mat.albedo_texture = UiTheme.weave_texture("ourlet", 52, 8, true)
		hem_mat.uv1_scale = Vector3(1, 30, 1)
		hem.material_override = hem_mat
		hem.position = Vector3(side * 3.51, -0.019, -0.1)
		add_child(hem)


func add_card(card: CardInPlay, who: int) -> Card3D:
	var c := Card3D.new()
	add_child(c)
	c.setup(card, who)
	c.tapped.connect(func(x): card_tapped.emit(x))
	_cards[card] = c
	return c


func card_for(card: CardInPlay) -> Card3D:
	return _cards.get(card)


func forget(card: CardInPlay) -> void:
	_cards.erase(card)


## Range les deux mains : celle de `viewer` en bas, l'autre en haut, faces cachées.
func layout(hands: Array, viewer: int) -> void:
	for p in 2:
		var hand: Array = hands[p]
		var z := BOTTOM_Z if p == viewer else TOP_Z
		for i in hand.size():
			var c: Card3D = _cards[hand[i]]
			var x := (i - (hand.size() - 1) / 2.0) * SPACING
			c.set_face_up(false)
			c.move_to(Vector3(x, 0.0, z))


func to_center(card: Card3D) -> void:
	card.move_to(CENTER, 0.5)
	card.set_face_up(true)


## Planches d'acacia : bruit étiré dans le sens du fil, joints sombres.
static func _wood_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var dark := Color("2a1a0f")
	var light := Color("5b3b22")
	for y in h:
		for x in w:
			var plank := x / 32
			var grain := noise.get_noise_2d(x * 6.0 + plank * 97.0, y * 0.5)
			var c := dark.lerp(light, 0.5 + grain * 0.6)
			if x % 32 == 0:
				c = dark.darkened(0.3)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
