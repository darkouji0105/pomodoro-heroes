class_name SheetHeading
extends VBoxContainer

# 紙の見出し（2026-09-26・回UI-2・手本の「見出し（明朝＋太い下線）」と「菱形の飾り罫」）。
#
# ⚠ 2つの形：
#   ⚠ ふつう … 左に題 ／ 右に数や操作の字 ／ ⚠ 下に**太い墨の下線**（幅いっぱい）
#   ⚠ 飾り罫 … 題の右に「線 ◆◇◆ 線」を伸ばす（⚠ 下線は引かない。⚠ 手本の「概要」「持ち物」）
# ⚠ 字の色は紙のテーマが決める（⚠ 紙の上に置く前提）。⚠ 線の色と寸法は Theme の `SheetHeading` 型。
# ⚠ 文字は翻訳キーで受け取る（⚠ ここで日本語を書かない）。
# ⚠ `.new()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"SheetHeading"

@export var title_key: String = "":
	set(value):
		title_key = value
		_refresh()

# 右の字（⚠ 「9 個」「覚えている 2 / 6」など）。⚠ 翻訳済みの文字を受け取る（⚠ 数を混ぜるため）。
@export var right_text: String = "":
	set(value):
		right_text = value
		_refresh()

@export var ornament: bool = false:
	set(value):
		ornament = value
		_refresh()

var _title: Label = null
var _right: Label = null
var _middle: Control = null
var _rule_space: Control = null


func _init() -> void:
	# ⚠ 題と下線の間は Theme の `SheetHeading`（⚠ separation 0）。⚠ override を書かない（`UI-1`）。
	theme_type_variation = THEME_TYPE
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	add_child(row)
	_title = Label.new()
	_title.name = "Title"
	_title.theme_type_variation = &"SheetHeadingLabel"
	row.add_child(_title)
	_middle = Control.new()
	_middle.name = "Ornament"
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_middle.draw.connect(_draw_ornament)
	row.add_child(_middle)
	_right = Label.new()
	_right.name = "Right"
	_right.theme_type_variation = &"CaptionLabel"
	_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_right)
	_rule_space = Control.new()
	_rule_space.name = "RuleSpace"
	_rule_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule_space)


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if _title == null:
		return
	_title.text = tr(title_key) if title_key != "" else ""
	_right.text = right_text
	_right.visible = right_text != ""
	var rule_height: float = 0.0
	if not ornament and is_inside_tree():
		rule_height = float(get_theme_constant(&"gap", THEME_TYPE) + get_theme_constant(&"rule_width", THEME_TYPE))
	_rule_space.custom_minimum_size = Vector2(0.0, rule_height)
	_middle.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if ornament:
		return
	var width: float = float(get_theme_constant(&"rule_width", THEME_TYPE))
	var y: float = size.y - width * 0.5
	draw_line(Vector2(0.0, y), Vector2(size.x, y), get_theme_color(&"rule", THEME_TYPE), width)


# ⚠ 「線 ◆◇◆ 線」。⚠ 真ん中の◇だけ中を抜く（⚠ 手本の飾り罫）。
func _draw_ornament() -> void:
	if not ornament:
		return
	var color: Color = get_theme_color(&"ornament", THEME_TYPE)
	var r: float = float(get_theme_constant(&"diamond", THEME_TYPE))
	var w: float = _middle.size.x
	var y: float = _middle.size.y * 0.5
	var cx: float = w * 0.5
	var pad: float = r * 2.0
	var cluster: float = r * 5.0
	_middle.draw_line(Vector2(pad, y), Vector2(cx - cluster, y), color, 1.0)
	_middle.draw_line(Vector2(cx + cluster, y), Vector2(w - pad, y), color, 1.0)
	for offset: float in [-r * 3.0, r * 3.0]:
		_middle.draw_colored_polygon(_diamond(Vector2(cx + offset, y), r * 0.7), color)
	_middle.draw_polyline(_diamond_closed(Vector2(cx, y), r * 1.3), color, 1.0)


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])


func _diamond_closed(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = _diamond(center, radius)
	points.append(points[0])
	return points


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		_middle.queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_refresh()
