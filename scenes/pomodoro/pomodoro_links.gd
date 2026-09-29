class_name PomodoroLinks
extends HBoxContainer

# ポモドーロの画面から「集中の道具」「ポモドーロの設定」へ（2026-09-29・回UI-仕組み⑤・人間「⚠ 4い」
#   「⚠ ポモドーロ設定はポモドーロ画面から開ける」）。
# ⚠ 置くのは2か所：⚠ 加護を選ぶビュー ／ ⚠ 集中のビューの開始前（⚠ 加護は1日1回＝2回目からは集中のビューから始まる）。
# ⚠ どちらも戻るとポモドーロ（⚠ まだ何も始まっていないときだけ出す）。

const FOCUS_TOOLS_PATH: String = "res://scenes/pomodoro/focus_tools_screen.tscn"
const SETTINGS_PATH: String = "res://scenes/base/settings_screen.tscn"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"


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


func _on_settings_pressed() -> void:
	SceneManager.change_scene_with_data(SETTINGS_PATH, {
		TransferKeys.SETTINGS_TAB: SettingsScreen.TAB_POMODORO,
		TransferKeys.RETURN_PATH: POMODORO_PATH,
	})
