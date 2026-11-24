class_name UpdateNotice
extends Control
## Mises à jour hors Google Play (docs/RELEASES.md) : au lancement, l'accueil demande à GitHub la
## dernière version publiée dans le dépôt des releases. Si elle est plus récente que celle-ci, une
## fenêtre montre ses nouveautés et un bouton « Télécharger » qui ouvre l'APK dans le navigateur.
## « Plus tard » la referme jusqu'au prochain lancement.

const REPO := "juniorbrindou/perfectionnement-releases"
const API := "https://api.github.com/repos/%s/releases/latest" % REPO
const ASSET := "perfectionnement.apk"

static var checked := false  ## Une seule vérification par lancement.

var _http: HTTPRequest


## Ajoute la vérification à un écran (sans effet si elle a déjà eu lieu, ou sans écran).
static func check_from(host: Control) -> void:
	if checked or DisplayServer.get_name() == "headless":
		return
	checked = true
	var n := UpdateNotice.new()
	host.add_child(n)


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_http.request(API, ["User-Agent: Perfectionnement", "Accept: application/vnd.github+json"])


func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		queue_free()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		queue_free()
		return
	var latest := str(data.get("tag_name", "")).trim_prefix("v")
	if not is_newer(latest, current_version()):
		queue_free()
		return
	var url := str(data.get("html_url", ""))
	for a in data.get("assets", []):
		if a is Dictionary and str(a.get("name", "")).ends_with(".apk"):
			url = str(a.get("browser_download_url", url))
	_show(latest, str(data.get("body", "")), url)


static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## « 0.6.10 » est plus récent que « 0.6.9 » : on compare nombre par nombre.
static func is_newer(candidate: String, current: String) -> bool:
	var a := candidate.split(".")
	var b := current.split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


# ---------------------------------------------------------------- La fenêtre

func _show(version: String, notes: String, url: String) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Glass.DEEP, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := UiTheme.margins(22, 0, 22, 0)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var center := CenterContainer.new()
	m.add_child(center)
	var panel := PanelContainer.new()
	var s := Glass.panel_style(Color(0.05, 0.1, 0.24, 0.97), 22, Glass.RING, 18, 18)
	s.set_border_width_all(UiTheme.px(2))
	s.shadow_color = Color(1.0, 0.84, 0.42, 0.3)
	s.shadow_size = UiTheme.px(10)
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size = Vector2(get_viewport_rect().size.x - UiTheme.px(44), 0)
	center.add_child(panel)
	var v := UiTheme.vbox(10)
	panel.add_child(v)
	v.add_child(Glass.title("Nouvelle version", 26))
	v.add_child(UiTheme.label("La version %s est disponible (tu as la %s)." % [version, current_version()], 15, Glass.PALE, 800))
	if not notes.strip_edges().is_empty():
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, UiTheme.px(180))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_override("normal_font", UiTheme.body_font(800))
		text.add_theme_font_override("bold_font", UiTheme.TITLE_FONT)
		text.add_theme_font_size_override("normal_font_size", UiTheme.px(14))
		text.add_theme_font_size_override("bold_font_size", UiTheme.px(15))
		text.add_theme_color_override("default_color", UiTheme.CREAM)
		text.text = markdown_to_bbcode(notes)
		scroll.add_child(text)
		v.add_child(scroll)
	v.add_child(UiTheme.spacer(4))
	var download := Glass.gold_button("Télécharger", func():
		OS.shell_open(url)
		queue_free(), 22, 58)
	v.add_child(download)
	v.add_child(Glass.button("Plus tard", queue_free, 17, 48))
	v.add_child(UiTheme.label("Après le téléchargement, ouvre le fichier pour installer la mise à jour : ta progression est gardée.", 12, Glass.SOFT, 800))


## Changelog GitHub (Markdown simple) → texte enrichi : titres, listes, gras.
static func markdown_to_bbcode(md: String) -> String:
	var out := PackedStringArray()
	for raw in md.replace("\r", "").split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			out.append("[b]%s[/b]" % line.lstrip("# "))
		elif line.begins_with("- ") or line.begins_with("* "):
			out.append("  •  " + line.substr(2))
		else:
			out.append(line)
	var text := "\n".join(out)
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	return bold.sub(text, "[b]$1[/b]", true)
