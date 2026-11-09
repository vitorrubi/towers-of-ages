extends Control
## Launcher do Tower Overtime (antes Towers of Ages; o repo, o zip e o exe mantêm o nome antigo): consulta a última Release do repositório público
## de builds no GitHub, baixa e instala o jogo em game/ (ao lado do launcher)
## quando a versão mudou, e abre o jogo pelo botão Jogar.

const GITHUB_OWNER := "vitorrubi"
const GITHUB_REPO := "towers-of-ages"
## Asset da release com o jogo: um .zip cujo nome começa assim.
const GAME_ASSET_PREFIX := "TowersOfAges-"
const GAME_EXE_NAME := "TowersOfAges.exe"
const GAME_SUBDIR := "game"
const VERSION_FILE_NAME := "version.txt"
const DOWNLOAD_TMP_NAME := "update_download.zip"
const USER_AGENT := "TowersOfAgesLauncher"

const GAME_TITLE := "Tower Overtime"
const NAVY := Color(0.07, 0.1, 0.2)
const GOLD := Color(1.0, 0.74, 0.14)
const GOLD_DARK := Color(0.82, 0.38, 0.06)
const RIFT := Color(0.38, 0.8, 1.0)
const TITLE_FONT_FILE := preload("res://fonts/Fredoka.ttf")
const BODY_FONT_FILE := preload("res://fonts/Nunito.ttf")
const PANORAMA := preload("res://assets/panorama.jpg")
const LOGO := preload("res://assets/tower_overtime_small.png")
const LOGO_WIDTH := 340.0

var _game_dir: String
var _version_file_path: String
var _remote_version := ""
var _is_downloading := false

var _status_label: Label
var _version_label: Label
var _progress_bar: ProgressBar
var _play_button: Button
var _api_request: HTTPRequest
var _download_request: HTTPRequest


func _ready() -> void:
	_game_dir = OS.get_executable_path().get_base_dir().path_join(GAME_SUBDIR)
	_version_file_path = _game_dir.path_join(VERSION_FILE_NAME)
	DirAccess.make_dir_recursive_absolute(_game_dir)
	_build_ui()

	_api_request = HTTPRequest.new()
	add_child(_api_request)
	_api_request.request_completed.connect(_on_api_completed)
	_download_request = HTTPRequest.new()
	add_child(_download_request)
	_download_request.request_completed.connect(_on_download_completed)

	_check_for_update()


func _process(_delta: float) -> void:
	if not _is_downloading:
		return
	var total := _download_request.get_body_size()
	var done := _download_request.get_downloaded_bytes()
	if total > 0:
		_progress_bar.value = float(done) / float(total) * 100.0
		_status_label.text = "Baixando v%s  ·  %.0f / %.0f MB" % [_remote_version, done / 1048576.0, total / 1048576.0]
	else:
		_status_label.text = "Baixando v%s  ·  %.0f MB" % [_remote_version, done / 1048576.0]


# --- Interface ---


func _build_ui() -> void:
	get_window().title = GAME_TITLE
	var title_font := _font(TITLE_FONT_FILE, 600)
	var ui_theme := Theme.new()
	ui_theme.default_font = _font(BODY_FONT_FILE, 650)
	ui_theme.default_font_size = 16
	theme = ui_theme

	# Fundo: a mesma foto do panorama da tela de carregamento do jogo, escurecida embaixo para o texto.
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var picture := TextureRect.new()
	picture.texture = PANORAMA
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(NAVY, 0.0))
	gradient.add_point(0.5, Color(NAVY, 0.1))
	gradient.set_color(gradient.get_point_count() - 1, Color(NAVY, 0.9))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(LOGO_WIDTH, LOGO_WIDTH * LOGO.get_height() / LOGO.get_width())
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(logo)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	_status_label = Label.new()
	_style_title(_status_label, title_font, 17, Color.WHITE, 6)
	column.add_child(_status_label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 26
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.add_theme_stylebox_override("background", _chunky_style(Color(NAVY, 0.92), NAVY.darkened(0.5), 3, 5))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(10)
	fill.border_color = GOLD.lightened(0.35)
	fill.border_width_top = 3
	fill.expand_margin_left = -4
	fill.expand_margin_right = -4
	fill.expand_margin_top = -4
	fill.expand_margin_bottom = -6
	_progress_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_progress_bar)

	_play_button = Button.new()
	_play_button.custom_minimum_size = Vector2(200, 66)
	_play_button.disabled = true
	_play_button.text = "    JOGAR"
	_play_button.add_theme_font_override("font", title_font)
	_play_button.add_theme_font_size_override("font_size", 28)
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_play_button.add_theme_color_override(state, NAVY)
	_play_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	_play_button.add_theme_stylebox_override("normal", _chunky_style(GOLD, GOLD_DARK))
	_play_button.add_theme_stylebox_override("hover", _chunky_style(GOLD.lightened(0.18), RIFT))
	_play_button.add_theme_stylebox_override("pressed", _chunky_style(GOLD.darkened(0.12), GOLD_DARK, 3, 2))
	_play_button.add_theme_stylebox_override("focus", _chunky_style(Color.TRANSPARENT, RIFT))
	_play_button.add_theme_stylebox_override("disabled", _chunky_style(Color(NAVY, 0.85), NAVY.darkened(0.5)))
	var play_icon := MenuIcon.make("play", 24.0, NAVY)
	_play_button.add_child(play_icon)
	play_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	play_icon.position.x = 34
	play_icon.position.y -= 2
	_play_button.pressed.connect(_on_play_pressed)
	row.add_child(_play_button)

	_version_label = Label.new()
	_style_title(_version_label, title_font, 14, Color(1, 1, 1, 0.85), 5)
	_version_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.offset_right = -14
	_version_label.offset_top = 10
	add_child(_version_label)
	_refresh_version_label()


## Botão grosso do jogo: cantos redondos, contorno escuro e a borda de baixo mais alta (o "degrau").
static func _chunky_style(face: Color, edge: Color, border: int = 3, depth: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = edge
	style.set_border_width_all(border)
	style.border_width_bottom = depth
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.3)
	# O foco é só a borda por cima do botão: a sombra dele escureceria a face inteira.
	style.shadow_size = 2 if face.a > 0.0 else 0
	style.shadow_offset = Vector2(0, 3)
	return style


func _font(file: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = file
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _style_title(label: Label, font: Font, font_size: int, color: Color, outline: int) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", NAVY)
	label.add_theme_constant_override("outline_size", outline)


func _refresh_version_label() -> void:
	var local := _read_local_version()
	_version_label.text = ("v" + local) if not local.is_empty() else ""


func _set_ready(message: String) -> void:
	_status_label.text = message
	_progress_bar.value = 100
	_play_button.disabled = false
	_play_button.grab_focus()
	_refresh_version_label()


# --- Atualização ---


func _check_for_update() -> void:
	_status_label.text = "Procurando atualizações..."
	var url := "https://api.github.com/repos/%s/%s/releases/latest" % [GITHUB_OWNER, GITHUB_REPO]
	var err := _api_request.request(url, ["User-Agent: " + USER_AGENT, "Accept: application/vnd.github+json"])
	if err != OK:
		_fallback_to_offline("Sem conexão com o servidor.")


func _on_api_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fallback_to_offline("Sem conexão com o servidor.")
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary or not (json as Dictionary).has("tag_name"):
		_fallback_to_offline("Resposta inesperada do servidor.")
		return

	_remote_version = String(json["tag_name"]).trim_prefix("v")
	var asset_url := ""
	for asset: Dictionary in json.get("assets", []):
		var asset_name := String(asset.get("name", ""))
		if asset_name.begins_with(GAME_ASSET_PREFIX) and asset_name.to_lower().ends_with(".zip"):
			asset_url = String(asset.get("browser_download_url", ""))
			break
	if asset_url.is_empty():
		_fallback_to_offline("A versão mais recente ainda não tem o jogo para baixar.")
		return

	if _read_local_version() == _remote_version and _game_installed():
		_set_ready("Tudo pronto! Versão mais recente instalada.")
		return
	_start_download(asset_url)


func _start_download(url: String) -> void:
	_is_downloading = true
	_progress_bar.value = 0
	_play_button.disabled = true
	_download_request.download_file = _game_dir.path_join(DOWNLOAD_TMP_NAME)
	var err := _download_request.request(url, ["User-Agent: " + USER_AGENT])
	if err != OK:
		_is_downloading = false
		_fallback_to_offline("Não foi possível iniciar o download.")


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_is_downloading = false
	var tmp_path := _game_dir.path_join(DOWNLOAD_TMP_NAME)
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		DirAccess.remove_absolute(tmp_path)
		_fallback_to_offline("O download falhou.")
		return
	_status_label.text = "Instalando..."
	await get_tree().process_frame
	var ok := _extract_zip(tmp_path, _game_dir)
	DirAccess.remove_absolute(tmp_path)
	if not ok:
		_fallback_to_offline("Não foi possível instalar (o jogo está aberto?).")
		return
	_write_local_version(_remote_version)
	_set_ready("Atualizado para a v%s!" % _remote_version)


func _extract_zip(zip_path: String, dest_dir: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return false
	for entry_path in reader.get_files():
		if entry_path.ends_with("/"):
			continue
		var out_path := dest_dir.path_join(entry_path)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			reader.close()
			return false
		file.store_buffer(reader.read_file(entry_path))
		file.close()
	reader.close()
	return true


func _game_installed() -> bool:
	return FileAccess.file_exists(_game_dir.path_join(GAME_EXE_NAME))


func _read_local_version() -> String:
	if not FileAccess.file_exists(_version_file_path):
		return ""
	return FileAccess.get_file_as_string(_version_file_path).strip_edges()


func _write_local_version(version: String) -> void:
	var file := FileAccess.open(_version_file_path, FileAccess.WRITE)
	file.store_string(version)
	file.close()


func _fallback_to_offline(message: String) -> void:
	_progress_bar.value = 0
	if _game_installed():
		_set_ready(message + " Jogando a versão instalada.")
	else:
		_status_label.text = message + " Tente de novo mais tarde."
		_play_button.disabled = true


func _on_play_pressed() -> void:
	var exe_path := _game_dir.path_join(GAME_EXE_NAME)
	if not FileAccess.file_exists(exe_path):
		_status_label.text = "Jogo não encontrado."
		return
	OS.create_process(exe_path, [])
	get_tree().quit()
