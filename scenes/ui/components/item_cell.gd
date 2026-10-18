# res://scenes/ui/components/item_cell.gd
# 品のマス（2026-10-18・回UI-1018-1・手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/mocks/Belongings.html` の `.cell`）。
#
# ⚠ 左上＝等級の色と数（⚠ 装備だけ）／ 右下＝★（装備）か「×3」（数を持つ品）／ 右上＝着けている人の顔 ／ 下＝札（着用中・最大・遺物）。
# ⚠ 状態：選んでいる（灯りの縁）／ 選べない（暗い）／ 一括分解で選んだ（封蝋の縁と ✓）。⚠ 決めるのは画面（⚠ ここは描くだけ）。
# ⚠ 絵は `ItemIcon`（40px）を大きさに合わせて伸ばす（⚠ 線画・画像の差し替えは `ItemIcon` の仕事のまま）。
# ⚠ 印は子の `Overlay` が引く（⚠ 自分の `_draw()` は子のアイコンより下に描かれるため）。
# ⚠ 持ち物・鍛冶場・育成・詰所で使う（⚠ 2画面以上＝components/）。⚠ `.new()` で作る。

class_name ItemCell
extends Button

signal cell_hovered(cell: ItemCell)
signal cell_unhovered(cell: ItemCell)

const THEME_TYPE: StringName = &"ItemCell"

enum Tag { PLAIN, MAX, RELIC }

var entry: Dictionary = {}
var key: String = ""

var _side: float = 0.0
var _selected: bool = false
var _picked: bool = false
var _locked: bool = false
var _tag_text: String = ""
var _tag_kind: int = Tag.PLAIN
var _icon: ItemIcon = null
var _overlay: Control = null


# ⚠ `side` が 0 なら Theme の `cell`（56）。⚠ 行の中は小さく（`row_icon`）。
static func create(p_entry: Dictionary, side: int = 0) -> ItemCell:
	var cell: ItemCell = ItemCell.new()
	cell.entry = p_entry
	cell.key = ItemView.key_of(p_entry)
	cell.name = "Cell_" + cell.key
	cell._build(side)
	return cell


func _build(side: int) -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	_side = float(side if side > 0 else ThemeDB.get_project_theme().get_constant(&"cell", THEME_TYPE))
	custom_minimum_size = Vector2(_side, _side)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var item_id: String = ItemView.item_id_of(entry)
	var grade: int = int(entry.get(GameManager.SLOT_ENTRY_GRADE, 0))
	_icon = ItemIcon.create(item_id, grade, ItemIcon.NO_COUNT)
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_letter_visible(false)
	var base: float = float(Balance.icon.icon_size_px) if Balance.icon != null else _side
	_icon.scale = Vector2.ONE * (_side / base)
	add_child(_icon)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	# ⚠ ★は `Overlay` が引く（⚠ 一覧の行の `SpecialEffectCard.star()` はマスには大きすぎた＝手本は 16px の墨の丸）。
	# ⚠ 着けている人の顔（⚠ 右上の外へ 6px）。
	var owner: String = str(entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if owner != "":
		var face_side: int = ThemeDB.get_project_theme().get_constant(&"owner", THEME_TYPE)
		var out: float = float(ThemeDB.get_project_theme().get_constant(&"owner_out", THEME_TYPE))
		var face: CharacterAvatar = CharacterAvatar.create(owner, face_side)
		face.name = "Owner"
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.position = Vector2(_side - float(face_side) + out, -out)
		face.size = Vector2(face_side, face_side)
		add_child(face)

	tooltip_text = ""
	mouse_entered.connect(func() -> void: cell_hovered.emit(self))
	mouse_exited.connect(func() -> void: cell_unhovered.emit(self))


# --- 状態（⚠ 決めるのは画面） ---

func set_selected(value: bool) -> void:
	_selected = value
	_redraw()


func is_selected() -> bool:
	return _selected


func set_picked(value: bool) -> void:
	_picked = value
	_redraw()


func is_picked() -> bool:
	return _picked


func set_locked(value: bool) -> void:
	_locked = value
	if _icon != null:
		var alpha: float = float(get_theme_constant(&"lock_alpha_pct", THEME_TYPE)) / 100.0
		_icon.modulate = Color(alpha, alpha, alpha, 0.6) if value else Color.WHITE
	_redraw()


func is_locked() -> bool:
	return _locked


# ⚠ ★（特殊効果）を出しているか（⚠ 装備だけ）。
func has_star() -> bool:
	return ItemView.is_instance(entry) and ItemView.is_special(entry)


func set_tag(text: String, kind: int = Tag.PLAIN) -> void:
	_tag_text = text
	_tag_kind = kind
	_redraw()


func get_tag_text() -> String:
	return _tag_text


func _redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


# --- 印 ---

func _draw_overlay() -> void:
	var font: Font = get_theme_default_font()
	var side: float = _side
	# 選んでいる（灯りの縁・外へ 4px）。
	if _selected:
		var out: float = float(get_theme_constant(&"ring_out", THEME_TYPE))
		_overlay.draw_rect(Rect2(-out, -out, side + out * 2.0, side + out * 2.0), get_theme_color(&"ring", THEME_TYPE), false, float(get_theme_constant(&"ring", THEME_TYPE)))
	# 等級の札（⚠ 装備だけ・左上・等級の色）。
	if ItemView.is_instance(entry) and Balance.icon != null:
		var grade: int = int(entry.get(GameManager.SLOT_ENTRY_GRADE, 1))
		var font_size: int = get_theme_constant(&"badge_font", THEME_TYPE)
		var pad: float = float(get_theme_constant(&"badge_pad", THEME_TYPE))
		var text: String = str(grade)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var badge: Rect2 = Rect2(1, 1, maxf(text_size.x + pad * 2.0, float(font_size) + 2.0), float(font_size) + 3.0)
		_overlay.draw_rect(badge, Balance.icon.color_of_grade(grade))
		_overlay.draw_string(font, Vector2(badge.position.x + (badge.size.x - text_size.x) * 0.5, badge.position.y + float(font_size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"badge_text", THEME_TYPE))
	# ★（⚠ 右下から少しはみ出す・手本 `.ic .st{right:-3px;bottom:-3px}`）。
	if has_star():
		var star_side: float = float(get_theme_constant(&"star", THEME_TYPE))
		var star_center: Vector2 = Vector2(side, side) + Vector2(3, 3) - Vector2(star_side, star_side) * 0.5
		_overlay.draw_circle(star_center, star_side * 0.5, get_theme_color(&"star_bg", THEME_TYPE))
		var star_font: int = get_theme_constant(&"star_font", THEME_TYPE)
		var star_text: String = TranslationServer.translate("ui_eqfx_star")
		var star_size: Vector2 = font.get_string_size(star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, star_font)
		_overlay.draw_string(font, star_center + Vector2(-star_size.x * 0.5, float(star_font) * 0.38), star_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, star_font, get_theme_color(&"star", THEME_TYPE))
	# 数（⚠ 数を持つ品だけ・右下「×3」）。
	var count: int = ItemView.count_of(entry)
	if count >= 0 and not ItemView.is_instance(entry):
		var count_size: int = get_theme_constant(&"count_font", THEME_TYPE)
		var count_text: String = TranslationServer.translate("ui_item_count_mark") % count
		var width: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size).x
		var at: Vector2 = Vector2(side - width - 2.0, side - 3.0)
		_overlay.draw_string(font, at + Vector2(1, 1), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, at, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, get_theme_color(&"count_text", THEME_TYPE))
	# 札（着用中・最大・遺物。⚠ 下の真ん中から少し下へ）。
	if _tag_text != "":
		var tag_size: int = get_theme_constant(&"tag_font", THEME_TYPE)
		var height: float = float(get_theme_constant(&"tag_height", THEME_TYPE))
		var tag_width: float = font.get_string_size(_tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 10.0
		var pill: Rect2 = Rect2((side - tag_width) * 0.5, side - height + float(get_theme_constant(&"tag_drop", THEME_TYPE)), tag_width, height)
		var bg_name: StringName = &"tag_bg"
		var fg_name: StringName = &"tag_text"
		if _tag_kind == Tag.MAX:
			bg_name = &"tag_max_bg"
			fg_name = &"tag_max_text"
		elif _tag_kind == Tag.RELIC:
			bg_name = &"tag_relic_bg"
			fg_name = &"tag_relic_text"
		_draw_pill(pill, get_theme_color(bg_name, THEME_TYPE))
		_overlay.draw_string(font, Vector2(pill.position.x + 5.0, pill.position.y + float(tag_size) + 1.0), _tag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, get_theme_color(fg_name, THEME_TYPE))
	# 一括分解で選んだ（封蝋の縁・真ん中に ✓）。
	if _picked:
		var ring: float = float(get_theme_constant(&"pick_ring", THEME_TYPE))
		_overlay.draw_rect(Rect2(-ring, -ring, side + ring * 2.0, side + ring * 2.0), get_theme_color(&"pick_ring", THEME_TYPE), false, ring)
		var radius: float = float(get_theme_constant(&"pick_mark", THEME_TYPE)) * 0.5
		var center: Vector2 = Vector2(side, side) * 0.5
		var light: Color = get_theme_color(&"pick_mark_text", THEME_TYPE)
		_overlay.draw_circle(center, radius, get_theme_color(&"pick_mark", THEME_TYPE))
		_overlay.draw_arc(center, radius, 0.0, TAU, 24, light, 2.0)
		_overlay.draw_polyline(PackedVector2Array([
			center + Vector2(-radius * 0.45, 0.0), center + Vector2(-radius * 0.1, radius * 0.35), center + Vector2(radius * 0.45, -radius * 0.35),
		]), light, 2.5)


func _draw_pill(rect: Rect2, color: Color) -> void:
	var radius: float = rect.size.y * 0.5
	_overlay.draw_rect(Rect2(rect.position + Vector2(radius, 0), rect.size - Vector2(radius * 2.0, 0)), color)
	_overlay.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	_overlay.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
