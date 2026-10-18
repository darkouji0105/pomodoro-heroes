# res://scenes/guild/stat_node_cell.gd
# ステータスノードの暗いマス（2026-10-18・回UI-1018-4・web版の手本 `02_training_nd.png`・人間「⚠ ステータスノードもアイコンにプラス○○って書いてほしい」）。
#
# ⚠ 墨の地に真鍮のふち ／ 上にステータスの線の絵 ／ 下に「+5」を大きく ／ ⚠ `with_tag` なら下にはみ出す札「1ptごと」。
# ⚠ 値は渡されたものを出すだけ（⚠ 段の値は `GameManager.get_stat_node_step_value()`）。⚠ 色と寸法は Theme の `StatNodeCell`。
# ⚠ 育成（概要・ステータスノード）でしか使わないので scenes/guild/（AGENTS.md）。

class_name StatNodeCell
extends Control

const THEME_TYPE: StringName = &"StatNodeCell"

var _stat_key: String = ""
var _value: int = 0
var _with_tag: bool = false
var _side: float = 0.0


static func create(stat_key: String, value: int, side: int, with_tag: bool) -> StatNodeCell:
	var cell: StatNodeCell = StatNodeCell.new()
	cell.name = "NodeCell_" + stat_key
	cell._stat_key = stat_key
	cell._value = value
	cell._with_tag = with_tag
	cell._side = float(side)
	cell.custom_minimum_size = Vector2(side, side + (float(ThemeDB.get_project_theme().get_constant(&"tag_height", THEME_TYPE)) * 0.5 if with_tag else 0.0))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return cell


func get_value_text() -> String:
	return BelongingsDetail.stat_text(_stat_key, _value)


func _draw() -> void:
	var side: float = _side
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = get_theme_color(&"bg", THEME_TYPE)
	box.border_color = get_theme_color(&"border", THEME_TYPE)
	box.set_border_width_all(get_theme_constant(&"border", THEME_TYPE))
	box.set_corner_radius_all(get_theme_constant(&"corner", THEME_TYPE))
	draw_style_box(box, Rect2(0, 0, side, side))
	var ink: Color = get_theme_color(&"ink", THEME_TYPE)
	var texture: Texture2D = IconTextures.for_stat(_stat_key)
	var icon: float = side * float(get_theme_constant(&"icon_pct", THEME_TYPE)) / 100.0
	if texture != null:
		draw_texture_rect(texture, Rect2((side - icon) * 0.5, side * 0.14, icon, icon), false, ink)
	var font: Font = get_theme_default_font()
	var font_size: int = int(side * float(get_theme_constant(&"value_pct", THEME_TYPE)) / 100.0)
	var text: String = get_value_text()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((side - width) * 0.5, side * 0.86), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	if _with_tag:
		var tag_font: int = get_theme_constant(&"tag_font", THEME_TYPE)
		var tag_text: String = TranslationServer.translate("ui_stat_node_per_point")
		var tag_width: float = font.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font).x + 10.0
		var height: float = float(get_theme_constant(&"tag_height", THEME_TYPE))
		var pill: StyleBoxFlat = StyleBoxFlat.new()
		pill.bg_color = get_theme_color(&"tag_bg", THEME_TYPE)
		pill.border_color = get_theme_color(&"tag_border", THEME_TYPE)
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(int(height * 0.5))
		var rect: Rect2 = Rect2((side - tag_width) * 0.5, side - height * 0.5, tag_width, height)
		draw_style_box(pill, rect)
		draw_string(font, Vector2(rect.position.x + 5.0, rect.position.y + float(tag_font) + 1.0), tag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_font, get_theme_color(&"tag_ink", THEME_TYPE))
