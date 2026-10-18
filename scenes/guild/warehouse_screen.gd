# res://scenes/guild/warehouse_screen.gd
# 持ち物（⚠ ファイル名は前の「倉庫」のまま＝決定 `BS-15`「画面は増やさず、いまの倉庫画面を作り替える」）。
#
# ⚠⚠ 2026-10-18（回UI-1018-2・web版の手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/mocks/Belongings.html`・NOTES §6）：⚠ **作り替えた**。
#   ⚠ 左：紙のタブ（装備・装飾・素材＝数つき）／ 並べ替えの欄（`ItemListBar`・⚠ 全タブでマス目｜行）／ 品の並び（`ItemCollection`）／ 凡例。
#   ⚠ 右：説明の紙（`BelongingsDetail`）＝ ⚠ 押した品を詳しく。⚠ 一括分解のあいだは `BulkScrapSummary`。
#   ⚠ 部位の縦タブはやめた（⚠ 欄の「しぼる」へ）。⚠ 触れると出る札（`ItemTipCard`）。
#   ⚠ 前の作り（09-27・回UI-組 持ち物）の決まりは残す：⚠ マス目・ページ・容量の字は出さない（`BS-10`）／ ⚠ 図鑑は記録の画面。
# ⚠ 何が何個あるかは全部 `GameManager` の口（⚠ 装備＝`get_owned_instances()` ／ 持ち物＝`get_inventory_slot_entries()` ／
#   ⚠ 素材＝`get_material_slot_entries()`）。⚠ ここで数え直さない。⚠ 並べ替えと絞り込みは `ItemListBar` の1か所。
# ⚠ 刺すのは2通り：⚠ 装備の空き枠を押す → 刺せる装飾を並べる（`_attach_instance`）／ ⚠ 装飾の「装備に刺す…」→ 空き枠のある装備を並べる（`_attach_part_id`）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ remove_child してから queue_free。

class_name WarehouseScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"Belongings"

# ⚠ タブの並び。⚠ 外から開くときは `TransferKeys.WAREHOUSE_TAB_*` の字で指す（⚠ 番号を漏らさない）。
const TAB_IDS: Array[String] = [
	TransferKeys.WAREHOUSE_TAB_EQUIP, TransferKeys.WAREHOUSE_TAB_PART,
	TransferKeys.WAREHOUSE_TAB_MATERIAL,
]
const TAB_KEYS: Array[String] = [
	"ui_belongings_tab_equip", "ui_belongings_tab_part", "ui_belongings_tab_material",
]

var _tab: String = TransferKeys.WAREHOUSE_TAB_EQUIP
# ⚠ いま選んでいる品の鍵（⚠ 個体なら instance_id・それ以外は item_id）。
var _selected_key: String = ""
# ⚠ 刺せる装飾を並べているあいだの相手（⚠ 空なら並べていない）。⚠ 状態ではなく画面の都合。
var _attach_instance: String = ""
var _attach_slot: int = -1
# ⚠ 「装備に刺す…」で、⚠ 刺す先の装備を並べているあいだの装飾（⚠ 空なら並べていない）。
var _attach_part_id: String = ""
# ⚠ 一括分解のあいだか ／ 選んだ個体。
var _scrapping: bool = false
var _picked: Array[String] = []
# ⚠ 装飾を合わせるあいだか ／ 選んだ材料（⚠ item_id の並び・同じ物を重ねてよい）／ 作るもの（10-18・`BS-23`）。
var _merging: bool = false
var _merge_picks: Array[String] = []
var _merge_target: String = ""

var tabs: PaperTabs = null
var _page: VBoxContainer = null
var _detail: BelongingsDetail = null
var _detail_holder: TiltedSheet = null
var _summary: Control = null
var _tip: ItemTipCard = null
# ⚠ いま並べている装備（⚠ 「見えている物ぜんぶ」「等級◯以下」が見る）。
var _shown_views: Array = []

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body
@onready var left: VBoxContainer = $Margin/Layout/Body/Left


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_source_return_data)
	var data: Dictionary = SceneManager.consume_transfer_data()
	# ⚠ 10-07（H）：⚠ 渡されなければ前に開いていたタブ。
	var wanted_tab: String = str(data.get(TransferKeys.WAREHOUSE_TAB, SceneManager.recall(TransferKeys.MEMORY_WAREHOUSE_TAB, TransferKeys.WAREHOUSE_TAB_EQUIP)))
	_tab = wanted_tab if wanted_tab in TAB_IDS else TransferKeys.WAREHOUSE_TAB_EQUIP
	var wanted_instance: String = str(data.get(TransferKeys.WAREHOUSE_INSTANCE_ID, ""))
	if wanted_instance != "":
		_tab = TransferKeys.WAREHOUSE_TAB_EQUIP
		_selected_key = wanted_instance

	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.BELONGINGS)

	tabs = PaperTabs.new()
	tabs.name = "Tabs"
	tabs.tab_changed.connect(_on_tab_changed)
	left.add_child(tabs)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Page"
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sheet)
	_page = VBoxContainer.new()
	_page.name = "PageBody"
	sheet.add_child(_page)

	_detail_holder = TiltedSheet.create(1)
	_detail_holder.name = "DetailHolder"
	_detail_holder.sheet.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	_detail = BelongingsDetail.new()
	_detail.name = "Detail"
	_detail.host = self
	_detail.attach_requested.connect(_on_attach_requested)
	_detail.attach_part_requested.connect(_on_attach_part_requested)
	_detail.merge_requested.connect(_on_merge_requested)
	_detail_holder.sheet.add_child(_detail)
	body.add_child(_detail_holder)
	_tip = ItemTipCard.attach(self)

	# ⚠ 1操作で2本飛ぶことがある（⚠ 分解＝素材と個体）。⚠ 再描画に await を持たせない（AGENTS.md）。
	GameManager.inventory_changed.connect(_on_state_changed.unbind(1))
	GameManager.equipment_instances_changed.connect(_on_state_changed.unbind(1))
	GameManager.material_changed.connect(_on_state_changed.unbind(2))
	GameManager.character_growth_changed.connect(_on_state_changed.unbind(1))
	_rebuild()


# --- 描き直し ---

func _rebuild() -> void:
	# ⚠ 10-18（人間「⚠ スクロールのあるもので項目を選んだら　スクロールを上に戻される」）：⚠ 描き直しの前の位置へ戻す。
	var kept: Dictionary = ScrollKeeper.capture(self)
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	if _tip != null:
		_tip.hide_tip()
	_refresh_tabs()
	header.set_subtitle_text(tr(TAB_KEYS[TAB_IDS.find(_tab)]))

	var entries: Array = _entries()
	# ⚠ 選んでいたものが無くなっていることがある（壊した・分解した）。⚠ そのときは先頭を選ぶ。
	var selected: Dictionary = {}
	for entry: Variant in entries:
		if ItemView.key_of(entry as Dictionary) == _selected_key:
			selected = entry
	if selected.is_empty() and not _in_pick_mode() and not entries.is_empty():
		selected = entries[0]
		_selected_key = ItemView.key_of(selected)
	# ⚠ 10-07：⚠ 「見た」にするのは右の紙に出した品だけ（⚠ 紐が一気に消えないように）。
	if not selected.is_empty() and not _in_pick_mode():
		GameManager.mark_items_seen([ItemView.item_id_of(selected)])

	if _scrapping:
		var scrap: BulkScrapBar = BulkScrapBar.create()
		scrap.grade_chosen.connect(_on_scrap_grade_chosen)
		scrap.visible_all_pressed.connect(_on_scrap_visible_all)
		scrap.reset_pressed.connect(_on_scrap_reset)
		_page.add_child(scrap)
	if _attach_instance != "" or _attach_part_id != "" or _merging:
		_page.add_child(_build_attach_heading())
	_page.add_child(_build_list_bar())

	var collection: ItemCollection = ItemCollection.create(ItemListBar.view_of(_bar_kind()))
	collection.tip = _tip
	collection.selected_key = "" if _in_pick_mode() else _selected_key
	collection.empty_key = _empty_key()
	_mark_collection(collection, entries)
	collection.item_pressed.connect(_on_item_pressed)
	collection.set_entries(entries)
	_page.add_child(collection)
	_page.add_child(_build_legend())

	var facility: Node = get_node_or_null("FacilityBar")
	if facility is BaseFacilityBar:
		(facility as BaseFacilityBar).refresh_attention()

	# 右：⚠ 一括分解のあいだは選んだ物の見積もり ／ ⚠ 刺す相手を並べているあいだも、⚠ 右の紙は刺す元のまま。
	if _summary != null:
		_detail_holder.sheet.remove_child(_summary)
		_summary.queue_free()
		_summary = null
	_detail.visible = not (_scrapping or _merging)
	if _scrapping:
		var scrap_summary: BulkScrapSummary = BulkScrapSummary.create(_picked.duplicate())
		scrap_summary.confirm_pressed.connect(_on_scrap_confirm)
		scrap_summary.cancel_pressed.connect(_end_scrap)
		_summary = scrap_summary
		_detail_holder.sheet.add_child(_summary)
	elif _merging:
		var merge_panel: PartMergePanel = PartMergePanel.create(_merge_picks.duplicate(), _merge_target)
		merge_panel.pick_removed.connect(_on_merge_pick_removed)
		merge_panel.target_chosen.connect(_on_merge_target_chosen)
		merge_panel.confirm_pressed.connect(_on_merge_confirm)
		merge_panel.cancel_pressed.connect(_end_merge)
		_summary = merge_panel
		_detail_holder.sheet.add_child(_summary)
	elif _attach_instance != "":
		_detail.setup(ItemView.instance_entry(_attach_instance), false)
	elif _attach_part_id != "":
		_detail.setup(_part_entry(_attach_part_id), true)
	else:
		_detail.setup(selected, false)
	ScrollKeeper.restore(self, kept)


func _in_pick_mode() -> bool:
	return _scrapping or _merging or _attach_instance != "" or _attach_part_id != ""


# ⚠ いま並べるもの（⚠ マスの形）。
func _entries() -> Array:
	_shown_views = []
	if _attach_instance != "":
		return _attachable_part_entries()
	match _tab:
		TransferKeys.WAREHOUSE_TAB_PART:
			if _attach_part_id != "":
				return _equip_entries()
			return ItemListBar.apply_entries(_part_entries(), ItemListBar.KIND_PART)
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			return ItemListBar.apply_entries(_material_entries(), ItemListBar.KIND_MATERIAL)
	return _equip_entries()


func _bar_kind() -> String:
	if _attach_instance != "":
		return ItemListBar.KIND_PART
	match _tab:
		TransferKeys.WAREHOUSE_TAB_PART:
			return ItemListBar.KIND_EQUIP if _attach_part_id != "" else ItemListBar.KIND_PART
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			return ItemListBar.KIND_MATERIAL
	return ItemListBar.KIND_EQUIP


func _equip_entries() -> Array:
	_shown_views = ItemListBar.apply_views(GameManager.get_owned_instances())
	var entries: Array = []
	for view: Variant in _shown_views:
		entries.append(ItemView.entry_of_view(view as Dictionary))
	return entries


func _part_entries() -> Array:
	var entries: Array = []
	for raw: Variant in GameManager.get_inventory_slot_entries():
		var entry: Dictionary = raw
		if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) != GameManager.SLOT_KIND_ITEM:
			continue
		if GameManager.get_part_definition(ItemView.item_id_of(entry)).is_empty():
			continue
		entries.append(entry)
	return entries


# ⚠ 素材（⚠ 持っていない素材も薄く並ぶ）＋ ⚠ 持ち物のマスを使うその他の品（消耗品など）。
func _material_entries() -> Array:
	var entries: Array = []
	for raw: Variant in GameManager.get_material_slot_entries():
		entries.append(raw)
	for raw: Variant in GameManager.get_inventory_slot_entries():
		var entry: Dictionary = raw
		if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) != GameManager.SLOT_KIND_ITEM:
			continue
		if not GameManager.get_part_definition(ItemView.item_id_of(entry)).is_empty():
			continue
		entries.append(entry)
	return entries


# 刺せる装飾だけ（⚠ 判定は `get_part_reject_reason()` の1本。⚠ 刺さらない種類・解放されていない種類は並べない）。
func _attachable_part_entries() -> Array:
	var entries: Array = []
	for entry: Variant in ItemListBar.apply_entries(_part_entries(), ItemListBar.KIND_PART):
		var item_id: String = ItemView.item_id_of(entry as Dictionary)
		if GameManager.get_part_reject_reason(_attach_instance, _attach_slot, item_id) == GameManager.PART_REJECT_KIND:
			continue
		var definition: Dictionary = GameManager.get_part_definition(item_id)
		if not GameManager.is_part_kind_unlocked(str(definition.get(GameManager.ITEM_MASTER_PART_KIND, ""))):
			continue
		entries.append(entry)
	return entries


func _part_entry(item_id: String) -> Dictionary:
	for entry: Variant in _part_entries():
		if ItemView.item_id_of(entry as Dictionary) == item_id:
			return entry
	return {}


# ⚠ その装備のうち、⚠ この装飾が刺さる最初の空き枠（⚠ 無ければ -1）。⚠ 判定は `get_part_reject_reason()`。
func _open_slot_for(instance_id: String, part_id: String) -> int:
	for view: Variant in GameManager.get_part_entries(instance_id):
		if (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null) is Dictionary:
			continue
		var index: int = int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1))
		if GameManager.get_part_reject_reason(instance_id, index, part_id) == "":
			return index
	return -1


# ⚠ マスの印（⚠ 選べない・分解で選んだ・札）。⚠ 決めるのはここ（⚠ 部品は描くだけ）。
func _mark_collection(collection: ItemCollection, entries: Array) -> void:
	var locked: Dictionary = {}
	var picked: Dictionary = {}
	var tags: Dictionary = {}
	for raw: Variant in entries:
		var entry: Dictionary = raw
		var key: String = ItemView.key_of(entry)
		if _scrapping and ItemView.is_instance(entry):
			if ItemView.owner_name(entry) != "":
				locked[key] = true
				tags[key] = [tr("ui_item_tag_equipped"), ItemCell.Tag.PLAIN]
			if key in _picked:
				picked[key] = true
		elif _attach_part_id != "" and ItemView.is_instance(entry):
			if _open_slot_for(key, _attach_part_id) < 0:
				locked[key] = true
		elif _merging:
			# ⚠ 材料になれない物・段が違う物・もう全部選んだ物は暗く。⚠ 選んだ数は札に。
			var chosen: int = _merge_picks.count(key)
			if not _can_add_merge_pick(key, entry):
				locked[key] = true
			if chosen > 0:
				picked[key] = true
				tags[key] = [tr("ui_part_merge_tag") % chosen, ItemCell.Tag.PLAIN]
		elif _tab == TransferKeys.WAREHOUSE_TAB_MATERIAL and ItemView.count_of(entry) == 0:
			locked[key] = true
	collection.locked = locked
	collection.picked = picked
	collection.tags = tags


func _empty_key() -> String:
	if _attach_instance != "":
		return "ui_part_none_hint"
	if _bar_kind() == ItemListBar.KIND_EQUIP and ItemListBar.is_filtering(ItemListBar.KIND_EQUIP):
		return "ui_equip_filter_hidden"
	return "ui_warehouse_empty"


func _build_list_bar() -> ItemListBar:
	var kind: String = _bar_kind()
	var bar: ItemListBar = ItemListBar.create(kind)
	# ⚠ 一括分解（⚠ 装備タブだけ・⚠ 手本 NOTES §6）。⚠ 分解しているあいだは「やめる」。
	if _tab == TransferKeys.WAREHOUSE_TAB_EQUIP and _attach_instance == "":
		var scrap: Button = Button.new()
		scrap.name = "ScrapToggle"
		scrap.theme_type_variation = &"PaperToggle"
		scrap.focus_mode = Control.FOCUS_NONE
		scrap.text = tr("ui_common_cancel") if _scrapping else tr("ui_bulk_scrap_open")
		scrap.pressed.connect(_end_scrap if _scrapping else _start_scrap)
		bar.trailing = scrap
	bar.changed.connect(_on_bar_changed)
	return bar


# ⚠ 刺す相手を並べているあいだの見出し（⚠ 「やめる」で戻る）。
func _build_attach_heading() -> Control:
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	if _merging:
		heading.title_text = tr("ui_part_merge_heading") % GameManager.get_part_merge_count()
	elif _attach_instance != "":
		heading.title_text = tr("ui_belongings_attach_heading") % (_attach_slot + 1)
	else:
		heading.title_text = tr("ui_belongings_attach_to_heading") % ItemView.name_text(_part_entry(_attach_part_id))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "AttachHead"
	row.add_child(heading)
	var cancel: Button = UiButton.create_paper_choice("ui_common_cancel")
	cancel.name = "AttachCancel"
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_end_merge if _merging else _end_attach)
	row.add_child(cancel)
	return row


# 凡例（⚠ 手本の紙の下の1行）。
func _build_legend() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Legend"
	column.add_child(HSeparator.new())
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var left_label: Label = Label.new()
	left_label.theme_type_variation = &"ErrorLabel" if _scrapping else &"FieldCaptionLabel"
	left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_label: Label = Label.new()
	right_label.theme_type_variation = &"FieldCaptionLabel"
	if _scrapping:
		left_label.text = tr("ui_belongings_legend_scrap")
	elif _bar_kind() == ItemListBar.KIND_EQUIP:
		left_label.text = tr("ui_belongings_legend_equip")
		right_label.text = tr("ui_belongings_legend_touch")
	else:
		left_label.text = tr("ui_belongings_legend_stack")
		right_label.text = tr("ui_belongings_legend_press")
	row.add_child(left_label)
	row.add_child(right_label)
	return column


# ⚠ タブの字（⚠ 「装備 35」）と NEW の紐。
func _refresh_tabs() -> void:
	var labels: Array[String] = []
	for i: int in range(TAB_IDS.size()):
		labels.append("%s %d" % [tr(TAB_KEYS[i]), _tab_count(TAB_IDS[i])])
	tabs.set_tabs(labels, TAB_IDS.find(_tab))
	# ⚠ 10-07：⚠ NEW の品があるタブに紐（⚠ いま見ているタブは「見た」になったので消える）。
	for index: int in range(TAB_IDS.size()):
		tabs.set_attention(index, _tab_has_new(TAB_IDS[index]))


func _tab_count(tab_id: String) -> int:
	match tab_id:
		TransferKeys.WAREHOUSE_TAB_PART:
			return _part_entries().size()
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			var owned: int = 0
			for entry: Variant in _material_entries():
				if ItemView.count_of(entry as Dictionary) != 0:
					owned += 1
			return owned
	return GameManager.get_owned_instances().size()


# ⚠ そのタブに NEW の品があるか（⚠ 装備は絞り込みを見ない）。
func _tab_has_new(tab_id: String) -> bool:
	var entries: Array = []
	match tab_id:
		TransferKeys.WAREHOUSE_TAB_PART:
			entries = _part_entries()
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			entries = _material_entries()
		_:
			for view: Variant in GameManager.get_owned_instances():
				entries.append(ItemView.entry_of_view(view as Dictionary))
	for entry: Variant in entries:
		if GameManager.is_item_new(ItemView.item_id_of(entry as Dictionary)):
			return true
	return false


# --- 操作 ---

func _on_tab_changed(index: int) -> void:
	_tab = TAB_IDS[index]
	SceneManager.remember(TransferKeys.MEMORY_WAREHOUSE_TAB, _tab)
	_selected_key = ""
	_attach_instance = ""
	_attach_slot = -1
	_attach_part_id = ""
	_scrapping = false
	_picked.clear()
	_merging = false
	_merge_picks.clear()
	_merge_target = ""
	ScrollKeeper.reset(self)
	_rebuild()


func _on_bar_changed() -> void:
	ScrollKeeper.reset(self)
	_rebuild()


func _on_item_pressed(key: String) -> void:
	# ⚠ 合わせる：⚠ 押すと材料に1つ足す（⚠ 段が違う・持っている数を超える・もう足りている は足さない）。
	if _merging:
		if _can_add_merge_pick(key, _part_entry(key)):
			_merge_picks.append(key)
			_rebuild()
		return
	# ⚠ 一括分解：⚠ 押すと選ぶ／外す（⚠ 着けている物は選べない）。
	if _scrapping:
		var view: Dictionary = {}
		for raw: Variant in _shown_views:
			if str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == key:
				view = raw
		if view.is_empty() or not BulkScrapBar.can_pick(view):
			return
		if key in _picked:
			_picked.erase(key)
		else:
			_picked.append(key)
		_rebuild()
		return
	# ⚠ 刺せる装飾を並べているあいだは、⚠ 押した装飾をそのまま刺す（⚠ 2手目）。
	if _attach_instance != "":
		var target: String = _attach_instance
		var slot_index: int = _attach_slot
		_attach_instance = ""
		_attach_slot = -1
		# ⚠ 描き直しはシグナル側（⚠ 刺すと個体と持ち物の2本が飛ぶ）。
		if not GameManager.attach_part(target, slot_index, key):
			_rebuild()
		return
	# ⚠ 「装備に刺す…」：⚠ 押した装備の最初の空き枠へ（⚠ 刺さらない装備は押しても何もしない）。
	if _attach_part_id != "":
		var slot: int = _open_slot_for(key, _attach_part_id)
		if slot < 0:
			return
		var part_id: String = _attach_part_id
		_attach_part_id = ""
		_selected_key = part_id
		if not GameManager.attach_part(key, slot, part_id):
			_rebuild()
		return
	if key == _selected_key:
		return
	_selected_key = key
	_rebuild()


# ⚠ 装備の空き枠か「刺す」から（⚠ 刺す相手の装備は選んだまま）。
func _on_attach_requested(instance_id: String, slot_index: int) -> void:
	_attach_instance = instance_id
	_attach_slot = slot_index
	ScrollKeeper.reset(self)
	_rebuild()


# ⚠ 装飾の「装備に刺す…」から。⚠ 装備を並べる（⚠ タブは装飾のまま＝やめると装飾へ戻る）。
func _on_attach_part_requested(item_id: String) -> void:
	_attach_part_id = item_id
	ScrollKeeper.reset(self)
	_rebuild()


func _end_attach() -> void:
	_attach_instance = ""
	_attach_slot = -1
	_attach_part_id = ""
	_rebuild()


# --- 装飾を合わせる（`BS-23`） ---

# ⚠ 材料に足せるか（⚠ 材料になれる・段がそろう・持っている数を超えない・まだ足りていない）。⚠ 決めるのは `GameManager` の材料の口と、ここの数え。
func _can_add_merge_pick(item_id: String, entry: Dictionary) -> bool:
	if entry.is_empty() or not GameManager.can_be_merge_input(item_id):
		return false
	if _merge_picks.size() >= GameManager.get_part_merge_count():
		return false
	if _merge_picks.count(item_id) >= ItemView.count_of(entry):
		return false
	if not _merge_picks.is_empty():
		var pick_tier: int = int(GameManager.get_part_definition(_merge_picks[0]).get(GameManager.ITEM_MASTER_PART_TIER, 0))
		if int(GameManager.get_part_definition(item_id).get(GameManager.ITEM_MASTER_PART_TIER, 0)) != pick_tier:
			return false
	return true


func _on_merge_requested(item_id: String) -> void:
	_merging = true
	_merge_picks = [item_id]
	_merge_target = ""
	_rebuild()


func _end_merge() -> void:
	_merging = false
	_merge_picks.clear()
	_merge_target = ""
	_rebuild()


func _on_merge_pick_removed(index: int) -> void:
	if index >= 0 and index < _merge_picks.size():
		_merge_picks.remove_at(index)
	if _merge_picks.is_empty():
		_merge_target = ""
	_rebuild()


func _on_merge_target_chosen(item_id: String) -> void:
	_merge_target = item_id
	_rebuild()


func _on_merge_confirm() -> void:
	var picks: Array[String] = _merge_picks.duplicate()
	var target: String = _merge_target
	if not await PartMergePanel.run(self, picks, target):
		return
	if not is_instance_valid(self):
		return
	_merging = false
	_merge_picks.clear()
	_merge_target = ""
	_selected_key = target
	_rebuild()


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


func _on_state_changed() -> void:
	# ⚠ 一括分解のあいだに選んだ物が消えたら外す。
	var kept: Array[String] = []
	for instance_id: String in _picked:
		if GameManager.can_dismantle_equipment(instance_id):
			kept.append(instance_id)
	_picked = kept
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.go_back_or(BASE_PATH)


# 入手先の窓から戻ってきたときの姿（⚠ 同じタブ・装備なら同じ品）。
func _source_return_data() -> Dictionary:
	return {TransferKeys.WAREHOUSE_TAB: _tab, TransferKeys.WAREHOUSE_INSTANCE_ID: _selected_key if _tab == TransferKeys.WAREHOUSE_TAB_EQUIP else ""}
