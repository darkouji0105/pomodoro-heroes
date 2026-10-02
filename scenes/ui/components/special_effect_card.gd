class_name SpecialEffectCard
extends PanelContainer

# 装備の特殊効果の札（2026-10-02・回UI-仕組み⑦・手本 RichItemFx / RichItemMax・`UI_GUIDE.md`「特殊効果＝墨に金」）。
#
# ⚠ 黒地（墨）に金：⚠ 1行目＝★と名前・右に「いつ起きるか」の小札 ／ ⚠ 2行目＝中身の一文。
# ⚠ 中身は `GameManager.get_special_effect_view()`（⚠ ここで効果のデータを読まない）。
# ⚠ 一覧の行の星は `SpecialEffectCard.star()`。⚠ 色は Theme の `SpecialEffect` 型。
# ⚠ 持ち物・記録・育成の装備で使う＝共通の部品（scenes/ui/components/）。

const THEME_TYPE: StringName = &"SpecialEffect"


# その品の札（⚠ 特殊効果が無ければ null＝呼ぶ側は何も足さない）。
static func create_for_item(item_id: String) -> SpecialEffectCard:
	var view: Dictionary = GameManager.get_special_effect_view(GameManager.get_item_special_effect(item_id))
	if view.is_empty():
		return null
	var card: SpecialEffectCard = SpecialEffectCard.new()
	card.name = "SpecialEffectCard"
	card.theme_type_variation = &"SpecialEffectPanel"
	var column: VBoxContainer = VBoxContainer.new()
	card.add_child(column)
	var line: HBoxContainer = HBoxContainer.new()
	column.add_child(line)
	var title: Label = Label.new()
	title.name = "EffectName"
	title.theme_type_variation = &"SpecialEffectTitleLabel"
	title.text = "%s %s" % [TranslationServer.translate("ui_eqfx_star"), TranslationServer.translate(str(view["name_key"]))]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	var trigger: Label = Label.new()
	trigger.name = "EffectTrigger"
	trigger.theme_type_variation = &"SpecialEffectTagLabel"
	trigger.text = TranslationServer.translate(str(view["trigger_key"]))
	trigger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(trigger)
	var desc: Label = Label.new()
	desc.name = "EffectDesc"
	desc.theme_type_variation = &"SpecialEffectTextLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = TranslationServer.translate(str(view["desc_key"]))
	column.add_child(desc)
	return card


# 一覧の行の星（⚠ 墨の丸に金の★）。⚠ 特殊効果が無ければ null。
static func star(item_id: String) -> Label:
	if GameManager.get_item_special_effect(item_id) == "":
		return null
	var mark: Label = Label.new()
	mark.name = "SpecialStar"
	mark.theme_type_variation = &"SpecialStarLabel"
	mark.text = TranslationServer.translate("ui_eqfx_star")
	mark.tooltip_text = TranslationServer.translate("ui_eqfx_legend")
	mark.mouse_filter = Control.MOUSE_FILTER_PASS
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var side: float = float(ThemeDB.get_project_theme().get_constant(&"star_size", THEME_TYPE))
	mark.custom_minimum_size = Vector2(side, side)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return mark
