class_name Table3D
extends Node3D
## Le plateau : table, lumière, caméra et disposition des cartes.
## La main du joueur qui tient le téléphone est en bas, celle de l'autre en haut.

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
	env.environment.ambient_light_color = Color("ffe8c0")
	env.environment.ambient_light_energy = 0.55
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(25), 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50
	cam.position = Vector3(0, 7.2, 4.9)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0.35))

	var wood := MeshInstance3D.new()
	wood.mesh = Card3D._plane(Vector2(10, 16))
	wood.material_override = Card3D._material(UiTheme.WOOD)
	wood.position.y = -0.02
	add_child(wood)
	var felt := MeshInstance3D.new()
	felt.mesh = Card3D._plane(Vector2(7.0, 8.4))
	felt.material_override = Card3D._material(Color("2f4a3a"))
	felt.position = Vector3(0, -0.015, -0.1)
	add_child(felt)


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
