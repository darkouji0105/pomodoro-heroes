# res://scenes/guild/warehouse_screen.gd
# 持ち物（⚠ ファイル名は前の「倉庫」のまま＝決定 `BS-15`「画面は増やさず、いまの倉庫画面を作り替える」）。
#
# ⚠⚠ 2026-09-27（回UI-組 持ち物・手本 Belongings / RichItemMulti・人間「⚠ 1あ 2あ 3あ 4あ」）：⚠ **作り替えた**。
#   ⚠ 左：紙のタブ（装備・装飾・素材）。⚠ 装備は部位の縦タブ（すべて・頭・…）で絞る。⚠ 中は台帳の行。
#   ⚠ 右：説明の紙（`BelongingsDetail`）＝ ⚠ 着ける・外す・鍛える・刺す・外す・分解・段階を上げる・重ねる・捨てる。
#   ⚠ マス目・ページ・「マス 0/500」・「枠を買う」は画面から消した（決定 `BS-10`）。
#   ⚠ **容量の判定は `GameManager` に残っている**（人間「⚠ 1あ」＝判定を消す `BS-20` は別の回に EXEC を書いてから）。
#   ⚠ 図鑑は 2026-09-28 に記録の画面へ移した（⚠ 人間「⚠ 4あ」＝持ち物のタブから外した）。
#   ⚠ 前の装備画面（仮の鍛冶場）と説明の窓（`ItemActionPanel`）は消した（人間「⚠ 3あ」）。
#   ⚠ 「捨てる」は持ち物のマスを使う品だけに残した（人間「⚠ 4あ」・`EQ-14` は判定を消す回で）。
# ⚠ 何が何個あるかは全部 `GameManager` の口（⚠ 装備＝`get_owned_instances()` ／ 持ち物＝`get_inventory_slot_entries()` ／
#   ⚠ 素材＝`get_material_slot_entries()`）。⚠ ここで数え直さない。

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
# ⚠ 行の中身の鍵（⚠ 行と右の紙で同じ品を指すため）。
const ROW_ENTRY: String = "entry"
const ROW_KEY: String = "key"
const ROW_IN_INVENTORY: String = "in_inventory"

var _tab: String = TransferKeys.WAREHOUSE_TAB_EQUIP
# ⚠ 装備の部位の絞り込み（⚠ 空＝すべて）。
var _slot_filter: String = ""
# ⚠ いま選んでいる品の鍵（⚠ 個体なら instance_id・それ以外は item_id）。
var _selected_key: String = ""
# ⚠ 刺せる装飾を並べているあいだの相手（⚠ 空なら並べていない）。⚠ 状態ではなく画面の都合。
var _attach_instance: String = ""
var _attach_slot: int = -1

var tabs: PaperTabs = null
var _page: HBoxContainer = null
var _detail: BelongingsDetail = null

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
	tabs.set_tabs(TAB_KEYS, TAB_IDS.find(_tab))
	tabs.tab_changed.connect(_on_tab_changed)
	left.add_child(tabs)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Page"
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sheet)
	_page = HBoxContainer.new()
	_page.name = "PageBody"
	sheet.add_child(_page)

	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "DetailHolder"
	holder.sheet.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	_detail = BelongingsDetail.new()
	_detail.name = "Detail"
	_detail.host = self
	_detail.attach_requested.connect(_on_attach_requested)
	holder.sheet.add_child(_detail)
	body.add_child(holder)

	# ⚠ 1操作で2本飛ぶことがある（⚠ 分解＝素材と個体）。⚠ 再描画に await を持たせない（AGENTS.md）。
	GameManager.inventory_changed.connect(_on_state_changed.unbind(1))
	GameManager.equipment_instances_changed.connect(_on_state_changed.unbind(1))
	GameManager.material_changed.connect(_on_state_changed.unbind(2))
	GameManager.character_growth_changed.connect(_on_state_changed.unbind(1))
	_rebuild()


# --- 描き直し ---

func _rebuild() -> void:
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	if _tab == TransferKeys.WAREHOUSE_TAB_EQUIP and _attach_instance == "":
		_page.add_child(_build_filter())
		_page.add_child(VSeparator.new())

	var rows: Array[Dictionary] = _rows()
	# ⚠ 選んでいたものが無くなっていることがある（壊した・分解した）。⚠ そのときは先頭を選ぶ。
	var selected: Dictionary = {}
	for row: Dictionary in rows:
		if str(row.get(ROW_KEY, "")) == _selected_key:
			selected = row
	if selected.is_empty() and _attach_instance == "" and not rows.is_empty():
		selected = rows[0]
		_selected_key = str(selected.get(ROW_KEY, ""))
	# ⚠ 10-07（人間「⚠ そのページの紐が全部一気に消えてしまう　一個ずつ消えていくように確認したら」）：⚠ 「見た」にするのは右の紙に出した品だけ（⚠ 前は一覧に出した品を全部＝紐が一気に消えた）。
	if not selected.is_empty() and _attach_instance == "":
		GameManager.mark_items_seen([str((selected.get(ROW_ENTRY, {}) as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, ""))])

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "ListColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(column)
	column.add_child(_build_heading(rows.size()))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Rows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if rows.is_empty():
		list.add_child(EmptyState.create("ui_part_none_hint" if _attach_instance != "" else "ui_warehouse_empty"))
	for row: Dictionary in rows:
		list.add_child(_create_row(row))
	# ⚠ 10-07（人間「⚠ しおり紐は気づいたんだけど　そこから言ったページで何を見ればいいのかわかんなかった」）：⚠ NEW の品があるタブに紐（⚠ いま見ているタブは「見た」になったので消える）。
	if tabs != null:
		for index: int in range(TAB_IDS.size()):
			tabs.set_attention(index, _tab_has_new(TAB_IDS[index]))
	var facility: Node = get_node_or_null("FacilityBar")
	if facility is BaseFacilityBar:
		(facility as BaseFacilityBar).refresh_attention()

	# ⚠ 刺せる装飾を並べているあいだも、⚠ 右の紙は刺す相手（装備）のまま。
	if _attach_instance != "":
		_detail.setup(_instance_entry(_attach_instance), false)
	else:
		_detail.setup(selected.get(ROW_ENTRY, {}) as Dictionary, bool(selected.get(ROW_IN_INVENTORY, false)))


# 部位の縦タブ（⚠ すべて・頭・上半身・下半身・武器・アクセサリー）。⚠ 並びは `get_equip_slots()`。
func _build_filter() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "SlotFilter"
	column.custom_minimum_size.x = float(get_theme_constant(&"filter_width", THEME_TYPE))
	var slots: Array[String] = [""]
	for slot: String in GameManager.get_equip_slots():
		slots.append(slot)
	for slot: String in slots:
		var row: LedgerRow = LedgerRow.new()
		row.name = "Filter_" + (slot if slot != "" else "all")
		row.selected = slot == _slot_filter
		row.show_rule = false
		row.pressed.connect(_on_filter_pressed.bind(slot))
		var label: Label = Label.new()
		label.text = tr("ui_equipment_slot_" + slot) if slot != "" else tr("ui_belongings_filter_all")
		row.add_child(label)
		column.add_child(row)
	return column


func _build_heading(count: int) -> Control:
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	heading.ornament = true
	heading.right_text = tr("ui_belongings_count") % count
	if _attach_instance == "":
		heading.title_key = TAB_KEYS[TAB_IDS.find(_tab)]
		return heading
	# ⚠ 刺せる装飾を並べているあいだ（⚠ 2手＝枠か「刺す」を押す → 装飾を押す）。⚠ 「やめる」で戻る。
	heading.title_text = tr("ui_belongings_attach_heading") % (_attach_slot + 1)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "AttachHead"
	row.add_child(heading)
	var cancel: Button = UiButton.create_paper_choice("ui_common_cancel")
	cancel.name = "AttachCancel"
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(_end_attach)
	row.add_child(cancel)
	return row


# --- 行 ---

# ⚠ そのタブに NEW の品があるか（⚠ 装備は部位の絞り込みを見ない）。
func _tab_has_new(tab_id: String) -> bool:
	match tab_id:
		TransferKeys.WAREHOUSE_TAB_PART:
			for row: Dictionary in _part_rows():
				if GameManager.is_item_new(str((row.get(ROW_ENTRY, {}) as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, ""))):
					return true
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			for row: Dictionary in _material_rows():
				if GameManager.is_item_new(str((row.get(ROW_ENTRY, {}) as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, ""))):
					return true
		_:
			for raw: Variant in GameManager.get_owned_instances():
				if GameManager.is_item_new(str((raw as Dictionary).get(GameStateKeys.INSTANCE_ITEM_ID, ""))):
					return true
	return false


func _rows() -> Array[Dictionary]:
	if _attach_instance != "":
		return _attachable_rows()
	match _tab:
		TransferKeys.WAREHOUSE_TAB_PART:
			return _part_rows()
		TransferKeys.WAREHOUSE_TAB_MATERIAL:
			return _material_rows()
	return _equip_rows()


# ⚠ 装備は着けている個体も並べる（⚠ 手本＝誰が着けているかを行に出す）。⚠ 並びは `get_owned_instances()` のまま。
func _equip_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw: Variant in GameManager.get_owned_instances():
		var view: Dictionary = raw
		var instance_id: String = str(view.get(GameManager.INSTANCE_VIEW_ID, ""))
		var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		var slot: String = str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))
		if _slot_filter != "" and slot != _slot_filter:
			continue
		rows.append({ROW_KEY: instance_id, ROW_ENTRY: _instance_entry(instance_id), ROW_IN_INVENTORY: false})
	return rows


func _part_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw: Variant in GameManager.get_inventory_slot_entries():
		var entry: Dictionary = raw
		if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) != GameManager.SLOT_KIND_ITEM:
			continue
		var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		if GameManager.get_part_definition(item_id).is_empty():
			continue
		rows.append({ROW_KEY: item_id, ROW_ENTRY: entry, ROW_IN_INVENTORY: true})
	return rows


# ⚠ 素材（⚠ 持っていない素材も薄く並ぶ＝前の素材タブと同じ）＋ ⚠ 持ち物のマスを使うその他の品（消耗品など）。
func _material_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw: Variant in GameManager.get_material_slot_entries():
		var entry: Dictionary = raw
		rows.append({ROW_KEY: str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")), ROW_ENTRY: entry, ROW_IN_INVENTORY: false})
	for raw: Variant in GameManager.get_inventory_slot_entries():
		var entry: Dictionary = raw
		if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) != GameManager.SLOT_KIND_ITEM:
			continue
		var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		if not GameManager.get_part_definition(item_id).is_empty():
			continue
		rows.append({ROW_KEY: item_id, ROW_ENTRY: entry, ROW_IN_INVENTORY: true})
	return rows


# 刺せる装飾だけ（⚠ 判定は `get_part_reject_reason()` の1本。⚠ 刺さらない種類・解放されていない種類は並べない）。
func _attachable_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in _part_rows():
		var item_id: String = str(row.get(ROW_KEY, ""))
		if GameManager.get_part_reject_reason(_attach_instance, _attach_slot, item_id) == GameManager.PART_REJECT_KIND:
			continue
		var definition: Dictionary = GameManager.get_part_definition(item_id)
		if not GameManager.is_part_kind_unlocked(str(definition.get(GameManager.ITEM_MASTER_PART_KIND, ""))):
			continue
		rows.append(row)
	return rows


# 台帳の1行：マス ／ 名前・添え書き ／ 主な値 ／ 誰が着けているか（⚠ 装備だけ）。
func _create_row(row_data: Dictionary) -> LedgerRow:
	var entry: Dictionary = row_data.get(ROW_ENTRY, {})
	var key: String = str(row_data.get(ROW_KEY, ""))
	var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	var row: LedgerRow = LedgerRow.new()
	row.name = "Row_" + key
	# ⚠ 10-07（人間「⚠ EはAとおなじ」）：⚠ 新しく手に入れた品にしおり紐。
	if GameManager.is_item_new(item_id):
		RibbonMark.attach(row)
	row.selected = key == _selected_key and _attach_instance == ""
	row.pressed.connect(_on_row_pressed.bind(key))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var icon: ItemSlot = ItemSlot.create(entry)
	var side: float = float(get_theme_constant(&"item_icon", &"Training"))
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = tr(GameManager.item_name_key(item_id))
	column.add_child(name_label)
	var sub: Label = Label.new()
	sub.theme_type_variation = &"CaptionLabel"
	column.add_child(sub)

	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(value)

	if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) == GameManager.SLOT_KIND_INSTANCE:
		var instance_id: String = str(entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
		var slot: String = str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))
		sub.text = tr("ui_equipment_slot_" + slot) if slot != "" else ""
		var stats: Dictionary = GameManager.get_instance_stats(instance_id)
		var main_key: String = BelongingsDetail.main_stat_of(stats)
		value.text = "%s %s" % [tr("ui_training_stat_" + main_key), BelongingsDetail.stat_text(main_key, int(stats.get(main_key, 0)))] if main_key != "" else ""
		# ⚠ 特殊効果の星（2026-10-02・回UI-仕組み⑦・手本 RichItemFx）。⚠ 値の右。
		var star: Label = SpecialEffectCard.star(item_id)
		if star != null:
			line.add_child(star)
		var owner: String = str(entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
		var owner_label: Label = Label.new()
		owner_label.name = "OwnerLabel"
		owner_label.theme_type_variation = &"CaptionLabel"
		owner_label.custom_minimum_size.x = side * 2.0
		owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if owner != "":
			owner_label.text = tr(str(MasterDataLoader.get_character(owner).get("name_key", owner)))
		line.add_child(owner_label)
	elif not GameManager.get_part_definition(item_id).is_empty():
		var definition: Dictionary = GameManager.get_part_definition(item_id)
		var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
		sub.text = tr("ui_belongings_owned") % int(entry.get(GameManager.SLOT_ENTRY_COUNT, 0))
		value.text = "%s %s" % [tr("ui_training_stat_" + stat_key), BelongingsDetail.part_range_text(item_id)] if stat_key != "" else ""
	else:
		var count: int = int(entry.get(GameManager.SLOT_ENTRY_COUNT, 0))
		value.theme_type_variation = &"DossierLevelLabel"
		value.text = str(count)
		# ⚠ 持っていない素材は薄く（⚠ 消さない＝何が要るかは見せる）。
		if count <= 0:
			row.modulate.a = 0.5
	return row


# ⚠ 個体をマスの形に包む（⚠ 行と右の紙に渡す形。⚠ 状態には入らない）。
func _instance_entry(instance_id: String) -> Dictionary:
	var instance: Dictionary = GameManager.get_equipment_instance(instance_id)
	if instance.is_empty():
		return {}
	var owner: String = ""
	for view: Variant in GameManager.get_owned_instances():
		if str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
			owner = str((view as Dictionary).get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
	return {
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
		GameManager.SLOT_ENTRY_INSTANCE_ID: instance_id,
		GameManager.SLOT_ENTRY_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: owner,
	}


# ⚠ 図鑑は 2026-09-28 に記録の画面（`records_screen`）へ移した（⚠ 人間「⚠ 4あ」）。

# --- 操作 ---

func _on_tab_changed(index: int) -> void:
	_tab = TAB_IDS[index]
	SceneManager.remember(TransferKeys.MEMORY_WAREHOUSE_TAB, _tab)
	_selected_key = ""
	_attach_instance = ""
	_attach_slot = -1
	_rebuild()


func _on_filter_pressed(slot: String) -> void:
	if slot == _slot_filter:
		return
	_slot_filter = slot
	_selected_key = ""
	_rebuild()


func _on_row_pressed(key: String) -> void:
	# ⚠ 刺せる装飾を並べているあいだは、⚠ 押した装飾をそのまま刺す（⚠ 2手目）。
	if _attach_instance != "":
		var target: String = _attach_instance
		var slot_index: int = _attach_slot
		_end_attach()
		# ⚠ 描き直しはシグナル側（⚠ 刺すと個体と持ち物の2本が飛ぶ）。
		GameManager.attach_part(target, slot_index, key)
		return
	if key == _selected_key:
		return
	_selected_key = key
	_rebuild()


# ⚠ 刺せる装飾を並べる（⚠ 右の紙の「刺す」か空きの枠から）。⚠ 刺す相手の装備は選んだまま。
func _on_attach_requested(instance_id: String, slot_index: int) -> void:
	_attach_instance = instance_id
	_attach_slot = slot_index
	_rebuild()


func _end_attach() -> void:
	_attach_instance = ""
	_attach_slot = -1
	_rebuild()


# ⚠ 「捨てる」は消した（2026-10-03・回3-d・`EQ-14`・人間「⚠ 4あ」＝拠点に容量が無いので捨てる理由が無い）。
#   ⚠ 装備は「素材にする」（分解）が残る。


func _on_state_changed() -> void:
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.go_back_or(BASE_PATH)


# 入手先の窓から戻ってきたときの姿（⚠ 同じタブ・装備なら同じ品）。
func _source_return_data() -> Dictionary:
	return {TransferKeys.WAREHOUSE_TAB: _tab, TransferKeys.WAREHOUSE_INSTANCE_ID: _selected_key if _tab == TransferKeys.WAREHOUSE_TAB_EQUIP else ""}
