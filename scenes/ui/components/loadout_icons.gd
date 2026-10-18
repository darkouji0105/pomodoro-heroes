# res://scenes/ui/components/loadout_icons.gd
# キャラの持ち物の小さな並び：スキルの枠 ／ 装備5つ（2026-10-18・回UI-1018-4・手本 `02_training_ov.png` の身上書と概要）。
#
# ⚠ スキル＝ふちで囲んだ線のアイコン（⚠ 空きは薄いふち）。⚠ 装備＝品のマス（`ItemCell`・⚠ 空きは薄い枠）。
# ⚠ 触れると出る札（`ItemTipCard`）を渡されていれば、⚠ 装備に触れると出す。
# ⚠ 押すと `pressed`（⚠ スキルなら "skill"・装備なら "equip"＝画面がそのタブを開く）。
# ⚠ 育成（身上書・概要）と詰所（ビルドの札）で使う（components/）。⚠ 値は Theme の `Loadout`。

class_name LoadoutIcons
extends HBoxContainer

signal pressed(kind: String)

const KIND_SKILL: String = "skill"
const KIND_EQUIP: String = "equip"
const THEME_TYPE: StringName = &"Loadout"

var tip: ItemTipCard = null


# スキルの枠（⚠ いま選んでいる枠の並び）。
static func skills(character_id: String, side: int) -> LoadoutIcons:
	var row: LoadoutIcons = LoadoutIcons.new()
	row.name = "SkillIcons"
	for raw: Variant in GameManager.get_selected_skills(character_id):
		row.add_child(skill_frame(str(raw) if raw != null else "", side))
	return row


# 装備5つ（⚠ 部位の並び）。
static func equipment(character_id: String, side: int, p_tip: ItemTipCard = null) -> LoadoutIcons:
	var row: LoadoutIcons = LoadoutIcons.new()
	row.name = "EquipIcons"
	row.tip = p_tip
	for raw: Variant in GameManager.get_equipment_slot_entries(character_id):
		var view: Dictionary = raw
		row.add_child(row._equip_slot(str(view.get(GameManager.SLOT_ENTRY_EQUIP_SLOT, "")), view.get(GameManager.SLOT_ENTRY_ENTRY, {}) as Dictionary, side))
	return row


# ふちで囲んだスキルのアイコン（⚠ 空きは薄いふちだけ）。
static func skill_frame(skill_id: String, side: int) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Skill_" + (skill_id if skill_id != "" else "empty")
	frame.theme_type_variation = &"SkillFrame" if skill_id != "" else &"SkillFrameEmpty"
	frame.custom_minimum_size = Vector2(side, side)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.tooltip_text = TranslationServer.translate(str(MasterDataLoader.get_skill(skill_id).get("name_key", ""))) if skill_id != "" else ""
	var texture: Texture2D = IconTextures.for_skill(skill_id) if skill_id != "" else null
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = ThemeDB.get_project_theme().get_color(&"skill_icon", THEME_TYPE)
		frame.add_child(icon)
	return frame


func _ready() -> void:
	theme_type_variation = &"LoadoutRow"
	for child: Node in get_children():
		# ⚠ 品のマスは自分の `pressed` を持つ（⚠ 二重に飛ばさない）。
		if child is Control and not (child is ItemCell):
			var kind: String = KIND_SKILL if str(child.name).begins_with("Skill_") else KIND_EQUIP
			(child as Control).gui_input.connect(_on_child_input.bind(kind))


func _equip_slot(slot: String, entry: Dictionary, side: int) -> Control:
	if entry.is_empty():
		var empty: PanelContainer = PanelContainer.new()
		empty.name = "Equip_" + slot
		empty.theme_type_variation = &"MergeSlotEmptyPanel"
		empty.custom_minimum_size = Vector2(side, side)
		empty.tooltip_text = TranslationServer.translate("ui_equipment_slot_" + slot)
		empty.mouse_filter = Control.MOUSE_FILTER_PASS
		return empty
	var cell: ItemCell = ItemCell.create(entry, side)
	cell.name = "Equip_" + slot
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.pressed.connect(func() -> void: pressed.emit(KIND_EQUIP))
	cell.cell_hovered.connect(_on_cell_hovered)
	cell.cell_unhovered.connect(_on_cell_unhovered)
	return cell


func _on_child_input(event: InputEvent, kind: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(kind)


func _on_cell_hovered(cell: ItemCell) -> void:
	if tip != null and is_instance_valid(tip):
		tip.show_entry(cell.entry)


func _on_cell_unhovered(_cell: ItemCell) -> void:
	if tip != null and is_instance_valid(tip):
		tip.hide_tip()
