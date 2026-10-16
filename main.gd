extends Control
## Launcher do Towers of Ages: consulta a última Release do repositório público
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

const BG := Color(0.03, 0.04, 0.06)
const ACCENT := Color(0.38, 0.9, 1.0)
const WARM := Color(1.0, 0.78, 0.36)
const TEXT_DIM := Color(0.62, 0.68, 0.74)
const TITLE_FONT_FILE := preload("res://fonts/Fredoka.ttf")
const BODY_FONT_FILE := preload("res://fonts/Nunito.ttf")

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
	var title_font := _font(TITLE_FONT_FILE, 600)
	var ui_theme := Theme.new()
	ui_theme.default_font = _font(BODY_FONT_FILE, 650)
	ui_theme.default_font_size = 16
	theme = ui_theme

	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(ACCENT, 0.18))
	gradient.set_color(1, Color(ACCENT, 0.0))
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = glow_texture
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_top = -260
	glow.offset_left = 300
	glow.offset_right = 260
	add_child(glow)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -34)
	column.add_child(logo)
	var title := Label.new()
	title.text = "TOWERS"
	_style_title(title, title_font, 96, Color.WHITE, 12)
	logo.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "OF AGES"
	_style_title(subtitle, title_font, 48, WARM, 9)
	logo.add_child(subtitle)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", TEXT_DIM)
	_status_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_status_label)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 14
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.07)
	track.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(7)
	_progress_bar.add_theme_stylebox_override("background", track)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_progress_bar)

	_play_button = Button.new()
	_play_button.custom_minimum_size = Vector2(200, 66)
	_play_button.disabled = true
	_play_button.text = "    JOGAR"
	_play_button.add_theme_font_override("font", title_font)
	_play_button.add_theme_font_size_override("font_size", 26)
	_play_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	for state: Array in [["normal", Color(0.16, 0.52, 0.6)], ["hover", Color(0.22, 0.66, 0.75)],
			["pressed", Color(0.1, 0.38, 0.45)], ["disabled", Color(0.1, 0.13, 0.17)], ["focus", Color(0, 0, 0, 0)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = state[1]
		style.set_corner_radius_all(10)
		style.border_color = ACCENT if state[0] != "disabled" else Color(1, 1, 1, 0.08)
		style.set_border_width_all(1)
		style.draw_center = state[0] != "focus"
		_play_button.add_theme_stylebox_override(state[0], style)
	var play_icon := MenuIcon.make("play", 24.0)
	_play_button.add_child(play_icon)
	play_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	play_icon.position.x = 34
	_play_button.pressed.connect(_on_play_pressed)
	row.add_child(_play_button)

	_version_label = Label.new()
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_version_label.add_theme_font_size_override("font_size", 13)
	_version_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_version_label.offset_right = -18
	_version_label.offset_top = 12
	add_child(_version_label)
	_refresh_version_label()


func _font(file: Font, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = file
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


func _style_title(label: Label, font: Font, font_size: int, color: Color, outline: int) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
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
