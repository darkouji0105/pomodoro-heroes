class_name PomodoroLinks
extends HBoxContainer

# ポモドーロの画面から「集中の道具」「ポモドーロの設定」へ（2026-09-29・回UI-仕組み⑤・人間「⚠ 4い」
#   「⚠ ポモドーロ設定はポモドーロ画面から開ける」）。
# ⚠ 置くのは2か所：⚠ 加護を選ぶビュー ／ ⚠ 集中のビューの開始前（⚠ 加護は1日1回＝2回目からは集中のビューから始まる）。
# ⚠ どちらも戻るとポモドーロ（⚠ まだ何も始まっていないときだけ出す）。

const FOCUS_TOOLS_PATH: String = "res://scenes/pomodoro/focus_tools_screen.tscn"


static func create() -> PomodoroLinks:
	var links: PomodoroLinks = PomodoroLinks.new()
	links.name = "PomodoroLinks"
	var tools: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_focus_tools_open")
	tools.name = "FocusToolsButton"
	tools.pressed.connect(links._on_tools_pressed)
	links.add_child(tools)
	var settings: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_settings_open")
	settings.name = "PomodoroSettingsButton"
	settings.pressed.connect(links._on_settings_pressed)
	links.add_child(settings)
	return links


func _on_tools_pressed() -> void:
	SceneManager.change_scene(FOCUS_TOOLS_PATH)


# ⚠ 2026-10-02（人間「⚠ ポモドーロ関連の設定はポモドーロ画面からできるように」）：⚠ 画面を移らず、⚠ 紙の窓で設定する。
#   ⚠ 変えたらポモドーロの画面に今の長さを効かせる（`apply_settings()`）。
func _on_settings_pressed() -> void:
	var panel: PomodoroSettingsPanel = PomodoroSettingsPanel.new()
	panel.custom_minimum_size.x = float(get_theme_constant(&"panel_width", &"PomodoroSettings"))
	var host: Node = get_tree().current_scene
	if host != null and host.has_method("apply_settings"):
		panel.changed.connect(Callable(host, "apply_settings"))
	Modal.notify(host, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_pomodoro_settings_open"),
		Modal.OPTION_CONTENT: panel,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
	})
