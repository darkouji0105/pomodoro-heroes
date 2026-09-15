# res://scenes/base/settings_screen.gd
# 設定画面（2026-09-15・人間の指示「オプション画面を別で作って切り替え」）。
#
# ⚠ いまの項目は「インベントリの出し方」1つだけ（⚠ ゲームの中 ／ 別の窓 を両方試して比べる）。
#   ⚠ 音量・ミュートはまだ入れない（NEXT_STEPS §0-UI-C-6 の 3 の残り）。
# ⚠ 値の読み書きは SaveManager の get_ / set_ を通す（⚠ ゲームのセーブとは別のファイル）。
# ⚠ 拠点からしか来ないので scenes/base/（AGENTS.md「1画面だけならその画面のフォルダ」）。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var value_slot: HBoxContainer = $Margin/Layout/InventoryModeRow/ValueSlot
@onready var toggle_button: UiButton = $Margin/Layout/InventoryModeRow/ToggleButton


func _ready() -> void:
	# ⚠ 拠点が SCREEN_ID を渡してくる。⚠ 使わないが、⚠ 次の遷移に混ざらないよう取り出して捨てる。
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	toggle_button.pressed.connect(_on_toggle_pressed)
	_refresh()


func _refresh() -> void:
	# ⚠ remove_child() してから queue_free() する（AGENTS.md「再描画は await を持たせない」）。
	for child in value_slot.get_children():
		value_slot.remove_child(child)
		child.queue_free()
	var row: ValueRow = ValueRow.create(
		tr("ui_settings_inventory_mode"),
		tr(_mode_label_key(SaveManager.get_inventory_mode())),
	)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_slot.add_child(row)


func _mode_label_key(mode: String) -> String:
	if mode == SaveManager.INVENTORY_MODE_NATIVE:
		return "ui_settings_inventory_mode_native"
	return "ui_settings_inventory_mode_embedded"


func _on_toggle_pressed() -> void:
	var next: String = SaveManager.INVENTORY_MODE_NATIVE
	if SaveManager.get_inventory_mode() == SaveManager.INVENTORY_MODE_NATIVE:
		next = SaveManager.INVENTORY_MODE_EMBEDDED
	# ⚠ 書けなかったら表示も変えない（⚠ 赤は SaveManager が出す）。
	if not SaveManager.set_inventory_mode(next):
		return
	_refresh()


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
