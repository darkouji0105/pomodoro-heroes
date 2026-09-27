class_name ChestBox
extends Control

# 届いた宝箱の画面の、⚠ 台の上の箱（2026-09-27・回UI-組 宝箱・手本 Chest）。
#
# ⚠ 絵（画像）を使わず線と面で描く（⚠ 砂時計 `Hourglass` と同じ流儀）。⚠ 革の面に真鍮の線・前に2本の帯。
# ⚠ 閉じた姿 ＝ 蓋が箱の上に乗る四角 ／ ⚠ 開いた姿 ＝ 蓋が上に開いた台形（⚠ 手本の絵）。
# ⚠ 値は Theme の `ChestScreen` 型（⚠ 色・大きさ・線の太さ）。
# ⚠ 宝箱の画面でしか使わないので scenes/base/（AGENTS.md）。

const THEME_TYPE: StringName = &"ChestScreen"

@export var opened: bool = false:
	set(value):
		opened = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(
		float(get_theme_constant(&"box_width", THEME_TYPE)),
		float(get_theme_constant(&"box_height", THEME_TYPE))
	)


func _draw() -> void:
	var line: Color = get_theme_color(&"box_line", THEME_TYPE)
	var fill: Color = get_theme_color(&"box_fill", THEME_TYPE)
	var width: float = float(get_theme_constant(&"box_line", THEME_TYPE))
	var lid: float = float(get_theme_constant(&"box_lid", THEME_TYPE))
	var band: float = float(get_theme_constant(&"box_band", THEME_TYPE))
	var w: float = size.x
	var h: float = size.y
	var half: float = width * 0.5
	# 箱の胴（⚠ 蓋の下から底まで）。
	var body: Rect2 = Rect2(Vector2(half, lid), Vector2(w - width, h - lid - half))
	draw_rect(body, fill)
	draw_rect(body, line, false, width)
	# 前の2本の帯。
	for x: float in [band, w - band]:
		draw_line(Vector2(x, lid), Vector2(x, h - half), line, width)
	if opened:
		# ⚠ 開いた蓋＝胴の上の縁から外へ開く台形（⚠ 手本の絵）。
		var inset: float = band * 0.8
		var lid_shape: PackedVector2Array = PackedVector2Array([
			Vector2(half, lid), Vector2(inset, half), Vector2(w - inset, half), Vector2(w - half, lid),
		])
		draw_colored_polygon(lid_shape, get_theme_color(&"box_inside", THEME_TYPE))
		lid_shape.append(Vector2(half, lid))
		draw_polyline(lid_shape, line, width)
	else:
		# ⚠ 閉じた蓋＝胴の上に乗る四角。
		var cover: Rect2 = Rect2(Vector2(half, half), Vector2(w - width, lid - half))
		draw_rect(cover, fill)
		draw_rect(cover, line, false, width)
		# 錠前。
		var lock: Vector2 = Vector2(w * 0.5, lid)
		draw_rect(Rect2(lock - Vector2(band * 0.3, band * 0.3), Vector2(band * 0.6, band * 0.6)), line)
