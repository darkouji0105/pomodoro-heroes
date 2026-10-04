class_name TaskColorMark
extends Control

# タスクの色の印（2026-10-04・DECISIONS.md `TK-12`）。
#
# ⚠ 色の番号（`GameStateKeys.TASK_COLOR`）を丸で描く。⚠ 色そのものは Theme の `TaskColor` 型（`color_<n>`）。
#   ⚠ ここに色を書かない（AGENTS.md「Themeの扱い」）。⚠ 大きさは Theme の `Task/mark`。
# ⚠ 拠点の紙・タスクの画面・ポモドーロの選ぶ窓・記録の4画面で使う＝scenes/ui/components/（AGENTS.md）。
# ⚠ `.new()` で作る（⚠ `TaskColorMark.create(index)`）。

const THEME_TYPE: StringName = &"Task"
const COLOR_TYPE: StringName = &"TaskColor"

var color_index: int = 0:
	set(value):
		color_index = value
		queue_redraw()

# ⚠ 大きさ（⚠ 0 なら Theme の `mark`）。⚠ 詳しくの色の札は大きく出す。
var side: int = 0:
	set(value):
		side = value
		_resize()


static func create(index: int, p_side: int = 0) -> TaskColorMark:
	var mark: TaskColorMark = TaskColorMark.new()
	mark.name = "ColorMark"
	mark.color_index = index
	mark.side = p_side
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return mark


func _ready() -> void:
	_resize()


func _resize() -> void:
	if not is_inside_tree():
		return
	var px: float = float(side if side > 0 else get_theme_constant(&"mark", THEME_TYPE))
	custom_minimum_size = Vector2(px, px)
	queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	draw_circle(size * 0.5, radius, get_theme_color(StringName("color_%d" % color_index), COLOR_TYPE))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_resize()
