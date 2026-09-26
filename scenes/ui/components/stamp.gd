class_name Stamp
extends Control

# 判（2026-09-26・回UI-2・手本の「判」）。
#
# ⚠ **その紙の事柄の状態**を押す（⚠ 済・受理・昇級・可・使用中・枠1・成功・失敗）。⚠ 通知ではない。
# ⚠ 赤い四角か丸の枠に明朝の字、⚠ 少し傾けて押す。⚠ 傾きは自分の描画だけに掛ける
#   （⚠ 器の中でも効く。⚠ `Container` が戻すのは子の回転で、⚠ 描画の変換ではない）。
# ⚠ 値は Theme の `Stamp` 型（⚠ 色・字・枠・傾き）。⚠ 文字は翻訳キー。
# ⚠ `.new()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"Stamp"

enum Shape { RECT, CIRCLE }

@export var label_key: String = "":
	set(value):
		label_key = value
		_resize()

@export var shape: Shape = Shape.RECT:
	set(value):
		shape = value
		_resize()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_resize()


func _text() -> String:
	return tr(label_key) if label_key != "" else ""


func _resize() -> void:
	if not is_inside_tree():
		return
	var font: Font = get_theme_font(&"font", THEME_TYPE)
	var font_size: int = get_theme_font_size(&"font_size", THEME_TYPE)
	var text_size: Vector2 = font.get_string_size(_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad_h: float = float(get_theme_constant(&"pad_h", THEME_TYPE))
	var pad_v: float = float(get_theme_constant(&"pad_v", THEME_TYPE))
	var box: Vector2 = text_size + Vector2(pad_h, pad_v) * 2.0
	if shape == Shape.CIRCLE:
		var side: float = maxf(box.x, box.y)
		box = Vector2(side, side)
	custom_minimum_size = box
	queue_redraw()


func _draw() -> void:
	var ink: Color = get_theme_color(&"ink", THEME_TYPE)
	var border: float = float(get_theme_constant(&"border", THEME_TYPE))
	var font: Font = get_theme_font(&"font", THEME_TYPE)
	var font_size: int = get_theme_font_size(&"font_size", THEME_TYPE)
	var center: Vector2 = size * 0.5
	draw_set_transform(center, deg_to_rad(float(get_theme_constant(&"tilt_deg", THEME_TYPE))), Vector2.ONE)
	var half: Vector2 = custom_minimum_size * 0.5
	if shape == Shape.CIRCLE:
		draw_arc(Vector2.ZERO, half.x - border, 0.0, TAU, 48, ink, border)
	else:
		draw_rect(Rect2(-half + Vector2.ONE * border * 0.5, half * 2.0 - Vector2.ONE * border), ink, false, border)
	var text: String = _text()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2(-text_size.x * 0.5, font.get_ascent(font_size) - text_size.y * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_resize()
