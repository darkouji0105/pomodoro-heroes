class_name BelongingsDetail
extends VBoxContainer

# 持ち物の右の説明の紙（2026-09-27・回UI-組 持ち物・手本 Belongings / RichItemMulti・人間「⚠ 3あ」）。
#
# ⚠ 中身は押した品の種類で変わる（⚠ 装備の個体 ／ 装飾 ／ 素材・消耗品）。⚠ 種類の分岐はここ1本。
#   ⚠ 装備 … 絵・名前・主な値 ／ 全部の値 ／ 装飾の枠（刺さっている・空き・鍵）／ 誰が着けているか ／ 鍛える・刺す・分解
#   ⚠ 装飾 … 絵・名前・値の幅 ／ 持っている数 ／ 段階を上げる・壊す（⚠ ルーンは重ねる）
#   ⚠ 素材 … 絵・名前 ／ 持っている数 ／ ⚠ 持ち物のマスを使う品だけ「捨てる」（⚠ 人間「⚠ 4あ」＝容量の判定を消す回まで残す）
# ⚠⚠ 前は説明の窓（`ItemActionPanel`）と装備画面（仮の鍛冶場）にあった操作。⚠ 両方消してここへ集めた（決定 `BS-16`）。
# ⚠⚠ **判定は全部 `GameManager` の口に聞く**（⚠ 押せるか・値段・戻る素材・刺さるか）。⚠ ここに2本目を書かない。
# ⚠ 紙そのものは持たない（⚠ 置く側が紙に入れる）。⚠ 持ち物でしか使わないので scenes/guild/（AGENTS.md）。
# ⚠⚠ 無名関数をシグナルにつながない（⚠ `Lambda capture ... was freed`）。⚠ 名前付き＋`bind()`。

# ⚠ 装飾の枠を押した・「刺す」を押した（⚠ 刺せる装飾を並べるのは画面の仕事）。
signal attach_requested(instance_id: String, slot_index: int)
# ⚠ 装飾の「装備に刺す…」（⚠ 刺す先の装備を並べるのは画面の仕事・10-18）。
signal attach_part_requested(item_id: String)

const THEME_TYPE: StringName = &"Belongings"
const FORGE_PATH: String = "res://scenes/guild/forge_screen.tscn"
const WAREHOUSE_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const DESCRIPTION_PREFIX: String = "ui_desc_"

# ⚠ 吹き出しを出す画面（⚠ `SlotActionPopover` の置き場）。⚠ 画面が入れる。
var host: Control = null

var _entry: Dictionary = {}
# ⚠ 「だれが着けると」で選んでいる人（⚠ 画面の控え・状態には無い）。⚠ 空なら持ち主か編成の先頭。
var _who: String = ""


# ⚠ 2つ目の引数（持ち物のマスを使うか）は「捨てる」にだけ使っていた（⚠ 10-03 に消した・`EQ-14`）。⚠ 呼び手を変えないため残す。
func setup(entry: Dictionary, _in_inventory: bool) -> void:
	_entry = entry.duplicate(true)
	_rebuild()


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _rebuild() -> void:
	if host != null:
		SlotActionPopover.close_in(host)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _entry.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = &"CaptionLabel"
		none.text = tr("ui_detail_none")
		add_child(none)
		return
	match str(_entry.get(GameManager.SLOT_ENTRY_KIND, "")):
		GameManager.SLOT_KIND_INSTANCE:
			_build_instance(str(_entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, "")))
		_:
			var item_id: String = str(_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
			if not GameManager.get_part_definition(item_id).is_empty():
				_build_part(item_id)
			else:
				_build_item(item_id)


# --- 装備の個体 ---
# ⚠⚠ 10-18（回UI-1018-2・手本 `06_belongings_eq_grid.png` の右の紙）：⚠ 頭 ／ 主な値 ／ ほかの能力 ／ ★ ／ 装飾の枠
#   ／ だれが着けると（⚠ 編成の3人・押すと比べる）／ 着ける・鍛える・分解。
# ⚠⚠ 09-27 に消した「キャラ3人の札」を戻した（⚠ web版の手本＝人間が作ったもの）。⚠ 着けられるかは `get_equip_reject_reason()` の1本
#   ＝⚠ ほかの人が着けている品は着けられない（⚠ 1個につき1人のまま・09-27 の人間の決定）。

func _build_instance(instance_id: String) -> void:
	var instance: Dictionary = GameManager.get_equipment_instance(instance_id)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	var equip_slot: String = str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))
	_add_head(_entry, tr(GameManager.item_name_key(item_id)), ItemView.sub_text(_entry), "")

	var main_key: String = ItemView.main_stat_key(_entry)
	if main_key != "":
		add_child(_value_line("MainLine", tr("ui_training_stat_" + main_key), ItemView.main_value_text(_entry), true, IconTextures.for_stat(main_key)))
	var others: String = ItemView.other_stats_text(_entry)
	if others != "":
		add_child(_value_line("OtherLine", tr("ui_item_tip_other"), others, false, null))
	# ⚠ 特殊効果の札（2026-10-02・回UI-仕組み⑦・手本 RichItemFx＝値の下・装飾の上）。
	var effect_card: SpecialEffectCard = SpecialEffectCard.create_for_item(item_id)
	if effect_card != null:
		add_child(effect_card)
	_build_part_slots(instance_id, equip_slot, grade)
	_build_who(instance_id, equip_slot)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var forge_note: Label = Label.new()
	forge_note.name = "ForgeNote"
	forge_note.theme_type_variation = &"CaptionLabel"
	forge_note.text = _forge_note(instance_id)
	add_child(forge_note)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Actions"
	var wear: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_belongings_wear")
	wear.name = "WearButton"
	wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var who: String = _who_of(instance_id)
	wear.disabled = who == "" or GameManager.get_equipped_instance_id(who, equip_slot) == instance_id \
		or GameManager.get_equip_reject_reason(who, equip_slot, instance_id) != ""
	wear.pressed.connect(_on_wear_pressed.bind(who, equip_slot, instance_id))
	buttons.add_child(wear)
	var forge: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_equipment_forge")
	forge.name = "ForgeButton"
	forge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 2026-09-27（人間「⚠ 3あ」）：⚠ ここでは鍛えない。⚠ 鍛冶場をこの品を選んだ状態で開く（⚠ 素材の足りる・足りないは鍛冶場が出す）。
	forge.disabled = grade >= GameManager.get_max_equipment_grade()
	forge.pressed.connect(_on_forge_pressed.bind(instance_id))
	buttons.add_child(forge)
	# ⚠ 分解は戻らない＝赤（決定 `MD-5`）。⚠ 着けている個体は外してから（⚠ 前と同じ）。
	# ⚠ 10-07（見る回23回目）：⚠ 遺物に点数が入る品（等級5以上）は「捧げる」（⚠ 口は同じ `dismantle_equipment()`）。
	var offerable: bool = not GameManager.get_offer_preview(instance_id).is_empty()
	var melt: UiButton = UiButton.create(UiButton.Variant.DANGER, "ui_grelic_offer" if offerable else "ui_belongings_dismantle")
	melt.name = "DismantleButton"
	melt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	melt.disabled = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, "")) != ""
	melt.pressed.connect(_on_dismantle_pressed.bind(instance_id))
	buttons.add_child(melt)
	add_child(buttons)


# 「だれが着けると」：⚠ 編成の3人の札（⚠ 押すとその人で比べる）＋ ⚠ 比べた1行（「剣士：18 → 76 +58」）。
func _build_who(instance_id: String, equip_slot: String) -> void:
	var members: Array[String] = []
	for raw: Variant in GameManager.get_party_members():
		if str(raw) != "":
			members.append(str(raw))
	if members.is_empty():
		return
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_belongings_who")
	add_child(caption)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "WhoRow"
	add_child(row)
	var who: String = _who_of(instance_id)
	var face: int = get_theme_constant(&"who_face", THEME_TYPE)
	for character_id: String in members:
		var button: Button = Button.new()
		button.name = "Who_" + character_id
		button.theme_type_variation = &"PaperChoiceSelected" if character_id == who else &"PaperChoice"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_who_pressed.bind(character_id))
		# ⚠ 顔と名前を横に（⚠ ボタンは子を並べないので、⚠ 押下を通す横の器を全面に敷く）。
		var inner: HBoxContainer = HBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		var avatar: CharacterAvatar = CharacterAvatar.create(character_id, face)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(avatar)
		var label: Label = Label.new()
		label.text = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(label)
		button.add_child(inner)
		button.custom_minimum_size.y = inner.get_combined_minimum_size().y + 12.0
		row.add_child(button)
	var line: Label = Label.new()
	line.name = "CompareLine"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var main_key: String = ItemView.main_stat_key(_entry)
	var reason: String = GameManager.get_equip_reject_reason(who, equip_slot, instance_id)
	var who_name: String = tr(str(MasterDataLoader.get_character(who).get("name_key", who)))
	if main_key == "":
		line.text = ""
	elif reason != "" and GameManager.get_equipped_instance_id(who, equip_slot) != instance_id:
		line.theme_type_variation = &"CaptionLabel"
		var owner: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
		line.text = tr("ui_belongings_who_worn") % tr(str(MasterDataLoader.get_character(owner).get("name_key", owner))) if owner != "" and owner != who \
			else tr("ui_belongings_who_cannot") % who_name
	else:
		var now: int = int(GameManager.get_effective_stats(who).get(main_key, 0))
		var current: String = GameManager.get_equipped_instance_id(who, equip_slot)
		var mine: int = int(ItemView.stats_of(_entry).get(main_key, 0))
		var theirs: int = 0 if current == "" else int(GameManager.get_instance_stats(current).get(main_key, 0))
		var after: int = now if current == instance_id else now - theirs + mine
		line.theme_type_variation = &"GainLabel" if after >= now else &"ErrorLabel"
		line.text = tr("ui_belongings_who_compare") % [tr("ui_training_stat_" + main_key), who_name, now, after, BelongingsDetail.stat_text(main_key, after - now)]
	add_child(line)


# ⚠ 比べる人：⚠ 選んだ人 ／ ⚠ 無ければ持ち主（⚠ 編成にいれば）／ ⚠ 無ければ編成の先頭。
func _who_of(_instance_id: String) -> String:
	var members: Array[String] = []
	for raw: Variant in GameManager.get_party_members():
		if str(raw) != "":
			members.append(str(raw))
	if _who in members:
		return _who
	var owner: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if owner in members:
		return owner
	return members[0] if not members.is_empty() else ""


# 1行：（絵）見出し …… 値。⚠ 主な値は大きく。
func _value_line(line_name: String, caption_text: String, value_text: String, big: bool, texture: Texture2D) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = line_name
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = float(get_theme_constant(&"row_icon", &"Training"))
		icon.custom_minimum_size = Vector2(side, side)
		icon.modulate = get_theme_color(&"row_icon", &"Training")
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"" if big else &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "Value"
	value.theme_type_variation = &"DossierLevelLabel" if big else &""
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(value)
	return line


# 装飾の枠（⚠ 刺さっている・空き・次に開く鍵＝決定 `BS-17`）。⚠ 並びは `ItemDetail.merged_part_defs()` の1本。
func _build_part_slots(instance_id: String, equip_slot: String, grade: int) -> void:
	var row: PartSlotRow = PartSlotRow.create(ItemDetail.merged_part_defs(instance_id, equip_slot), grade)
	if row.get_open_count() == 0 and row.get_next_locked_grade() <= 0:
		row.queue_free()
		return
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = "%s  %d / %d" % [tr("ui_part_slot_header"), row.get_filled_count(), row.get_open_count()]
	add_child(caption)
	# ⚠⚠ 装飾そのものがまだ解放されていないことがある（⚠ 門1・前の説明の窓と同じ）。⚠ 押せるようにせず1行だけ出す。
	if not GameManager.is_part_kind_unlocked(GameManager.PART_KIND_GEM):
		row.queue_free()
		var locked: Label = Label.new()
		locked.name = "PartGateLabel"
		locked.theme_type_variation = &"MutedLabel"
		locked.text = tr("ui_part_gate_locked")
		add_child(locked)
		return
	add_child(row)
	for node: Node in row.find_children("*", "PartSlotIcon", true, false):
		(node as PartSlotIcon).pressed.connect(_on_part_slot_pressed.bind(instance_id))
	if row.get_next_locked_grade() > 0:
		var hint: Label = Label.new()
		hint.theme_type_variation = &"CaptionLabel"
		hint.text = tr("ui_part_slot_next_hint") % row.get_next_locked_grade()
		add_child(hint)


# 「鍛える：鉄の塊 8 ／ 24」。⚠ 素材と数は `get_forge_cost()` の1本。
func _forge_note(instance_id: String) -> String:
	var cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return tr("ui_equipment_max_grade")
	var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
	return tr("ui_belongings_forge_note") % [tr("ui_res_" + material_id), amount, GameManager.get_material_count(material_id)]


# --- 装飾 ---

func _build_part(item_id: String) -> void:
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	var main_text: String = ""
	if stat_key != "":
		main_text = "%s %s" % [tr("ui_training_stat_" + stat_key), BelongingsDetail.part_range_text(item_id)]
	_add_head(_entry, tr(GameManager.item_name_key(item_id)), ItemView.sub_text(_entry), "")
	if main_text != "":
		add_child(_value_line("EffectLine", tr("ui_belongings_effect"), main_text, true, IconTextures.for_stat(stat_key)))
	add_child(_value_line("CountLine", tr("ui_item_tip_owned"), tr("ui_item_count_mark") % GameManager.get_item_count(item_id), true, null))
	_add_description(item_id)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# ⚠ 10-18（回UI-1018-2・手本 `06_belongings_part_grid.png`）：⚠ 装飾から刺す先を選ぶ（⚠ 空き枠のある装備を並べてもらう）。
	var attach_to: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_belongings_attach_to")
	attach_to.name = "AttachToButton"
	attach_to.disabled = GameManager.get_item_count(item_id) <= 0 \
		or not GameManager.is_part_kind_unlocked(str(definition.get(GameManager.ITEM_MASTER_PART_KIND, "")))
	attach_to.pressed.connect(_on_attach_to_pressed.bind(item_id))
	add_child(attach_to)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Actions"
	add_child(buttons)
	# ⚠ ルーンは分解方式で上がらない（GAME_DESIGN.md 7-7）。⚠ ボタンは「重ねる」1つだけ。
	if not GameManager.get_rune_definition(item_id).is_empty():
		var reason: String = GameManager.get_rune_merge_reject_reason(item_id)
		if reason == GameManager.RUNE_REJECT_MAX or reason == GameManager.RUNE_REJECT_KIND:
			return
		var merge: UiButton = UiButton.create()
		merge.name = "RuneMergeButton"
		merge.text = "%s(%d)" % [tr("ui_part_rune_merge"), GameManager.get_rune_merge_count()]
		merge.disabled = reason != ""
		merge.pressed.connect(_on_rune_merge_pressed.bind(item_id))
		buttons.add_child(merge)
		return
	# ⚠⚠ 装飾は「鍛える」ではなく「段階を上げる」（決定 `BS-18`）。⚠ 混ぜない。
	if GameManager.get_upgraded_part_id(item_id) != "":
		var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
		var upgrade: UiButton = UiButton.create()
		upgrade.name = "PartUpgradeButton"
		upgrade.text = tr("ui_part_upgrade")
		# ⚠ 10-07（人間「⚠ 足りないボタンは不足とは出さないで数字の色で」）：⚠ 素材の数はボタンの外に出して、足りなければ赤。
		var upgrade_material: String = str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, ""))
		var upgrade_amount: int = int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0))
		var upgrade_cost: Label = Label.new()
		upgrade_cost.name = "PartUpgradeCostLabel"
		upgrade_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		upgrade_cost.text = "%s %d / %d" % [tr("ui_res_" + upgrade_material), GameManager.get_material_count(upgrade_material), upgrade_amount]
		upgrade_cost.theme_type_variation = &"" if GameManager.get_material_count(upgrade_material) >= upgrade_amount else &"ErrorLabel"
		buttons.add_child(upgrade_cost)
		# ⚠ 10-07（人間「⚠ プラスボタン押さなくても　例えば必要な素材を提示する画面などがあれば」・`NAV-19`）：⚠ 素材が足りなくても押せる＝押すと入手先の窓。
		upgrade.disabled = GameManager.get_item_count(item_id) <= 0
		upgrade.pressed.connect(_on_part_upgrade_pressed.bind(item_id))
		buttons.add_child(upgrade)
		# ⚠ 「入手先を見る」は 10-07 に外した（⚠ 人間「⚠ 減らして」）＝足りないまま「段階を上げる」を押すと窓。
	var refund_total: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund_total += int(amount)
	var break_button: UiButton = UiButton.create()
	break_button.name = "PartDismantleButton"
	break_button.text = "%s(%d)" % [tr("ui_part_dismantle"), refund_total]
	break_button.disabled = refund_total <= 0
	break_button.pressed.connect(_on_part_dismantle_pressed.bind(item_id))
	buttons.add_child(break_button)


# --- 素材・消耗品 ---

func _build_item(item_id: String) -> void:
	var count: int = int(_entry.get(GameManager.SLOT_ENTRY_COUNT, 0))
	_add_head(_entry, tr(GameManager.item_name_key(item_id)), ItemView.sub_text(_entry), "")
	add_child(_value_line("CountLine", tr("ui_item_tip_owned"), str(count), true, null))
	# ⚠ 10-18（人間「⚠ １あつくって」）：⚠ 使い道（⚠ 今ある費用から拾う＝`get_material_uses()`）。
	var uses: Array[String] = GameManager.get_material_uses(item_id)
	if not uses.is_empty():
		var names: Array[String] = []
		for use: String in uses:
			names.append(tr("ui_material_use_" + use))
		add_child(_value_line("UseLine", tr("ui_material_uses"), tr("ui_barracks_skill_separator").join(names), false, null))
	_add_description(item_id)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	if not uses.is_empty():
		var go: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_material_go_use")
		go.name = "GoUseButton"
		go.pressed.connect(_on_go_use_pressed.bind(item_id, uses))
		add_child(go)
	# ⚠ 「捨てる」は消した（2026-10-03・回3-d・`EQ-14`＝拠点に容量が無い）。
	# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓（⚠ 行った先の「戻る」で持ち物の素材タブへ戻る）。
	if GameManager.get_material_ids().has(item_id):
		var source: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_source_open")
		source.name = "SourceButton"
		source.pressed.connect(ItemSourceWindow.open.bind(self, item_id, 0, {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_MATERIAL}))
		add_child(source)


# --- 小さい器 ---

# 頭：絵 ／ 名前（明朝）・添え書き ／ 主な値。
func _add_head(entry: Dictionary, name_text: String, sub_text: String, main_text: String) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	var icon: ItemCell = ItemCell.create(entry, get_theme_constant(&"head_icon", THEME_TYPE))
	icon.name = "HeadIcon"
	# ⚠ 10-07：⚠ アイコンを押しても入手先の窓（⚠ 装備の個体は品のIDで引く）。
	ItemSourceWindow.attach_to(icon, str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = name_text
	column.add_child(name_label)
	var sub: Label = Label.new()
	sub.theme_type_variation = &"CaptionLabel"
	sub.text = sub_text
	column.add_child(sub)
	if main_text != "":
		var main: Label = Label.new()
		main.name = "MainLabel"
		main.theme_type_variation = &"DossierLevelLabel"
		main.text = main_text
		column.add_child(main)
	add_child(head)
	add_child(HSeparator.new())


# ⚠ 効果文は `ui_desc_<id>`。⚠ 無ければ出さない（⚠ `tr()` は表に無いキーをそのまま返す）。
func _add_description(item_id: String) -> void:
	var key: String = DESCRIPTION_PREFIX + item_id
	if tr(key) == key:
		return
	var label: Label = Label.new()
	label.name = "DescriptionLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr(key)
	add_child(label)


# ⚠ 一番大きい値を「主な値」にする（⚠ 同じならステータスの並び順で先のもの）。⚠ 行と紙で同じものを使う。
static func main_stat_of(stats: Dictionary) -> String:
	var best: String = ""
	var best_value: int = 0
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int(stats.get(stat_key, 0))
		if value > best_value:
			best = stat_key
			best_value = value
	return best


# 「+160」「+17%」。⚠ 10-07（回HB-2）：⚠ マイナスは「−」のまま（⚠ 型の「下げる値」）。
static func stat_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%+d%%" % value
	return "%+d" % value


# 装飾の値の幅（⚠ 出目で変わる＝`part_base` 〜 `part_base + part_roll_max`）。
static func part_range_text(item_id: String) -> String:
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	var base: int = int(definition.get(GameManager.ITEM_MASTER_PART_BASE, 0))
	var top: int = base + int(definition.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0))
	if top == base:
		return BelongingsDetail.stat_text(stat_key, base)
	return "%s〜%s" % [BelongingsDetail.stat_text(stat_key, base), BelongingsDetail.stat_text(stat_key, top)]


# --- 押されたもの（⚠ 口は全部 `GameManager`。⚠ 描き直しは画面がシグナルで受ける） ---

# ⚠ 10-06（`NAV-18`）：⚠ 寄り道＝鍛冶場の「戻る」でこの品を選んだ持ち物へ（⚠ 前は本部へ飛んだ）。
func _on_forge_pressed(instance_id: String) -> void:
	SceneManager.open_detour(FORGE_PATH, {TransferKeys.FORGE_INSTANCE_ID: instance_id},
		WAREHOUSE_PATH, {TransferKeys.WAREHOUSE_INSTANCE_ID: instance_id})


# ⚠ 使い道ごとの行き先（⚠ 寄り道＝行った先の「戻る」で持ち物の素材タブへ）。
static func use_path(use: String) -> String:
	match use:
		GameManager.MATERIAL_USE_RESEARCH:
			return "res://scenes/guild/research_screen.tscn"
		GameManager.MATERIAL_USE_CRAFT:
			return "res://scenes/guild/workshop_screen.tscn"
		GameManager.MATERIAL_USE_FORGE:
			return FORGE_PATH
		GameManager.MATERIAL_USE_LEVEL_UP:
			return "res://scenes/guild/training_screen.tscn"
	return WAREHOUSE_PATH


# 「使う所へ行く」：⚠ 使い道が1つならそこへ ／ ⚠ 2つ以上なら吹き出しで選ぶ。
func _on_go_use_pressed(item_id: String, uses: Array[String]) -> void:
	if uses.size() == 1 or host == null:
		go_to_use(uses[0])
		return
	var anchor: Control = find_child("GoUseButton", true, false) as Control
	var pop: SlotActionPopover = SlotActionPopover.open(host, anchor.get_global_rect() if anchor != null else Rect2(), tr(GameManager.item_name_key(item_id)), tr("ui_material_go_use_pick"))
	for use: String in uses:
		var button: UiButton = pop.add_action(tr("ui_material_use_" + use), UiButton.Variant.SECONDARY, go_to_use.bind(use))
		button.name = "GoUse_" + use


func go_to_use(use: String) -> void:
	var data: Dictionary = {}
	if use == GameManager.MATERIAL_USE_PART_UPGRADE:
		data[TransferKeys.WAREHOUSE_TAB] = TransferKeys.WAREHOUSE_TAB_PART
	SceneManager.open_detour(use_path(use), data, WAREHOUSE_PATH, {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_MATERIAL})


func _on_attach_to_pressed(item_id: String) -> void:
	attach_part_requested.emit(item_id)


func _on_who_pressed(character_id: String) -> void:
	_who = character_id
	_rebuild()


# ⚠ 着ける（⚠ 判定は `equip_instance()` の1本。⚠ 描き直しは画面がシグナルで受ける）。
func _on_wear_pressed(character_id: String, slot: String, instance_id: String) -> void:
	GameManager.equip_instance(character_id, slot, instance_id)


# ⚠ 分解は戻らない。⚠ 確かめの窓を通す（決定 `MD-10`・手本 Confirm「分解する」）。
func _on_dismantle_pressed(instance_id: String) -> void:
	var item_id: String = str(GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var offer: Dictionary = GameManager.get_offer_preview(instance_id)
	if not offer.is_empty():
		var offered: bool = await Modal.confirm(self, "ui_grelic_offer_confirm", [tr(GameManager.item_name_key(item_id))], false, {
			Modal.OPTION_TITLE: tr("ui_grelic_offer"),
		})
		if not offered or not is_instance_valid(self):
			return
		var host: Node = get_tree().current_scene
		if GameManager.dismantle_equipment(instance_id):
			GuildRelicScreen.notify_offered(host, offer)
		return
	var confirmed: bool = await Modal.confirm(
		self, "ui_belongings_dismantle_confirm",
		[tr(GameManager.item_name_key(item_id)), GameManager.get_dismantle_refund_total(instance_id)], false, {
			Modal.OPTION_TITLE: tr("ui_belongings_dismantle_title"),
			Modal.OPTION_DANGER: true,
			Modal.OPTION_CONFIRM_LABEL: "ui_belongings_dismantle",
			Modal.OPTION_STAMP: "ui_stamp_irreversible",
		}
	)
	if not confirmed or not is_instance_valid(self):
		return
	GameManager.dismantle_equipment(instance_id)


# 装飾の枠を押した。⚠ 空き → 刺せる装飾を並べてもらう ／ ⚠ 刺さっている → 吹き出し（外す・移動量・決定 `BS-14`）。
func _on_part_slot_pressed(view: Dictionary, instance_id: String) -> void:
	var slot_index: int = int(view.get(GameManager.PART_VIEW_INDEX, 0))
	var entry: Variant = view.get(GameManager.PART_VIEW_ENTRY, null)
	if not (entry is Dictionary):
		attach_requested.emit(instance_id, slot_index)
		return
	_open_part_popover(instance_id, slot_index, view, entry as Dictionary)


func _open_part_popover(instance_id: String, slot_index: int, view: Dictionary, entry: Dictionary) -> void:
	if host == null:
		return
	var icon: Control = null
	for node: Node in find_children("PartSlot_%d" % slot_index, "", true, false):
		icon = node as Control
	if icon == null:
		return
	var pop: SlotActionPopover = SlotActionPopover.open(
		host, icon.get_global_rect(), tr(PartSlotIcon.part_slot_label_key(view)), _part_text(entry)
	)
	# ⚠⚠ 外すと壊れる（GAME_DESIGN.md 7-6）＝赤（決定 `MD-5`）。⚠ 確認はハンドラ側。
	var detach: UiButton = pop.add_action(
		tr("ui_part_detach"), UiButton.Variant.DANGER, _on_detach_part_pressed.bind(instance_id, slot_index)
	)
	detach.name = "DetachButton"
	_add_rune_move_actions(pop, entry)


func _add_rune_move_actions(pop: SlotActionPopover, entry: Dictionary) -> void:
	var item_id: String = str(entry.get(GameStateKeys.PART_ITEM_ID, ""))
	var choices: Array[int] = GameManager.get_rune_move_choices(item_id)
	if choices.is_empty():
		return
	var owner: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	var current: int = GameManager.get_rune_move(owner, item_id) if owner != "" else 0
	for value: int in choices:
		var button: UiButton = pop.add_action(
			tr("ui_part_rune_move_format") % value, UiButton.Variant.GHOST,
			_on_rune_move_chosen.bind(owner, item_id, value), value == current or owner == ""
		)
		button.name = "RuneMove_%d" % value
	pop.set_note(tr("ui_part_rune_move"))


# ⚠ 判定は set_rune_move() が持つ。⚠ ここで choices を検算しない。
func _on_rune_move_chosen(owner: String, item_id: String, value: int) -> void:
	GameManager.set_rune_move(owner, item_id, value)


# 刺さっている装飾1つ分。「HPの宝石④  HP +131」。⚠ 加算量は `get_part_stat_value()` の1本。
func _part_text(entry: Dictionary) -> String:
	var item_id: String = str(entry.get(GameStateKeys.PART_ITEM_ID, ""))
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	if stat_key == "":
		return tr("ui_res_" + item_id)
	return "%s  %s %s" % [
		tr("ui_res_" + item_id), tr("ui_training_stat_" + stat_key),
		BelongingsDetail.stat_text(stat_key, GameManager.get_part_stat_value(entry)),
	]


# 外すと壊れる（GAME_DESIGN.md 7-6・人間の決定D）。⚠ 取り返しがつかないので確認を出す。
# ⚠ await のあいだに再描画でこの器が消えることがある。⚠ 続きの前に is_instance_valid(self) を見る。
func _on_detach_part_pressed(instance_id: String, slot_index: int) -> void:
	var item_id: String = ""
	for view: Variant in GameManager.get_part_entries(instance_id):
		if int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1)) == slot_index:
			var entry: Variant = (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
			if entry is Dictionary:
				item_id = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
	if item_id == "":
		return
	var confirmed: bool = await Modal.confirm(
		self, "ui_part_break_confirm", [tr("ui_res_" + item_id)], false, {
			Modal.OPTION_TITLE: tr("ui_part_break_title"),
			Modal.OPTION_DANGER: true,
			Modal.OPTION_CONFIRM_LABEL: "ui_common_break",
			Modal.OPTION_STAMP: "ui_stamp_irreversible",
		}
	)
	if not confirmed or not is_instance_valid(self):
		return
	GameManager.detach_part(instance_id, slot_index)


func _on_rune_merge_pressed(item_id: String) -> void:
	GameManager.merge_runes(item_id)


func _on_part_dismantle_pressed(item_id: String) -> void:
	GameManager.dismantle_part(item_id, 1)


func _on_part_upgrade_pressed(item_id: String) -> void:
	var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
	if ItemSourceWindow.open_if_short(self, str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, "")),
			int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0)), {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_PART}):
		return
	GameManager.upgrade_part(item_id)
