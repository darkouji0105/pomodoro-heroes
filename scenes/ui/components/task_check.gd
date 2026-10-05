class_name TaskCheck
extends Button

# 紙に描いた四角（2026-10-05・タスクのモック「四角を押すと終わり」）。
#
# ⚠ 終えたか（`TK-4`）。⚠ 押すと切り替わる（`toggle_mode`）＝⚠ 受ける側は `toggled` を繋ぐ。
# ⚠ 面は持たない（Theme `TaskCheck`＝面なし）。⚠ 墨の四角と、終えたら墨の✓を自分で描く。⚠ 色と寸法は Theme の `Task` 型。
# ⚠ タスクの画面とポモドーロの集中中のリストで使う＝scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"Task"


static func create(done: bool) -> TaskCheck:
	var check: TaskCheck = TaskCheck.new()
	check.name = "DoneCheck"
	check.set_pressed_no_signal(done)
	return check


func _init() -> void:
	toggle_mode = true
	theme_type_variation = &"TaskCheck"
	focus_mode = Control.FOCUS_NONE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggled.connect(_on_toggled)


func _ready() -> void:
	var side: float = float(get_theme_constant(&"check", THEME_TYPE))
	custom_minimum_size = Vector2(side, side) + Vector2(6.0, 6.0)


func _on_toggled(_on: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var ink: Color = get_theme_color(&"check_ink", THEME_TYPE)
	var line: float = float(get_theme_constant(&"check_line", THEME_TYPE))
	var side: float = float(get_theme_constant(&"check", THEME_TYPE))
	var origin: Vector2 = (size - Vector2(side, side)) * 0.5
	draw_rect(Rect2(origin, Vector2(side, side)), ink, false, 1.5)
	if not button_pressed:
		return
	# ⚠ ✓ は線2本（⚠ フォントに頼らない）。
	var a: Vector2 = origin + Vector2(side * 0.2, side * 0.5)
	var b: Vector2 = origin + Vector2(side * 0.42, side * 0.75)
	var c: Vector2 = origin + Vector2(side * 0.85, side * 0.2)
	draw_polyline(PackedVector2Array([a, b, c]), ink, line + 0.5, true)
