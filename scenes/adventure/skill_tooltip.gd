class_name SkillTooltip
extends PanelContainer

# スキルのマスにマウスを乗せたときに出す説明の枠（2026-09-18・人間「ホバーすると
# スキルの説明が見えるように」＋人間が貼った参考画像）。
#
# ⚠ 参考画像の並び：⚠ 左上に絵 ／ ⚠ 名前 ／ ⚠ 右上にキー ／ ⚠ 右にクールダウン ／ ⚠ 下に説明文。
#   ⚠ マナと「レベルアップ」の行は**このゲームに無い**ので作らない（⚠ 無い値の欄を作らない）。
# ⚠ 説明文は `ui_desc_<skill_id>`（⚠ スキル設定の画面と同じ引き方）。⚠ 無ければ行ごと出さない
#   （⚠ 検証用のスキルには説明が無い）。
# ⚠ 入力を1つも受け取らない（⚠ 全部 MOUSE_FILTER_IGNORE）。⚠ 受け取るとマスから
#   外れたことに気づけず、⚠ 出たまま固まる（`ItemDetailPopup` で踏んだ形）。
# ⚠ 値は Theme の `SkillTile` 型（⚠ 幅・すきま）と variation（⚠ 面・字）。⚠ ここに書かない。
# ⚠ 使うのは戦闘だけなので `scenes/adventure/`（AGENTS.md）。

const THEME_TYPE: StringName = &"SkillTile"
# ⚠ 説明文のキーの頭。⚠ 綴りを散らさない（⚠ `skill_select_screen.gd` と同じ）。
const DESCRIPTION_PREFIX: String = "ui_desc_"

var _icon: TextureRect = null
var _name_label: Label = null
var _key_label: Label = null
var _meta_label: Label = null
var _desc_label: Label = null


func _ready() -> void:
	theme_type_variation = &"SkillTipPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	custom_minimum_size.x = get_theme_constant(&"tip_width", THEME_TYPE)
	# ⚠ 位置はコードで当てる（⚠ マスの上に出す）。⚠ アンカーは左上に固定。
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.theme_type_variation = &"ChipRow"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	# ⚠ SVG は 48px で読み込まれる。⚠ これが無いと大きさの指定が効かない（`resource_bar.gd` の注記）。
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px: int = get_theme_constant(&"icon", &"IconWell")
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_name_label)

	_key_label = Label.new()
	_key_label.name = "Key"
	_key_label.theme_type_variation = &"AccentLabel"
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_key_label)

	_meta_label = Label.new()
	_meta_label.name = "Meta"
	_meta_label.theme_type_variation = &"CaptionLabel"
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_meta_label)

	_desc_label = Label.new()
	_desc_label.name = "Description"
	_desc_label.theme_type_variation = &"CaptionLabel"
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_desc_label)


# そのマスの上に出す。⚠ 呼ぶのは `BattleController` のホバーの配線1本。
#
# ⚠ `key_label` は右上に出すキーの名前（⚠ 空なら出さない）。
func show_for(skill_id: String, name_text: String, key_label: String, tile: Control) -> void:
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	_icon.texture = IconTextures.for_skill(skill_id)
	_icon.visible = _icon.texture != null
	_name_label.text = name_text
	_key_label.text = "[%s]" % key_label if key_label != "" else ""
	_key_label.visible = key_label != ""

	# ⚠ クールダウンとチャージは `skills.json` の実測値（⚠ ここで計算しない）。
	#   ⚠ チャージは `activation: charge` のスキルだけが持つ（⚠ 無い値は出さない）。
	var meta: Array[String] = [
		tr("ui_skill_select_cooldown") % float(data.get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
	]
	if str(data.get(SkillSchema.FIELD_ACTIVATION, "")) == SkillSchema.ACTIVATION_CHARGE:
		var charge: Variant = data.get(SkillSchema.FIELD_CHARGE, null)
		if charge is Dictionary:
			meta.append(tr("ui_skill_select_charge") % float(
				(charge as Dictionary).get(SkillSchema.FIELD_JUST_SEC, 0.0)
			))
	_meta_label.text = "　".join(meta)

	# ⚠ 説明文は `ui_desc_<skill_id>`。⚠ `tr()` は表に無いキーをそのまま返すので、
	#   ⚠ 返りがキーと同じなら「無い」（⚠ `ItemDetail._add_description()` と同じ落とし方）。
	var key: String = DESCRIPTION_PREFIX + skill_id
	var text: String = tr(key)
	_desc_label.text = "" if text == key else text
	_desc_label.visible = _desc_label.text != ""

	visible = true
	_place_above(tile)


func hide_tip() -> void:
	visible = false


# マスの真上に出す。⚠ 画面からはみ出す分は内側へ寄せる。
#
# ⚠ 大きさは1フレーム待たないと確定しないので、⚠ 最小サイズで当てる
#   （⚠ `set_anchors_preset()` は今の大きさを保つ・§0-UI-F-4e で踏んだ罠）。
func _place_above(tile: Control) -> void:
	if tile == null or not is_instance_valid(tile):
		return
	var gap: float = float(get_theme_constant(&"tip_gap", THEME_TYPE))
	var box: Vector2 = get_combined_minimum_size()
	var tile_rect: Rect2 = tile.get_global_rect()
	var at: Vector2 = Vector2(
		tile_rect.get_center().x - box.x * 0.5,
		tile_rect.position.y - box.y - gap
	)
	var screen: Vector2 = get_viewport_rect().size
	at.x = clampf(at.x, gap, maxf(screen.x - box.x - gap, gap))
	at.y = maxf(at.y, gap)
	size = box
	global_position = at
