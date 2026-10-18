class_name TownBuilding
extends Button

# ギルドの街の建物1つ（2026-10-18・回UI-1018-6・web版の手本 `05_base_town.png`・`NAV-34`）。
#
# ⚠ 上に建物の形（⚠ 線と面で描いた仮の形）・その下に名前の札・さらに下に小さい字（⚠ いま何があるか・空なら出さない）。
# ⚠ 押すとその施設へ（⚠ 行き先は街の側が持つ＝`pressed` を繋ぐ）。⚠ 面は持たない（Theme `TownBuildingButton`）。
# ⚠⚠ 絵はまだ無い（⚠ 段階13・素材待ち）。⚠ 絵が入ったら `_draw_shape()` の中身を差し替える。
# ⚠ 寸法と色は Theme の `BaseTown` 型。⚠ 形の割合（0〜1 の升目）はここに置く（⚠ 値ではなく形）。
# ⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。

const THEME_TYPE: StringName = &"BaseTown"
const SHAPE_HOUSE: String = "house"
const SHAPE_GATE: String = "gate"
const SHAPE_SHOP: String = "shop"
const SHAPE_TOWER: String = "tower"
const SHAPE_HALL: String = "hall"
const SHAPE_VAULT: String = "vault"
const SHAPE_FORGE: String = "forge"
const SHAPE_LAB: String = "lab"
const SHAPE_ALTAR: String = "altar"


static func create(id: String, shape: String, big: bool, label_key: String) -> TownBuilding:
	var building: TownBuilding = TownBuilding.new()
	building.name = "Building_" + id
	building._shape_kind = shape
	building._big = big
	building._label_key = label_key
	return building


var _shape_kind: String = SHAPE_HOUSE
var _big: bool = false
var _label_key: String = ""
var _shape: Control = null
var _note: Label = null


func _ready() -> void:
	theme_type_variation = &"TownBuildingButton"
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = &"TightList"
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_shape = Control.new()
	_shape.name = "Shape"
	_shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = float(get_theme_constant(&"big_shape" if _big else &"small_shape", THEME_TYPE))
	_shape.custom_minimum_size = Vector2(side, side)
	_shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shape.draw.connect(_draw_shape)
	column.add_child(_shape)
	var plate: PanelContainer = PanelContainer.new()
	plate.name = "Plate"
	plate.theme_type_variation = &"TownPlatePanel"
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.theme_type_variation = &"TownPlateBigLabel" if _big else &"TownPlateLabel"
	label.text = tr(_label_key)
	plate.add_child(label)
	_note = Label.new()
	_note.name = "NoteLabel"
	_note.theme_type_variation = &"TownNoteLabel"
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_note.visible = false
	column.add_child(_note)
	custom_minimum_size = column.get_combined_minimum_size()
	column.minimum_size_changed.connect(_on_column_resized.bind(column))


func _on_column_resized(column: VBoxContainer) -> void:
	custom_minimum_size = column.get_combined_minimum_size()


func set_note(text: String) -> void:
	if _note == null:
		return
	_note.text = text
	_note.visible = text != ""


# ⚠ しおり紐を付ける相手（⚠ 建物の形＝手本は屋根の右上）。
func shape_control() -> Control:
	return _shape


# ⚠ 置き場所の点に合わせる縦の位置（⚠ 形の下端）。
func anchor_y() -> float:
	return _shape.custom_minimum_size.y if _shape != null else 0.0


func _draw_shape() -> void:
	var s: Vector2 = _shape.size
	var wall: Color = get_theme_color(&"wall", THEME_TYPE)
	var line: Color = get_theme_color(&"line", THEME_TYPE)
	var dark: Color = get_theme_color(&"dark", THEME_TYPE)
	var light: Color = get_theme_color(&"light", THEME_TYPE)
	var width: float = float(get_theme_constant(&"line_width", THEME_TYPE))
	match _shape_kind:
		SHAPE_GATE:
			# ⚠ アーチの門（⚠ 2本の柱 ＋ 太い弧）。⚠ 穴のある形は1枚の多角形にしない（⚠ 三角に割れず赤が出た）。
			var center: Vector2 = Vector2(s.x * 0.5, s.y * 0.45)
			var outer_r: float = s.x * 0.38
			var inner_r: float = s.x * 0.14
			var band: float = outer_r - inner_r
			_shape.draw_arc(center, (outer_r + inner_r) * 0.5, PI, TAU, 32, wall, band, true)
			_shape.draw_rect(Rect2(center.x - outer_r, center.y, band, s.y * 0.95 - center.y), wall)
			_shape.draw_rect(Rect2(center.x + inner_r, center.y, band, s.y * 0.95 - center.y), wall)
			_shape.draw_arc(center, outer_r, PI, TAU, 32, line, width, true)
			_shape.draw_arc(center, inner_r, PI, TAU, 32, line, width, true)
			for x: float in [center.x - outer_r, center.x - inner_r, center.x + inner_r, center.x + outer_r]:
				_shape.draw_line(Vector2(x, center.y), Vector2(x, s.y * 0.95), line, width)
			_shape.draw_line(Vector2(center.x - outer_r, s.y * 0.95), Vector2(center.x - inner_r, s.y * 0.95), line, width)
			_shape.draw_line(Vector2(center.x + inner_r, s.y * 0.95), Vector2(center.x + outer_r, s.y * 0.95), line, width)
		SHAPE_TOWER:
			var tower: PackedVector2Array = _pts(s, [Vector2(0.32, 0.95), Vector2(0.32, 0.3), Vector2(0.5, 0.05), Vector2(0.68, 0.3), Vector2(0.68, 0.95)])
			_fill(tower, wall, line, width)
			_shape.draw_circle(Vector2(s.x * 0.5, s.y * 0.42), s.x * 0.08, light)
		SHAPE_HALL:
			var hall: PackedVector2Array = _pts(s, [Vector2(0.08, 0.95), Vector2(0.08, 0.45), Vector2(0.5, 0.1), Vector2(0.92, 0.45), Vector2(0.92, 0.95)])
			_fill(hall, get_theme_color(&"hall", THEME_TYPE), line, width)
			_shape.draw_rect(Rect2(s.x * 0.4, s.y * 0.6, s.x * 0.2, s.y * 0.35), dark)
		SHAPE_VAULT:
			var body: Rect2 = Rect2(s.x * 0.1, s.y * 0.38, s.x * 0.8, s.y * 0.57)
			_shape.draw_rect(body, wall)
			var lid: PackedVector2Array = _half_ellipse(Vector2(s.x * 0.5, s.y * 0.38), s.x * 0.4, s.y * 0.26)
			_shape.draw_colored_polygon(lid, wall)
			_shape.draw_polyline(lid, line, width, true)
			_shape.draw_rect(body, line, false, width)
			_shape.draw_rect(Rect2(s.x * 0.44, s.y * 0.48, s.x * 0.12, s.y * 0.14), light)
		SHAPE_SHOP:
			_shape.draw_rect(Rect2(s.x * 0.15, s.y * 0.45, s.x * 0.7, s.y * 0.5), wall)
			_shape.draw_rect(Rect2(s.x * 0.15, s.y * 0.45, s.x * 0.7, s.y * 0.5), line, false, width)
			_fill(_pts(s, [Vector2(0.1, 0.45), Vector2(0.2, 0.3), Vector2(0.8, 0.3), Vector2(0.9, 0.45)]), get_theme_color(&"awning", THEME_TYPE), line, width)
		SHAPE_FORGE:
			_shape.draw_rect(Rect2(s.x * 0.62, s.y * 0.1, s.x * 0.1, s.y * 0.35), dark)
			var forge: PackedVector2Array = _pts(s, [Vector2(0.18, 0.95), Vector2(0.18, 0.5), Vector2(0.5, 0.22), Vector2(0.82, 0.5), Vector2(0.82, 0.95)])
			_fill(forge, get_theme_color(&"forge", THEME_TYPE), line, width)
			_shape.draw_circle(Vector2(s.x * 0.5, s.y * 0.7), s.x * 0.08, get_theme_color(&"fire", THEME_TYPE))
		SHAPE_LAB:
			var lab: PackedVector2Array = _pts(s, [Vector2(0.18, 0.95), Vector2(0.18, 0.5), Vector2(0.5, 0.22), Vector2(0.82, 0.5), Vector2(0.82, 0.95)])
			_fill(lab, get_theme_color(&"lab", THEME_TYPE), line, width)
			_shape.draw_arc(Vector2(s.x * 0.5, s.y * 0.62), s.x * 0.1, 0.0, TAU, 24, light, width, true)
		SHAPE_ALTAR:
			_shape.draw_line(Vector2(s.x * 0.5, s.y * 0.1), Vector2(s.x * 0.5, s.y * 0.45), get_theme_color(&"spark", THEME_TYPE), width)
			_fill(_pts(s, [Vector2(0.15, 0.95), Vector2(0.3, 0.45), Vector2(0.7, 0.45), Vector2(0.85, 0.95)]), dark, line, width)
		_:
			var house: PackedVector2Array = _pts(s, [Vector2(0.15, 0.95), Vector2(0.15, 0.5), Vector2(0.5, 0.18), Vector2(0.85, 0.5), Vector2(0.85, 0.95)])
			_fill(house, wall, line, width)


func _pts(s: Vector2, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for raw: Variant in unit:
		var p: Vector2 = raw
		out.append(Vector2(p.x * s.x, p.y * s.y))
	return out


func _fill(points: PackedVector2Array, fill: Color, line: Color, width: float) -> void:
	_shape.draw_colored_polygon(points, fill)
	_shape.draw_polyline(points + PackedVector2Array([points[0]]), line, width, true)


# ⚠ 上半分の楕円（⚠ 左端 → 上 → 右端）。⚠ 凸なので三角に割れる。
func _half_ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for step: int in range(0, 17):
		var a: float = PI + PI * float(step) / 16.0
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out
