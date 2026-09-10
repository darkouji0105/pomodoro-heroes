class_name CharacterAvatar
extends PanelContainer

# キャラの顔（2026-09-11・人間のモック「ギルド／育成」B・C）。
#
# ⚠ 角丸の四角に絵文字を1つ置くだけのもの。⚠ **絵（SDキャラ）はまだ無い**（段階13・素材待ち）。
#   ⚠ 絵が入ったら、⚠ ここの Label を TextureRect に差し替えるだけで全画面が変わる。
# ⚠ 色も角丸も **Theme が持つ**（`CharacterAvatar` 型）。⚠ このファイルに色を書かない。
# ⚠ 絵文字は `Glyphs` の1本から引く（AGENTS.md「絵文字を書く場所は Glyphs だけ」）。
# ⚠ 2画面以上で使う（育成の一覧・育成の詳細・スキル設定）ので components/。

const THEME_TYPE: StringName = &"CharacterAvatar"
const COLOR_FALLBACK: String = "fallback"

var _glyph: Label = null


static func create(character_id: String, size_px: int) -> CharacterAvatar:
	var avatar: CharacterAvatar = CharacterAvatar.new()
	avatar.name = "Avatar"
	avatar.custom_minimum_size = Vector2(size_px, size_px)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar._build(character_id, size_px)
	return avatar


# ⚠ `_ready()` を待たない。⚠ 一覧が行を数十個作るので、⚠ 作った時点で確定させる
#   （⚠ 待つと最小サイズの計算が空の状態で走る）。
func _build(character_id: String, size_px: int) -> void:
	_glyph = Label.new()
	_glyph.name = "Glyph"
	_glyph.text = Glyphs.for_character(character_id)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ⚠ 絵文字は器の半分。⚠ アイテムのマス（40px の器に 20px の線画）と同じ割合にする。
	_glyph.add_theme_font_size_override(&"font_size", int(size_px / 2))
	add_child(_glyph)
	_apply_colors(character_id)


# ⚠ 色は Theme から引く。⚠ 表に無いキャラは `fallback`（⚠ 検証用の3体がここに来る）。
func _apply_colors(character_id: String) -> void:
	var key: String = character_id
	if not has_theme_color(StringName("bg_" + key), THEME_TYPE):
		key = COLOR_FALLBACK
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = get_theme_color(StringName("bg_" + key), THEME_TYPE)
	style.set_corner_radius_all(get_theme_constant(&"corner_radius", THEME_TYPE))
	add_theme_stylebox_override(&"panel", style)
	_glyph.add_theme_color_override(&"font_color", get_theme_color(StringName("fg_" + key), THEME_TYPE))
