# res://scenes/guild/forge_screen.gd
# 鍛冶場（2026-09-27・回UI-仕組み①）。
#
# ⚠⚠ 2026-10-18（回UI-1018-3・web版の手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/mocks/Forge.html`・NOTES §3）：⚠ **作り替えた**。
#   ⚠ 左：鍛える装備をマス目でばーっと（⚠ 行にも切り替え）＝`ItemListBar`（並び・しぼる＝部位・等級・★・着けている物）＋`ItemCollection`。
#   ⚠ 右：鍛冶の腕の札 ／ 選んだ装備の紙（いま → 鍛えたら・成功率・素材・確定成功の札・「鍛える」「失敗しない所まで鍛える（等級◯まで）」）。
#     ⚠ 等級10は「これ以上は鍛えられない」＋「遺物に捧げる ›」（⚠ 前の「どの等級でも捧げる紙」は持ち物の「捧げる」へ任せた）。
#   ⚠ 鍛えると演出（`ForgeStrike`）→ ⚠ **結果の窓**（`ForgeResultWindow`・⚠ 09-28 の紙いっぱいの「結果の画面」はやめた）。
#   ⚠ 一括分解（`EQ-20`）＝見出しの右の「一括分解」。
#   ⚠ 育成から来たときは見出しの添え書きに「◯◯の装備から来た」・戻るは「育成に戻る」。
# ⚠ 鍛冶場のタブ（鍛える ／ 作る ／ 遺物）は `create_tabs()`（⚠ 3画面が同じタブを出す）。
# ⚠ 判定と状態の変更は `GameManager.forge_equipment_roll()` の1本（⚠ ここで成功率や費用を計算しない）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 画面は自分の操作のあとに自分で描き直す。

class_name ForgeScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"
const BELONGINGS_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const FORGE_PATH: String = "res://scenes/guild/forge_screen.tscn"
const THEME_TYPE: StringName = &"Forge"
# ⚠⚠ 鍛冶場のタブ（10-07・見る回22回目・人間「⚠ 鍛冶場の中に遺物のカテゴリを」）：⚠ 鍛える ／ 作る ／ 遺物。
const TAB_FORGE_ID: String = "forge"
const TAB_MAKE_ID: String = "make"
const TAB_RELIC_ID: String = "relic"
const RELIC_PATH: String = "res://scenes/guild/guild_relic_screen.tscn"
const TAB_ENTRY_ID: String = "id"
const TAB_ENTRY_KEY: String = "key"
const TAB_ENTRY_PATH: String = "path"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Body/Main
@onready var sheet_body: HBoxContainer = $Margin/Layout/Body/Main/Sheet/SheetBody
@onready var side: VBoxContainer = $Margin/Layout/Body/Side
@onready var sheet: PaperSheet = $Margin/Layout/Body/Main/Sheet

var _selected: String = ""
var _use_token: bool = false
var _tabs: PaperTabs = null
var _tip: ItemTipCard = null
# ⚠ 育成から来たときのキャラ（⚠ 見出しの添え書き・戻るの字）。
var _from_character: String = ""
# ⚠ 一括分解のあいだか ／ 選んだ個体 ／ いま並べている装備。
var _scrapping: bool = false
var _picked: Array[String] = []
var _shown_views: Array = []


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_source_return_data)
	var data: Dictionary = SceneManager.consume_transfer_data()
	_selected = str(data.get(TransferKeys.FORGE_INSTANCE_ID, ""))
	_from_character = str(data.get(TransferKeys.CHARACTER_ID, ""))
	header.back_pressed.connect(_on_back_pressed)
	if _from_character != "":
		header.back_label_key = "ui_forge_back_training"
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX))
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.FORGE)
	side.custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
	var tabs: PaperTabs = create_tabs(TAB_FORGE_ID)
	main_stack.add_child(tabs)
	main_stack.move_child(tabs, 0)
	_tabs = tabs
	_tip = ItemTipCard.attach(self)
	_rebuild()


# ⚠ 鍛冶場のタブの並び。⚠ 「作る」（作業場）は作業場を解放してから（⚠ 09-28・鍛冶場は持ち物と同じ解放で出る）。
static func tab_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{TAB_ENTRY_ID: TAB_FORGE_ID, TAB_ENTRY_KEY: "ui_forge_tab_forge", TAB_ENTRY_PATH: FORGE_PATH}]
	if GameManager.is_screen_unlocked(GameStateKeys.SCREEN_WORKSHOP):
		list.append({TAB_ENTRY_ID: TAB_MAKE_ID, TAB_ENTRY_KEY: "ui_forge_tab_make", TAB_ENTRY_PATH: WORKSHOP_PATH})
	list.append({TAB_ENTRY_ID: TAB_RELIC_ID, TAB_ENTRY_KEY: "ui_facility_guild_relic", TAB_ENTRY_PATH: RELIC_PATH})
	return list


# ⚠ 鍛冶場のタブを作る（⚠ 押すとその画面へ差し替える）。⚠ 置き場所は使う画面が決める。
# ⚠ 10-07：⚠ 作業場の品が完成していたら「作る」のタブに紐。
static func create_tabs(active_id: String) -> PaperTabs:
	var entries: Array[Dictionary] = tab_entries()
	var keys: Array[String] = []
	var paths: Array[String] = []
	var selected: int = 0
	for i: int in range(entries.size()):
		keys.append(str(entries[i][TAB_ENTRY_KEY]))
		paths.append(str(entries[i][TAB_ENTRY_PATH]))
		if str(entries[i][TAB_ENTRY_ID]) == active_id:
			selected = i
	var tabs: PaperTabs = PaperTabs.new()
	tabs.name = "Tabs"
	tabs.set_tabs(keys, selected)
	tabs.tab_changed.connect(func(index: int) -> void: SceneManager.swap_scene(paths[index]))
	for i: int in range(entries.size()):
		if str(entries[i][TAB_ENTRY_ID]) == TAB_MAKE_ID:
			tabs.set_attention(i, GameManager.has_completed_craft())
	return tabs


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	# ⚠ 10-18：⚠ 一覧で選んでも上へ戻らない（`ScrollKeeper`）。
	var kept: Dictionary = ScrollKeeper.capture(self)
	_clear(sheet_body)
	_clear(side)
	if _tip != null:
		_tip.hide_tip()
	var owned: Array = GameManager.get_owned_instances()
	_shown_views = ItemListBar.apply_views(owned, true)
	if not _scrapping and (_selected == "" or GameManager.get_equipment_instance(_selected).is_empty()):
		_selected = str((_shown_views[0] as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) if not _shown_views.is_empty() else ""
	header.set_subtitle_text(tr("ui_forge_from_character") % tr(str(MasterDataLoader.get_character(_from_character).get("name_key", _from_character))) if _from_character != "" else tr("ui_forge_subtitle"))
	sheet_body.add_child(_build_list(owned.size()))
	_build_side_level()
	if _scrapping:
		var holder: TiltedSheet = TiltedSheet.create(1)
		holder.name = "ScrapSheet"
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var summary: BulkScrapSummary = BulkScrapSummary.create(_picked.duplicate())
		summary.confirm_pressed.connect(_on_scrap_confirm)
		summary.cancel_pressed.connect(_end_scrap)
		holder.sheet.add_child(summary)
		side.add_child(holder)
	else:
		var holder: TiltedSheet = TiltedSheet.create(1)
		holder.name = "ForgeSheet"
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.sheet.add_child(_build_forge_page())
		side.add_child(holder)
	ScrollKeeper.restore(self, kept)


# --- 左：鍛える装備 -----------------------------------------------------

func _build_list(owned_count: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "List"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "ListHead"
	column.add_child(head)
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	heading.title_key = "ui_bulk_scrap_pick" if _scrapping else "ui_forge_list"
	heading.right_text = tr("ui_forge_list_count") % [owned_count, _shown_views.size()]
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var scrap: Button = UiButton.create_paper_choice("ui_common_cancel" if _scrapping else "ui_bulk_scrap_open")
	scrap.name = "ScrapToggle"
	scrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scrap.pressed.connect(_end_scrap if _scrapping else _start_scrap)
	head.add_child(scrap)
	if _scrapping:
		var scrap_bar: BulkScrapBar = BulkScrapBar.create()
		scrap_bar.grade_chosen.connect(_on_scrap_grade_chosen)
		scrap_bar.visible_all_pressed.connect(_on_scrap_visible_all)
		scrap_bar.reset_pressed.connect(_on_scrap_reset)
		column.add_child(scrap_bar)
	var bar: ItemListBar = ItemListBar.create(ItemListBar.KIND_EQUIP, {"equipped": true})
	bar.changed.connect(_on_bar_changed)
	column.add_child(bar)

	var entries: Array = []
	var locked: Dictionary = {}
	var picked: Dictionary = {}
	var tags: Dictionary = {}
	var max_grade: int = GameManager.get_max_equipment_grade()
	for raw: Variant in _shown_views:
		var view: Dictionary = raw
		var entry: Dictionary = ItemView.entry_of_view(view)
		var key: String = ItemView.key_of(entry)
		entries.append(entry)
		if _scrapping:
			if not BulkScrapBar.can_pick(view):
				locked[key] = true
				tags[key] = [tr("ui_item_tag_equipped"), ItemCell.Tag.PLAIN]
			if key in _picked:
				picked[key] = true
		elif int(view.get(GameStateKeys.INSTANCE_GRADE, 1)) >= max_grade:
			tags[key] = [tr("ui_item_tag_max"), ItemCell.Tag.MAX]
	var collection: ItemCollection = ItemCollection.create(ItemListBar.view_of(ItemListBar.KIND_EQUIP))
	collection.tip = _tip
	collection.selected_key = "" if _scrapping else _selected
	collection.locked = locked
	collection.picked = picked
	collection.tags = tags
	collection.empty_key = "ui_equip_filter_hidden" if (owned_count > 0 and ItemListBar.is_filtering(ItemListBar.KIND_EQUIP, true)) else "ui_forge_no_equipment"
	collection.item_pressed.connect(_on_item_pressed)
	collection.set_entries(entries)
	column.add_child(collection)

	var legend: VBoxContainer = VBoxContainer.new()
	legend.name = "Legend"
	legend.add_child(HSeparator.new())
	var line: HBoxContainer = HBoxContainer.new()
	legend.add_child(line)
	var left_label: Label = Label.new()
	left_label.theme_type_variation = &"ErrorLabel" if _scrapping else &"FieldCaptionLabel"
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_label.text = tr("ui_belongings_legend_scrap") if _scrapping else tr("ui_forge_legend")
	line.add_child(left_label)
	if not _scrapping:
		var right_label: Label = Label.new()
		right_label.theme_type_variation = &"FieldCaptionLabel"
		right_label.text = tr("ui_forge_legend_touch")
		line.add_child(right_label)
	column.add_child(legend)
	return column


func _on_item_pressed(instance_id: String) -> void:
	if _scrapping:
		var view: Dictionary = {}
		for raw: Variant in _shown_views:
			if str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
				view = raw
		if view.is_empty() or not BulkScrapBar.can_pick(view):
			return
		if instance_id in _picked:
			_picked.erase(instance_id)
		else:
			_picked.append(instance_id)
		_rebuild()
		return
	if instance_id == _selected:
		return
	_selected = instance_id
	_use_token = false
	_rebuild()


func _on_bar_changed() -> void:
	ScrollKeeper.reset(self)
	_rebuild()


# --- 右：鍛える（いま → 鍛えたら・成功率・素材・札） -----------------------

func _build_forge_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "ForgePage"
	page.theme_type_variation = &"TightList"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _selected == "":
		page.add_child(EmptyState.create("ui_forge_no_equipment", "ui_forge_no_equipment_hint"))
		return page
	var instance: Dictionary = GameManager.get_equipment_instance(_selected)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	var at_max: bool = grade >= GameManager.get_max_equipment_grade()
	var entry: Dictionary = ItemView.instance_entry(_selected)

	# 頭：絵 ／ 名前・添え書き（部位・等級・誰が着けているか）／ 「持ち物で見る」。
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	page.add_child(head)
	var head_icon: ItemCell = ItemCell.create(entry, get_theme_constant(&"head_icon", THEME_TYPE))
	head_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(head_icon)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = tr(GameManager.item_name_key(item_id))
	titles.add_child(name_label)
	var sub: Label = Label.new()
	sub.name = "SubLabel"
	sub.theme_type_variation = &"CaptionLabel"
	sub.text = ItemView.sub_text(entry)
	if ItemView.owner_name(entry) != "":
		sub.text += tr("ui_barracks_skill_separator") + tr("ui_forge_worn_by") % ItemView.owner_name(entry)
	titles.add_child(sub)
	var belongings: Button = UiButton.create_paper_choice("ui_forge_to_belongings")
	belongings.name = "BelongingsButton"
	belongings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	belongings.pressed.connect(_on_belongings_pressed)
	head.add_child(belongings)

	if at_max:
		_build_max_note(page)
		return page

	# いま → 鍛えたら。
	var before: Dictionary = GameManager.get_instance_stats(_selected)
	var after: Dictionary = GameManager.get_instance_stats_at_grade(_selected, grade + 1)
	var stat_key: String = BelongingsDetail.main_stat_of(before)
	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.name = "ArrowRow"
	arrow_row.theme_type_variation = &"ForgeArrowRow"
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(arrow_row)
	arrow_row.add_child(_cell_with_caption(item_id, grade, tr("ui_forge_now_caption"), _stat_text(stat_key, before), &""))
	arrow_row.add_child(_arrow())
	arrow_row.add_child(_cell_with_caption(item_id, grade + 1, tr("ui_forge_after_caption"), _stat_text(stat_key, after), &"GainLabel"))

	# 成功率（⚠ 必ず成功する段は緑、⚠ 失敗しうる段は強調・⚠ 札を使うなら緑）。
	var pct: int = GameManager.get_forge_success_pct(_selected)
	var chance_row: HBoxContainer = HBoxContainer.new()
	chance_row.name = "ChanceRow"
	page.add_child(chance_row)
	var chance: Label = Label.new()
	chance.name = "ChanceLabel"
	chance.theme_type_variation = &"GainLabel" if (pct >= 100 or _use_token) else &"AccentLabel"
	chance.text = tr("ui_forge_chance") % (100 if _use_token else pct)
	chance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chance_row.add_child(chance)
	var note: Label = Label.new()
	note.name = "NoteLabel"
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.text = tr("ui_forge_note_safe") % GameManager.get_forge_safe_limit(_selected) if pct >= 100 else tr("ui_forge_note")
	chance_row.add_child(note)

	# 素材（⚠ 等級ごとに1種類）。
	var cost: Dictionary = GameManager.get_forge_cost(_selected)
	var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	var cost_row: LedgerRow = LedgerRow.new()
	cost_row.name = "CostRow"
	cost_row.compact = true
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	cost_row.add_child(line)
	var cost_icon: ItemIcon = ItemIcon.create(material_id)
	cost_icon.name = "CostIcon"
	# ⚠ 10-07：⚠ アイコンを押しても入手先の窓。
	ItemSourceWindow.attach_to(cost_icon, material_id, amount)
	line.add_child(cost_icon)
	var material_name: Label = Label.new()
	material_name.text = tr("ui_res_" + material_id)
	material_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	material_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(material_name)
	var need: Label = Label.new()
	need.name = "NeedLabel"
	need.theme_type_variation = &"" if owned >= amount else &"ErrorLabel"
	need.text = tr("ui_forge_need") % [amount, owned]
	need.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(need)
	page.add_child(cost_row)

	# 確定成功の札（`EQ-7`）。⚠ 必ず成功する段・札が無いときは押せない。⚠ 紙の上の入り切り（`PaperToggle`）。
	var tokens: int = GameManager.get_forge_token_count()
	var token_row: HBoxContainer = HBoxContainer.new()
	token_row.name = "TokenRow"
	var check: Button = Button.new()
	check.name = "TokenCheck"
	check.theme_type_variation = &"PaperToggle"
	check.toggle_mode = true
	check.focus_mode = Control.FOCUS_NONE
	check.text = tr("ui_forge_use_token_on") if _use_token else tr("ui_forge_use_token")
	check.button_pressed = _use_token
	check.disabled = tokens <= 0 or pct >= 100
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(_on_token_toggled.bind(not _use_token))
	token_row.add_child(check)
	var left: Label = Label.new()
	left.theme_type_variation = &"CaptionLabel"
	left.text = tr("ui_forge_token_left") % tokens
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	token_row.add_child(left)
	page.add_child(token_row)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)
	var forge: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_forge_do")
	forge.name = "ForgeButton"
	# ⚠ 10-07（`NAV-19`）：⚠ 足りなくても押せる＝押すと入手先の窓。
	forge.pressed.connect(_on_forge_pressed)
	page.add_child(forge)
	# ⚠ 10-14（操作量を減らす D）：⚠ 失敗しない所まで まとめて鍛える（⚠ 失敗がある段からは1回ずつ）。
	var forge_max: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "")
	forge_max.name = "ForgeSafeButton"
	forge_max.text = tr("ui_forge_do_safe_to") % GameManager.get_forge_safe_limit(_selected)
	forge_max.disabled = _use_token or not _can_forge_safely()
	forge_max.pressed.connect(_on_forge_safe_pressed)
	page.add_child(forge_max)
	return page


# ⚠ 等級10（⚠ 手本 `03_forge_max.png`）：⚠ これ以上は鍛えられない ／ 遺物に捧げると育つ ／ 「遺物に捧げる ›」。
func _build_max_note(page: VBoxContainer) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)
	var title: Label = Label.new()
	title.name = "MaxLabel"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr("ui_forge_max_title") % GameManager.get_max_equipment_grade()
	page.add_child(title)
	var offer: Dictionary = GameManager.get_offer_preview(_selected)
	if not offer.is_empty():
		var hint: Label = Label.new()
		hint.name = "OfferText"
		hint.theme_type_variation = &"CaptionLabel"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = tr("ui_forge_max_offer_hint") % tr(str(MasterDataLoader.get_guild_relic(str(offer[GameManager.OFFER_RELIC_ID])).get("name_key", "")))
		page.add_child(hint)
		var equipped: bool = GameManager.get_equipped_owner(_selected) != ""
		if equipped:
			var reason: Label = Label.new()
			reason.name = "OfferReason"
			reason.theme_type_variation = &"CaptionLabel"
			reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			reason.text = tr("ui_forge_offer_equipped")
			page.add_child(reason)
		var button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_forge_offer_go")
		button.name = "ForgeOfferButton"
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.disabled = equipped
		button.pressed.connect(_on_offer_pressed)
		page.add_child(button)
	var bottom: Control = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(bottom)


# ⚠ 失敗しない（成功 100%）で、⚠ 素材が足りる。
func _can_forge_safely() -> bool:
	var grade: int = int(GameManager.get_equipment_instance(_selected).get(GameStateKeys.INSTANCE_GRADE, 1))
	return grade < GameManager.get_max_equipment_grade() and GameManager.get_forge_success_pct(_selected) >= 100 and GameManager.can_forge(_selected)


# ⚠ まとめて鍛える。⚠ 結果の窓は1枚（⚠ 前の値は1回目の前・あとの値は最後）。⚠ 演出も1回。
func _on_forge_safe_pressed() -> void:
	if not _can_forge_safely():
		return
	var stats_before: Dictionary = GameManager.get_instance_stats(_selected)
	var first: Dictionary = {}
	var last: Dictionary = {}
	var steps: int = 0
	while _can_forge_safely():
		var roll: Dictionary = GameManager.forge_equipment_roll(_selected, false)
		if not bool(roll.get(GameManager.FORGE_RESULT_OK, false)):
			break
		steps += 1
		if first.is_empty():
			first = roll
		last = roll
	if last.is_empty():
		_rebuild()
		return
	var result: Dictionary = last.duplicate()
	result[GameManager.FORGE_RESULT_GRADE_BEFORE] = first.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1)
	result[ForgeResultWindow.RESULT_STATS_BEFORE] = stats_before
	result[ForgeResultWindow.RESULT_STEPS] = steps
	var item_id: String = str(GameManager.get_equipment_instance(_selected).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var strike: ForgeStrike = ForgeStrike.play(self, item_id, int(result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1)), true)
	strike.finished.connect(_show_result.bind(result))


func _on_token_toggled(pressed: bool) -> void:
	_use_token = pressed
	_rebuild()


# 鍛える。⚠ 判定と乱数は `forge_equipment_roll()`。⚠ 前の値を控えてから呼ぶ（⚠ 結果の窓に出す）。
func _on_forge_pressed() -> void:
	var cost: Dictionary = GameManager.get_forge_cost(_selected)
	if ItemSourceWindow.open_if_short(self, str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, "")),
			int(cost.get(GameManager.FORGE_COST_AMOUNT, 0)), {TransferKeys.FORGE_INSTANCE_ID: _selected}):
		return
	var stats_before: Dictionary = GameManager.get_instance_stats(_selected)
	var result: Dictionary = GameManager.forge_equipment_roll(_selected, _use_token)
	if not bool(result.get(GameManager.FORGE_RESULT_OK, false)):
		push_warning("[ForgeScreen] 鍛えられなかった: " + str(result.get(GameManager.FORGE_RESULT_REASON, "")))
		_rebuild()
		return
	result[ForgeResultWindow.RESULT_STATS_BEFORE] = stats_before
	_use_token = false
	# ⚠ 鍛える演出を被せ、⚠ 終わってから結果の窓（⚠ 状態はもう変わっている＝演出は見せるだけ）。
	var item_id: String = str(GameManager.get_equipment_instance(_selected).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var strike: ForgeStrike = ForgeStrike.play(self, item_id, int(result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1)),
		bool(result.get(GameManager.FORGE_RESULT_SUCCESS, false)))
	strike.finished.connect(_show_result.bind(result))


func _show_result(result: Dictionary) -> void:
	if not is_inside_tree():
		return
	_rebuild()
	var window: ForgeResultWindow = ForgeResultWindow.open(self, _selected, result)
	# ⚠ 「続けて鍛える」＝その場でもう一度（⚠ 09-28 人間「⚠ 続けて鍛えるで元の画面に戻らないで」・札は使わない）。
	window.again_pressed.connect(_on_forge_pressed)


# --- 一括分解（`EQ-20`） ---

func _start_scrap() -> void:
	_scrapping = true
	_picked.clear()
	_rebuild()


func _end_scrap() -> void:
	_scrapping = false
	_picked.clear()
	_rebuild()


func _on_scrap_grade_chosen(max_grade: int) -> void:
	_picked = BulkScrapBar.pick_by_grade(_shown_views, max_grade)
	_rebuild()


func _on_scrap_visible_all() -> void:
	_picked = BulkScrapBar.pick_visible(_shown_views)
	_rebuild()


func _on_scrap_reset() -> void:
	_picked.clear()
	_rebuild()


func _on_scrap_confirm() -> void:
	var ids: Array[String] = _picked.duplicate()
	if not await BulkScrapSummary.run(self, ids):
		return
	if not is_instance_valid(self):
		return
	_scrapping = false
	_picked.clear()
	_rebuild()


# --- 右の列：鍛冶の腕 ----------------------------------------------------

# ⚠⚠ 鍛冶のレベル（10-09・回SYS-2・`EQ-5`）。⚠ Lv ／ 次まで ／ いまの補正（⚠ 全員・0 の軸は出さない）。
#   ⚠ 値は `GameManager.get_forge_*` から毎回（⚠ この画面で計算しない）。
func _build_side_level() -> void:
	var holder: TiltedSheet = TiltedSheet.create(0)
	holder.name = "ForgeLevelSheet"
	var line: HBoxContainer = HBoxContainer.new()
	holder.sheet.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_forge_level_title")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var level: Label = Label.new()
	level.name = "ForgeLevelLabel"
	level.theme_type_variation = &"DossierLevelLabel"
	level.text = tr("ui_forge_level_value") % GameManager.get_forge_level()
	line.add_child(level)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var next: Label = Label.new()
	next.name = "ForgeLevelNext"
	next.theme_type_variation = &"CaptionLabel"
	var to_next: int = GameManager.get_forge_exp_to_next()
	next.text = tr("ui_forge_level_next") % to_next if to_next > 0 else tr("ui_forge_level_max")
	column.add_child(next)
	var bonus: Dictionary = GameManager.get_forge_level_bonus()
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		if int(bonus.get(stat_key, 0)) != 0:
			parts.append(_stat_text(stat_key, bonus))
	var effect: Label = Label.new()
	effect.name = "ForgeLevelBonus"
	effect.theme_type_variation = &"CaptionLabel"
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.text = tr("ui_forge_level_bonus") % "  ".join(parts) if not parts.is_empty() else tr("ui_forge_level_bonus_none")
	column.add_child(effect)
	side.add_child(holder)


func _on_offer_pressed() -> void:
	var instance_id: String = _selected
	var item_id: String = str(GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var ok: bool = await Modal.confirm(self, "ui_grelic_offer_confirm", [tr(GameManager.item_name_key(item_id))], false, {
		Modal.OPTION_TITLE: tr("ui_grelic_offer"),
	})
	if not ok:
		return
	var offer: Dictionary = GameManager.get_offer_preview(instance_id)
	if GameManager.dismantle_equipment(instance_id):
		_selected = ""
		_rebuild()
		GuildRelicScreen.notify_offered(self, offer)


# ⚠ 10-06（`NAV-18`）：⚠ 寄り道＝持ち物の「戻る」でこの品を選んだ鍛冶場へ。
func _on_belongings_pressed() -> void:
	SceneManager.open_detour(BELONGINGS_PATH, {TransferKeys.WAREHOUSE_INSTANCE_ID: _selected},
		FORGE_PATH, {TransferKeys.FORGE_INSTANCE_ID: _selected, TransferKeys.CHARACTER_ID: _from_character})


func _on_back_pressed() -> void:
	var window: Node = get_node_or_null("ForgeResultWindow")
	if window is ForgeResultWindow:
		(window as ForgeResultWindow).close()
		return
	# ⚠ 10-06（`NAV-18`）：⚠ 育成・持ち物から寄り道で来たなら、そこへ戻る。
	SceneManager.go_back_or(BASE_PATH)


# --- 小さい道具 ----------------------------------------------------------

func _arrow() -> Label:
	var arrow: Label = Label.new()
	arrow.theme_type_variation = &"LevelArrowLabel"
	arrow.text = tr("ui_forge_arrow")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return arrow


# マス（⚠ 等級つき）＋ 下の2行（いま／鍛えたら ・値）。
func _cell_with_caption(item_id: String, grade: int, caption: String, value: String, variation: StringName) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var cell: ItemCell = ItemCell.create({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: item_id,
		GameManager.SLOT_ENTRY_INSTANCE_ID: _selected,
		GameManager.SLOT_ENTRY_GRADE: grade,
	}, Balance.icon.icon_size_px if Balance.icon != null else 40)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cell)
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = caption
	column.add_child(label)
	var value_label: Label = Label.new()
	# ⚠ 右の紙は狭い（⚠ 大きい字だと下の「鍛える」が紙から出た＝10-18 の絵）。
	value_label.theme_type_variation = variation
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.text = value
	column.add_child(value_label)
	return column


# 「攻撃 +14」。
func _stat_text(stat_key: String, stats: Dictionary) -> String:
	if stat_key == "":
		return ""
	return "%s %s" % [tr("ui_training_stat_" + stat_key), BelongingsDetail.stat_text(stat_key, int(stats.get(stat_key, 0)))]


# 入手先の窓から戻ってきたときの姿（⚠ 同じ品を選んだ鍛冶場）。
func _source_return_data() -> Dictionary:
	return {TransferKeys.FORGE_INSTANCE_ID: _selected, TransferKeys.CHARACTER_ID: _from_character}
