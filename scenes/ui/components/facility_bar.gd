class_name FacilityBar
extends PanelContainer

# 施設の帯（2026-09-26・回UI-2・手本の「施設の帯」・決定 `NAV-6`）。
#
# ⚠ 拠点の入口。⚠ 画面の下に横いっぱいで固定。⚠ いまいる施設は上に灯りの線。
# ⚠ 用事がある施設には右上に**しおり紐**（⚠ 手本の印の決まり：通知はしおり紐で確定）。
# ⚠ 並びと名前は使う側が渡す（⚠ ここで画面IDを持たない＝`NAV-6` の並びが変わっても触らない）。
# ⚠ 押されたことは `facility_pressed(id)` で伝える。⚠ 遷移は画面がやる（`SceneManager`）。
# ⚠ 値は Theme の `FacilityBarPanel` / `FacilityButton(Active)` / `FacilityBar` 型。
# ⚠ `.new()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

signal facility_pressed(id: String)

const THEME_TYPE: StringName = &"FacilityBar"
const ENTRY_ID: String = "id"
const ENTRY_LABEL_KEY: String = "label_key"

var _row: HBoxContainer = null
var _buttons: Dictionary = {}   # id -> Button
var _active_id: String = ""
var _attention: Dictionary = {}  # id -> true
# ⚠ 10-07（回HB-1）：⚠ 高さを引く Theme 型。⚠ 育成の中のタブ（帯の上の1段）は `FacilitySubBar` を渡す。
var height_type: StringName = THEME_TYPE


func _init() -> void:
	theme_type_variation = &"FacilityBarPanel"
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.theme_type_variation = &"FacilityRow"   # ⚠ 間0（⚠ 入口どうしは接する）
	add_child(_row)


func _ready() -> void:
	custom_minimum_size.y = float(get_theme_constant(&"height", height_type))


# ⚠ 入口を作り直す。⚠ 前のボタンは `remove_child()` してから捨てる（⚠ await を持たない）。
func set_facilities(entries: Array[Dictionary], active_id: String = "") -> void:
	for button: Button in _buttons.values():
		_row.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for entry: Dictionary in entries:
		var id: String = str(entry.get(ENTRY_ID, ""))
		var button: Button = Button.new()
		button.name = "Facility_" + id
		button.text = tr(str(entry.get(ENTRY_LABEL_KEY, "")))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_pressed.bind(id))
		button.draw.connect(_draw_ribbon.bind(button, id))
		_row.add_child(button)
		_buttons[id] = button
	set_active(active_id)


func set_active(id: String) -> void:
	_active_id = id
	for key: String in _buttons:
		(_buttons[key] as Button).theme_type_variation = &"FacilityButtonActive" if key == id else &"FacilityButton"


# ⚠ しおり紐を出す／消す（⚠ 「見たら消える」は使う側が決めて呼ぶ）。
func set_attention(id: String, on: bool) -> void:
	if on:
		_attention[id] = true
	else:
		_attention.erase(id)
	if _buttons.has(id):
		(_buttons[id] as Button).queue_redraw()


func _on_pressed(id: String) -> void:
	facility_pressed.emit(id)


# ⚠ 上の縁から垂れる赤い紐。⚠ 下の端は切り込み（⚠ 手本の形）。
func _draw_ribbon(button: Button, id: String) -> void:
	if not _attention.has(id):
		return
	# ⚠ 10-07：⚠ 形と色は `RibbonMark` の1本（⚠ 行・マスと同じ紐）。
	RibbonMark.draw_on(button)


# ⚠ 検査用：⚠ いま紐を出している施設。
func has_attention(id: String) -> bool:
	return _attention.has(id)


# ⚠ 検査用：⚠ いま灯りの線が乗っている施設。
func active_id() -> String:
	return _active_id
