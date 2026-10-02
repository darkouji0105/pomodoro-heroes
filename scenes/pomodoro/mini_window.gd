class_name MiniWindow
extends CanvasLayer

# デスクトップの小窓（2026-09-29・回UI-仕組み⑥・手本 Companion）。
#
# ⚠ 人間「⚠ 1あ　⚠ 2あ　⚠ 3い　⚠ 4あ」：⚠ **ゲームの窓そのもの**を小さくしてデスクトップの隅へ（⚠ 終われば元の大きさ・位置）／
#   ⚠ 中身は広間ができるまでの仮＝暗い部屋・暖炉・出撃1番の人・残り時間（⚠ 集中中は「z z」で眠る）／ ⚠ 話しかけない ／ ⚠ 設定の既定はオフ。
# ⚠ 小窓になるのは**タイマーが動いている集中と休憩のあいだだけ**（⚠ 振り返り＝文字を打つ・次のセットの「開始」は元の大きさ）。
# ⚠ 窓を小さくするとき、⚠ 画面の論理の大きさ（`content_scale_size`）も小窓の大きさにする（⚠ 1280×720 のまま縮めると字が潰れる）。
# ⚠ 窓の操作はヘッドレスでは何もしない（⚠ 中身の出し入れだけは動く＝検査が見る）。⚠ 値は Theme の `MiniWindow` 型。

const THEME_TYPE: StringName = &"MiniWindow"
const LAYER: int = 90

signal expand_requested

var _active: bool = false
var _saved_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _saved_position: Vector2i = Vector2i.ZERO
var _saved_size: Vector2i = Vector2i.ZERO
var _saved_borderless: bool = false
var _saved_on_top: bool = false
var _saved_scale_size: Vector2i = Vector2i.ZERO
var _root: Control = null
var _time_label: Label = null
var _sleep_label: Label = null
var _avatar: Control = null


static func create() -> MiniWindow:
	var mini: MiniWindow = MiniWindow.new()
	mini.name = "MiniWindow"
	mini.layer = LAYER
	mini.visible = false
	return mini


func is_active() -> bool:
	return _active


# 小窓にする（⚠ 2回呼んでも1回ぶん）。
func enter() -> void:
	if _active:
		return
	_active = true
	_build()
	visible = true
	var mini_size: Vector2i = Vector2i(_c(&"width"), _c(&"height"))
	var root_window: Window = get_tree().root
	_saved_scale_size = root_window.content_scale_size
	root_window.content_scale_size = mini_size
	if DisplayServer.get_name() == "headless":
		return
	_saved_mode = DisplayServer.window_get_mode()
	_saved_position = DisplayServer.window_get_position()
	_saved_size = DisplayServer.window_get_size()
	_saved_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_saved_on_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, GameSettings.mini_window_on_top())
	DisplayServer.window_set_size(mini_size)
	# ⚠ いまの画面の使える範囲（⚠ タスクバーを除く）の右下。
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var margin: int = _c(&"margin")
	DisplayServer.window_set_position(usable.position + usable.size - mini_size - Vector2i(margin, margin))


# 元の大きさ・位置に戻す。
func leave() -> void:
	if not _active:
		return
	_active = false
	visible = false
	get_tree().root.content_scale_size = _saved_scale_size
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _saved_on_top)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _saved_borderless)
	DisplayServer.window_set_size(_saved_size)
	DisplayServer.window_set_position(_saved_position)
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(_saved_mode)


# 残り時間と、⚠ 眠っているか（集中中）を出す。
func set_state(seconds: int, focusing: bool) -> void:
	if _time_label == null:
		return
	var time_text: String = "%02d:%02d" % [seconds / 60, seconds % 60]
	_time_label.text = time_text if focusing else tr("ui_mini_break") % time_text
	_sleep_label.visible = focusing
	_avatar.modulate = get_theme_color_safe(&"sleep_tint") if focusing else Color.WHITE


func _exit_tree() -> void:
	# ⚠ 小窓のまま画面を離れたら（⚠ やめる・拠点へ）必ず戻す。
	leave()


func _c(key: StringName) -> int:
	return ThemeDB.get_project_theme().get_constant(key, THEME_TYPE)


func get_theme_color_safe(key: StringName) -> Color:
	return ThemeDB.get_project_theme().get_color(key, THEME_TYPE)


# 中身（⚠ 仮の部屋）：⚠ 床・暖炉・人・残り時間・「大きくする」。
func _build() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "MiniRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var room: ColorRect = ColorRect.new()
	room.name = "Room"
	room.color = get_theme_color_safe(&"wall")
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(room)
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.color = get_theme_color_safe(&"floor")
	floor_rect.anchor_left = 0.0
	floor_rect.anchor_right = 1.0
	floor_rect.anchor_top = 0.68
	floor_rect.anchor_bottom = 1.0
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(floor_rect)
	# ⚠ 暖炉（⚠ 右奥）。
	var hearth: ColorRect = ColorRect.new()
	hearth.color = get_theme_color_safe(&"hearth")
	hearth.anchor_left = 0.62
	hearth.anchor_right = 0.85
	hearth.anchor_top = 0.2
	hearth.anchor_bottom = 0.68
	hearth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hearth)
	var fire: ColorRect = ColorRect.new()
	fire.color = get_theme_color_safe(&"fire")
	fire.anchor_left = 0.68
	fire.anchor_right = 0.79
	fire.anchor_top = 0.45
	fire.anchor_bottom = 0.68
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fire)
	# ⚠ 出撃1番の人（⚠ 左手前）。
	var members: Array = GameManager.get_party_members()
	var leader: String = str(members[0]) if not members.is_empty() else ""
	_avatar = CharacterAvatar.create(leader, _c(&"photo"))
	_avatar.name = "Leader"
	_avatar.position = Vector2(float(_c(&"width")) * 0.2, float(_c(&"height")) * 0.68 - float(_c(&"photo")))
	_root.add_child(_avatar)
	_sleep_label = Label.new()
	_sleep_label.name = "SleepLabel"
	_sleep_label.text = tr("ui_mini_sleep")
	_sleep_label.position = _avatar.position + Vector2(float(_c(&"photo")), -16.0)
	_sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sleep_label)
	# ⚠ 左上に残り時間（⚠ 手本の札）。
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.theme_type_variation = &"MiniTimeLabel"
	_time_label.position = Vector2(8.0, 6.0)
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_time_label)
	# ⚠ 右上に「大きくする」（⚠ このフェーズのあいだ元の大きさに戻す）。
	var expand: Button = Button.new()
	expand.name = "ExpandButton"
	expand.text = tr("ui_mini_expand")
	expand.anchor_left = 1.0
	expand.anchor_right = 1.0
	expand.offset_left = -float(_c(&"button_width")) - 6.0
	expand.offset_right = -6.0
	expand.offset_top = 6.0
	expand.pressed.connect(_on_expand_pressed)
	_root.add_child(expand)


func _on_expand_pressed() -> void:
	expand_requested.emit()
