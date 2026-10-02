# res://scenes/adventure/depth_gauge.gd
# 坑道の縦図（⚠ 2026-10-03・決定49・手本 DungeonGate ／ モック `barracks/Q8 A案`）。
#
# ⚠ 出撃の準備（難ダンジョン）の「潜る深さ」の紙に置く。⚠ 1画面だけで使う＝`scenes/adventure/`（AGENTS.md）。
# ⚠ 上が入口・下へ 10層ごとの出口の目盛り。⚠ 倒した出口に ✓・いちばん深い出口に「最深」・選んだ所につまみ。
# ⚠ 目盛りは `marks` 本ぶんの窓だけ描く（⚠ 500層を全部は描かない）。⚠ 窓は選んだ所が見えるように動く。
# ⚠ 開いている目盛りを押すとそこを選ぶ（`floor_picked`）。⚠ 判定は持たない＝画面が GameManager の口で確かめる。
# ⚠ 値（大きさ・色）は Theme の `DepthGauge` 型（`theme_builder.gd` の `DEPTH_GAUGE*`）。⚠ ここに数字を書かない。
class_name DepthGauge
extends Control

## 開いている目盛りを押した（⚠ `start_floor`＝入るフロアの番号・1 が入口）。
signal floor_picked(start_floor: int)

const THEME_TYPE: StringName = &"DepthGauge"

# ⚠ 入るフロア（1＝入口）。⚠ つまみはその1つ上の出口（⚠ 4 → 30層の出口）に置く。
var start_floor: int = 1:
	set(value):
		start_floor = value
		queue_redraw()
# ⚠ ボスを倒したいちばん深いフロア（⚠ 0＝まだ無い）＝✓ と「最深」。
var best_floor: int = 0:
	set(value):
		best_floor = value
		queue_redraw()
# ⚠ 入れるいちばん深いフロア（⚠ これより下の目盛りは薄く・押せない）。
var deepest_start: int = 1:
	set(value):
		deepest_start = value
		queue_redraw()
var max_floors: int = 1
var layers_per_floor: int = 10


func _ready() -> void:
	custom_minimum_size = Vector2(get_theme_constant(&"width", THEME_TYPE), get_theme_constant(&"height", THEME_TYPE))
	mouse_filter = Control.MOUSE_FILTER_STOP


# 窓のいちばん上の目盛り（⚠ 0＝入口）。⚠ 選んだ出口が窓の真ん中に来る（⚠ 浅いうちは入口から）。
func _window_start() -> int:
	var marks: int = maxi(2, get_theme_constant(&"marks", THEME_TYPE))
	var selected: int = start_floor - 1
	return clampi(selected - marks / 2, 0, maxi(0, max_floors - (marks - 1)))


func _mark_y(index_in_window: int) -> float:
	var marks: int = maxi(2, get_theme_constant(&"marks", THEME_TYPE))
	var top: float = float(get_theme_constant(&"pad_top", THEME_TYPE))
	var bottom: float = size.y - float(get_theme_constant(&"pad_bottom", THEME_TYPE))
	return top + (bottom - top) * float(index_in_window) / float(marks - 1)


func _draw() -> void:
	var marks: int = maxi(2, get_theme_constant(&"marks", THEME_TYPE))
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_constant(&"font_size", THEME_TYPE)
	var tube_w: float = float(get_theme_constant(&"tube_width", THEME_TYPE))
	var tube_x: float = float(get_theme_constant(&"tube_x", THEME_TYPE))
	var ink: Color = get_theme_color(&"ink", THEME_TYPE)
	var faint: Color = get_theme_color(&"ink_faint", THEME_TYPE)
	var cleared: Color = get_theme_color(&"cleared", THEME_TYPE)
	var top: float = _mark_y(0)
	var bottom: float = _mark_y(marks - 1)
	var start: int = _window_start()
	var selected_index: int = (start_floor - 1) - start

	# 坑道（⚠ つまみより上は掘った色）。
	draw_rect(Rect2(tube_x, top, tube_w, bottom - top), get_theme_color(&"tube", THEME_TYPE))
	if selected_index > 0:
		draw_rect(Rect2(tube_x, top, tube_w, _mark_y(selected_index) - top), get_theme_color(&"tube_fill", THEME_TYPE))
	draw_rect(Rect2(tube_x, top, tube_w, bottom - top), ink, false, 1.2)

	var tick_out: float = float(get_theme_constant(&"tick_out", THEME_TYPE))
	for i: int in range(marks):
		var exit_number: int = start + i
		if exit_number > max_floors:
			break
		var y: float = _mark_y(i)
		var open: bool = exit_number <= deepest_start - 1
		var color: Color = ink if open else faint
		draw_line(Vector2(tube_x - tick_out, y), Vector2(tube_x + tube_w + tick_out, y), color, 1.6 if open else 1.0)
		var text: String = TranslationServer.translate("ui_depth_gauge_entrance") if exit_number == 0 else str(exit_number * layers_per_floor)
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(tube_x - tick_out - 4.0 - text_w, y + float(font_size) * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		var right_x: float = tube_x + tube_w + tick_out + 4.0
		if exit_number >= 1 and exit_number <= best_floor:
			# ✓（⚠ 倒した出口）。
			draw_polyline(PackedVector2Array([
				Vector2(right_x, y - 1.0), Vector2(right_x + 3.0, y + 3.0), Vector2(right_x + 9.0, y - 5.0),
			]), cleared, 1.8)
			if exit_number == best_floor:
				draw_string(font, Vector2(right_x + 12.0, y + float(font_size) * 0.35), TranslationServer.translate("ui_depth_gauge_best"),
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, cleared)

	# つまみ（⚠ 選んだ出口・入口なら一番上）。
	if selected_index >= 0 and selected_index < marks:
		var center: Vector2 = Vector2(tube_x + tube_w * 0.5, _mark_y(selected_index))
		var radius: float = float(get_theme_constant(&"knob_radius", THEME_TYPE))
		draw_circle(center, radius, get_theme_color(&"knob", THEME_TYPE))
		draw_arc(center, radius, 0.0, TAU, 24, get_theme_color(&"knob_edge", THEME_TYPE), 1.6)
		draw_polyline(PackedVector2Array([
			center + Vector2(-4.0, -2.0), center + Vector2(0.0, 2.0), center + Vector2(4.0, -2.0),
		]), get_theme_color(&"knob_edge", THEME_TYPE), 1.6)

	# 下の「500層まで」。
	var limit: String = TranslationServer.translate("ui_depth_gauge_limit") % (max_floors * layers_per_floor)
	var limit_w: float = font.get_string_size(limit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(tube_x + tube_w * 0.5 - limit_w * 0.5, size.y - 2.0), limit,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, faint)


# 開いている目盛りを押すとそこを選ぶ（⚠ いちばん近い目盛り）。
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var marks: int = maxi(2, get_theme_constant(&"marks", THEME_TYPE))
	var best_i: int = 0
	for i: int in range(marks):
		if absf(_mark_y(i) - click.position.y) < absf(_mark_y(best_i) - click.position.y):
			best_i = i
	var picked: int = _window_start() + best_i + 1
	if picked >= 1 and picked <= deepest_start:
		floor_picked.emit(picked)
		accept_event()
