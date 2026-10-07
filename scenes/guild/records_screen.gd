# res://scenes/guild/records_screen.gd
# 記録（2026-09-28・回UI-仕組み②・手本 Records）。
#
# ⚠ 人間「⚠ 1い　⚠ 2あ　⚠ 3い　⚠ 4あ　⚠ 5あ」：
#   ⚠ 紙のタブ **アイテム図鑑 ／ 集中の履歴 ／ キャラの情報 ／ ダンジョンの情報**（⚠ いまあるデータで出せるぶん＝「⚠ 1い」）。
#   ⚠ 図鑑は「初めて手に入れた記録 n / 全体」・装備 ／ 装飾 ／ 素材 ごとに絵と「？」の枠（⚠ 素材も図鑑に載る＝「⚠ 2あ」）。
#   ⚠ 手本の左の「遺物」の欄は置かない（⚠ 遺物 `EQ-8` はまだ無い＝「⚠ 3い」）。
#   ⚠ 持ち物の画面の図鑑タブは外した（「⚠ 4あ」）。⚠ 施設の帯の「記録」はここを開く。
#   ⚠ 集中の履歴は合計と今日だけ（⚠ 日ごとの履歴は記録していない＝「⚠ 5あ」）。
# ⚠ 何を持っているか・数は全部 `GameManager` の口（⚠ ここで数え直さない）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 状態は変えない画面（⚠ 見るだけ）。

class_name RecordsScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const RECORDS_PATH: String = "res://scenes/guild/records_screen.tscn"
const THEME_TYPE: StringName = &"Records"
const TAB_KEYS: Array[String] = ["ui_records_tab_codex", "ui_records_tab_focus", "ui_records_tab_characters", "ui_records_tab_dungeons", "ui_records_tab_tasks"]
const TAB_CODEX: int = 0
const TAB_FOCUS: int = 1
const TAB_CHARACTERS: int = 2
const TAB_DUNGEONS: int = 3
# ⚠ 終わったタスク（2026-10-04・`TK-8`）。⚠ `TK-8` は「4つ目」と書くが、⚠ 既に4枚あった＝⚠ 末尾に足した（⚠ 既存の番号をずらさない）。
const TAB_TASKS: int = 4

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Main
@onready var sheet_body: VBoxContainer = $Margin/Layout/Main/Sheet/SheetBody

var _tab: int = TAB_CODEX
var _tabs: PaperTabs = null
# ⚠ 図鑑で押して選んだ品（⚠ 右に詳しく出す・09-28 見る回・人間「⚠ クリックすると詳細も見れるようにしたい」）。
var _picked: String = ""
# ⚠ 装備は等級の枠を押す（⚠ 0＝装備以外）。
var _picked_grade: int = 0
# ⚠ 図鑑で出している種類（⚠ 09-29 人間「⚠ 2あ」）。
var _codex_kind: String = GameManager.CODEX_KIND_EQUIPMENT


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_source_return_data)
	# ⚠ 10-06（`NAV-18`）：⚠ 寄り道（育成）から戻ったときは、そのときのタブで開く。
	var data: Dictionary = SceneManager.consume_transfer_data()
	# ⚠ 10-07（H）：⚠ 渡されなければ前に開いていたタブ。
	_tab = clampi(int(data.get(TransferKeys.RECORDS_TAB, SceneManager.recall(TransferKeys.MEMORY_RECORDS_TAB, TAB_CODEX))), 0, TAB_KEYS.size() - 1)
	# ⚠ 朝4:00 の移し（2026-10-04・`TK-6`）。⚠ 昨日終えたタスクを「終わったタスク」に載せてから描く。
	var _moved: int = GameManager.roll_over_done_tasks()
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.RECORDS)
	_tabs = PaperTabs.new()
	_tabs.name = "Tabs"
	_tabs.set_tabs(TAB_KEYS, _tab)
	_tabs.tab_changed.connect(_on_tab_changed)
	main_stack.add_child(_tabs)
	main_stack.move_child(_tabs, 0)
	_rebuild()


func _on_tab_changed(index: int) -> void:
	_tab = index
	SceneManager.remember(TransferKeys.MEMORY_RECORDS_TAB, _tab)
	_rebuild()


func _rebuild() -> void:
	for child: Node in sheet_body.get_children():
		sheet_body.remove_child(child)
		child.queue_free()
	match _tab:
		TAB_FOCUS:
			_build_focus()
		TAB_CHARACTERS:
			_build_characters()
		TAB_DUNGEONS:
			_build_dungeons()
		TAB_TASKS:
			_build_tasks()
		_:
			_build_codex()


func _heading(title_key: String, right: String = "") -> SheetHeading:
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = title_key
	heading.right_text = right
	heading.ornament = true
	return heading


func _scroll_list(parent: Control = null) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(sheet_body if parent == null else parent).add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


# --- アイテム図鑑（⚠ 手本「初めて手に入れた記録」） --------------------------

func _build_codex() -> void:
	var found: int = 0
	var total: int = 0
	for kind: String in GameManager.CODEX_KINDS:
		var counts: Vector2i = codex_counts(kind)
		found += counts.x
		total += counts.y
	# ⚠ 左に一覧 ／ 縦の線 ／ 右に押した品の詳しい中身。
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "CodexBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_body.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var heading: SheetHeading = _heading("ui_records_codex_title", "%d / %d" % [found, total])
	heading.name = "CodexHeading"
	left.add_child(heading)
	# ⚠ 種類の切り替え「装備｜装飾｜素材」（⚠ 09-29 見る回・人間「⚠ 2あ」＝装備の表が縦に長いので1つずつ出す）。
	var kinds: HBoxContainer = HBoxContainer.new()
	kinds.name = "KindChoices"
	kinds.theme_type_variation = &"SettingsChoices"
	for kind: String in GameManager.CODEX_KINDS:
		var counts: Vector2i = codex_counts(kind)
		var choice: Button = UiButton.create_paper_choice("")
		choice.name = "Kind_" + kind
		choice.text = "%s %d/%d" % [tr("ui_records_kind_" + kind), counts.x, counts.y]
		if kind == _codex_kind:
			choice.theme_type_variation = &"PaperChoiceSelected"
		choice.pressed.connect(_on_codex_kind_pressed.bind(kind))
		# ⚠ 10-07：⚠ NEW の品がある種類に紐（⚠ どれを押せばよいか）。
		var has_new: bool = false
		for codex_id: String in GameManager.get_codex_ids(kind):
			if GameManager.is_item_new(codex_id):
				has_new = true
				break
		choice.set_meta(RibbonMark.META_INSET, 0.0)
		RibbonMark.set_on(choice, has_new)
		kinds.add_child(choice)
	left.add_child(kinds)
	var list: VBoxContainer = _scroll_list(left)
	list.add_child(_codex_section(_codex_kind))
	body.add_child(VSeparator.new())
	body.add_child(_codex_detail())


func _on_codex_kind_pressed(kind: String) -> void:
	if kind == _codex_kind:
		return
	_codex_kind = kind
	# ⚠ 押した札を押している最中に外さない（⚠ 次のフレームで描き直す）。
	_rebuild.call_deferred()


# 埋まった数と全体（x＝埋まった ／ y＝全体）。⚠ 装備は「品 × 等級」で数える（⚠ `EXEC_CODEX_GRADES.md` §6）。
func codex_counts(kind: String) -> Vector2i:
	var ids: Array[String] = GameManager.get_codex_ids(kind)
	var found: int = 0
	if kind == GameManager.CODEX_KIND_EQUIPMENT:
		for item_id: String in ids:
			found += GameManager.get_codex_grades(item_id).size()
		return Vector2i(found, ids.size() * GameManager.get_max_equipment_grade())
	for item_id: String in ids:
		if GameManager.is_codex_discovered(item_id):
			found += 1
	return Vector2i(found, ids.size())


# 種類ひとつ：見出し「装備　4 / 15」＋ 絵と「？」の枠。⚠ 手に入れていない品は名前も絵も出さない（⚠ 中身が割れる）。
# ⚠ 装備だけは部位ごとの表（⚠ 列＝等級1〜10・行＝品）＝`_equipment_table()`（⚠ 09-28 人間「⚠ 等級ごとに列を作って　⚠ カテゴリごとに分ける」）。
func _codex_section(kind: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = "Section_" + kind
	var ids: Array[String] = GameManager.get_codex_ids(kind)
	var counts: Vector2i = codex_counts(kind)
	var line: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_records_kind_" + kind)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var count: Label = Label.new()
	count.name = "CountLabel"
	count.text = "%d / %d" % [counts.x, counts.y]
	line.add_child(count)
	section.add_child(line)
	if kind == GameManager.CODEX_KIND_EQUIPMENT:
		section.add_child(_equipment_table(ids))
		section.add_child(HSeparator.new())
		return section
	var cells: HFlowContainer = HFlowContainer.new()
	cells.name = "Cells"
	cells.theme_type_variation = &"RecordsCells"
	section.add_child(cells)
	for item_id: String in ids:
		if GameManager.is_codex_discovered(item_id):
			# ⚠ 押せる枠の中に絵（⚠ 押すと右に詳しく）。⚠ 選んでいる品は金の縁。
			var cell: Button = Button.new()
			cell.name = "Found_" + item_id
			cell.theme_type_variation = &"RecordsCellPicked" if item_id == _picked else &"RecordsCell"
			cell.tooltip_text = tr(GameManager.item_name_key(item_id))
			var side: float = float(get_theme_constant(&"cell", THEME_TYPE))
			cell.custom_minimum_size = Vector2(side, side)
			cell.pressed.connect(_on_item_picked.bind(item_id))
			# ⚠ 10-07（人間「⚠ EはAとおなじ」）：⚠ まだ見ていない品にしおり紐（⚠ 見せたら「見た」）。
			if GameManager.is_item_new(item_id):
				RibbonMark.attach(cell)
			var icon: ItemIcon = ItemIcon.create(item_id)
			icon.name = "Icon"
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
			cells.add_child(cell)
		else:
			cells.add_child(_unknown_cell(item_id))
	section.add_child(HSeparator.new())
	return section


# 装備の表：⚠ 上に等級の見出し（1〜10）・⚠ 部位ごとに小見出しと品の行。⚠ 行＝品の名前（まだなら「？」）＋ 等級の枠。
#   ⚠ 手に入れた等級＝その等級の色の絵（押せる）／ ⚠ まだ＝「？」の枠に等級の数字を薄く。
func _equipment_table(ids: Array[String]) -> VBoxContainer:
	var table: VBoxContainer = VBoxContainer.new()
	table.name = "EquipmentTable"
	var max_grade: int = GameManager.get_max_equipment_grade()
	var header: HBoxContainer = _table_row()
	header.name = "GradeHeader"
	header.add_child(_name_cell(""))
	for grade: int in range(1, max_grade + 1):
		var number: Label = Label.new()
		number.theme_type_variation = &"CaptionLabel"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.custom_minimum_size.x = float(get_theme_constant(&"cell", THEME_TYPE))
		number.text = tr("ui_records_grade") % grade
		header.add_child(number)
	table.add_child(header)
	# ⚠ 部位の順は品の並び順（sort_order）で最初に出た順（⚠ 武器が先）。
	var slots: Array[String] = []
	for item_id: String in ids:
		var item_slot: String = str(MasterDataLoader.get_item(item_id).get("equip_slot", ""))
		if not (item_slot in slots):
			slots.append(item_slot)
	for slot: String in slots:
		var slot_ids: Array[String] = []
		for item_id: String in ids:
			if str(MasterDataLoader.get_item(item_id).get("equip_slot", "")) == slot:
				slot_ids.append(item_id)
		if slot_ids.is_empty():
			continue
		var slot_label: Label = Label.new()
		slot_label.name = "Slot_" + slot
		slot_label.theme_type_variation = &"CaptionLabel"
		slot_label.text = tr("ui_equipment_slot_" + slot)
		table.add_child(slot_label)
		for item_id: String in slot_ids:
			var row: HBoxContainer = _table_row()
			row.name = "Row_" + item_id
			var grades: Array[int] = GameManager.get_codex_grades(item_id)
			row.add_child(_name_cell(tr(GameManager.item_name_key(item_id)) if GameManager.is_codex_discovered(item_id) else tr("ui_records_unknown")))
			for grade: int in range(1, max_grade + 1):
				if grade in grades:
					row.add_child(_found_cell(item_id, grade))
				else:
					var cell: PanelContainer = _unknown_cell(item_id)
					cell.name = "UnknownGrade_%s_%d" % [item_id, grade]
					(cell.get_child(0) as Label).text = str(grade)
					row.add_child(cell)
			table.add_child(row)
	return table


func _table_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"RecordsTableRow"
	return row


func _name_cell(text: String) -> Label:
	var label: Label = Label.new()
	label.custom_minimum_size.x = float(get_theme_constant(&"name_width", THEME_TYPE))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = text
	return label


# 手に入れた等級の枠（⚠ 押すと右にその等級の値）。
func _found_cell(item_id: String, grade: int) -> Button:
	var cell: Button = Button.new()
	cell.name = "Grade_%s_%d" % [item_id, grade]
	cell.theme_type_variation = &"RecordsCellPicked" if (item_id == _picked and grade == _picked_grade) else &"RecordsCell"
	cell.tooltip_text = "%s %s" % [tr(GameManager.item_name_key(item_id)), tr("ui_records_grade") % grade]
	var side: float = float(get_theme_constant(&"cell", THEME_TYPE))
	cell.custom_minimum_size = Vector2(side, side)
	cell.pressed.connect(_on_item_picked.bind(item_id, grade))
	# ⚠ 10-07：⚠ 装備の図鑑も NEW のしおり紐（⚠ 品ごと＝その品のどの等級を押しても消える）。
	if GameManager.is_item_new(item_id):
		RibbonMark.attach(cell)
	var icon: ItemIcon = ItemIcon.create(item_id, grade)
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	return cell


func _on_item_picked(item_id: String, grade: int = 0) -> void:
	if item_id == _picked and grade == _picked_grade:
		return
	_picked = item_id
	_picked_grade = grade
	# ⚠ 10-07（人間「⚠ そのページの紐が全部一気に消えてしまう　一個ずつ消えていくように確認したら」）：⚠ 押して詳しくを見た品だけ「見た」。
	GameManager.mark_items_seen([item_id])
	# ⚠ 押した枠を押している最中に外さない（⚠ 次のフレームで描き直す）。
	_rebuild.call_deferred()


# 右：押した品の詳しい中身（⚠ 品のデータに説明文は無い＝⚠ データにある値を出す）。
#   ⚠ 装備＝部位・素の値 ／ 装飾＝伸ばす値の幅・段階 ／ 素材＝段階 ／ ⚠ どれも持っている数・初めて手に入れた日。
func _codex_detail() -> VBoxContainer:
	var detail: VBoxContainer = VBoxContainer.new()
	detail.name = "CodexDetail"
	detail.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	if _picked == "" or not GameManager.is_codex_discovered(_picked):
		var none: Label = Label.new()
		none.name = "DetailNone"
		none.theme_type_variation = &"CaptionLabel"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = tr("ui_records_detail_none")
		detail.add_child(none)
		return detail
	var master: Dictionary = MasterDataLoader.get_item(_picked)
	var head: HBoxContainer = HBoxContainer.new()
	var holder: Control = Control.new()
	var icon_scale: float = float(get_theme_constant(&"detail_icon_scale_pct", THEME_TYPE)) / 100.0
	var icon: ItemIcon = ItemIcon.create(_picked, _picked_grade)
	icon.name = "DetailIcon"
	# ⚠ 10-07：⚠ アイコンを押しても入手先の窓。
	ItemSourceWindow.attach_to(icon, _picked)
	holder.add_child(icon)
	holder.scale = Vector2.ONE * icon_scale
	holder.custom_minimum_size = Vector2.ONE * float(get_theme_constant(&"cell", THEME_TYPE))
	var holder_box: Control = Control.new()
	holder_box.custom_minimum_size = holder.custom_minimum_size * icon_scale
	holder_box.add_child(holder)
	head.add_child(holder_box)
	var name_column: VBoxContainer = VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_column)
	var name_label: Label = Label.new()
	name_label.name = "DetailName"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = tr(GameManager.item_name_key(_picked))
	name_column.add_child(name_label)
	var kind: String = _kind_of(_picked)
	var kind_label: Label = Label.new()
	kind_label.theme_type_variation = &"CaptionLabel"
	kind_label.text = tr("ui_records_kind_" + kind)
	name_column.add_child(kind_label)
	detail.add_child(head)
	detail.add_child(HSeparator.new())
	match kind:
		GameManager.CODEX_KIND_EQUIPMENT:
			# ⚠ 押した等級の素の値（⚠ `get_item_stats_at_grade()`＝式は1か所・`EXEC_CODEX_GRADES.md` §6）。
			var grade: int = maxi(1, _picked_grade)
			detail.add_child(_detail_line("SlotLine", tr("ui_records_detail_slot"), tr("ui_equipment_slot_" + str(master.get("equip_slot", "")))))
			detail.add_child(_detail_line("GradeLine", tr("ui_forge_grade"), str(grade)))
			var stats: Dictionary = GameManager.get_item_stats_at_grade(_picked, grade)
			for stat_key: String in stats:
				if int(stats[stat_key]) != 0:
					detail.add_child(_detail_line("Stat_" + stat_key, tr("ui_training_stat_" + stat_key), "%+d" % int(stats[stat_key])))
			# ⚠ 特殊効果の札（2026-10-02・回UI-仕組み⑦）。
			var effect_card: SpecialEffectCard = SpecialEffectCard.create_for_item(_picked)
			if effect_card != null:
				detail.add_child(effect_card)
		GameManager.CODEX_KIND_PART:
			var part: Dictionary = GameManager.get_part_definition(_picked)
			var base: int = int(part.get(GameManager.ITEM_MASTER_PART_BASE, 0))
			detail.add_child(_detail_line("TierLine", tr("ui_records_detail_tier"), str(int(part.get(GameManager.ITEM_MASTER_PART_TIER, 0)))))
			detail.add_child(_detail_line("RangeLine", tr("ui_training_stat_" + str(part.get(GameManager.ITEM_MASTER_PART_STAT, ""))),
				tr("ui_records_detail_range") % [base, base + int(part.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0))]))
		_:
			detail.add_child(_detail_line("TierLine", tr("ui_records_detail_tier"), str(GameManager.get_material_tier(_picked))))
	# ⚠ 手に入れた数（⚠ 09-29 人間「⚠ 持っている数ではなく手に入れた数で」・使っても減らない）。
	detail.add_child(_detail_line("ObtainedCountLine", tr("ui_records_detail_obtained_count"), tr("ui_records_detail_count") % GameManager.get_codex_obtained_count(_picked)))
	var obtained: String = str(GameManager.get_codex_entry(_picked).get(GameStateKeys.CODEX_OBTAINED_AT, ""))
	var date_text: String = tr("ui_records_none")
	if obtained != "":
		date_text = Time.get_date_string_from_unix_time(int(float(obtained) + Time.get_time_zone_from_system().get("bias", 0) * 60))
	detail.add_child(_detail_line("ObtainedLine", tr("ui_records_detail_obtained"), date_text))
	return detail


func _detail_line(line_name: String, caption_text: String, value_text: String) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = line_name
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.text = value_text
	line.add_child(value)
	return line


func _kind_of(item_id: String) -> String:
	for kind: String in GameManager.CODEX_KINDS:
		if item_id in GameManager.get_codex_ids(kind):
			return kind
	return GameManager.CODEX_KIND_MATERIAL



func _unknown_cell(item_id: String) -> PanelContainer:
	var cell: PanelContainer = PanelContainer.new()
	cell.name = "Unknown_" + item_id
	cell.theme_type_variation = &"RecordsUnknownCell"
	var side: float = float(get_theme_constant(&"cell", THEME_TYPE))
	cell.custom_minimum_size = Vector2(side, side)
	var mark: Label = Label.new()
	mark.theme_type_variation = &"CaptionLabel"
	mark.text = tr("ui_records_unknown")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(mark)
	return cell


# --- 集中の履歴（⚠ 合計と今日だけ＝「⚠ 5あ」） ------------------------------

func _build_focus() -> void:
	sheet_body.add_child(_heading("ui_records_tab_focus"))
	var list: VBoxContainer = _scroll_list()
	list.add_child(_value_row("TotalRow", tr("ui_records_focus_total"), tr("ui_records_count") % GameManager.get_total_pomodoro_completed()))
	list.add_child(_value_row("TodayRow", tr("ui_records_focus_today"), tr("ui_records_minutes") % GameManager.get_cumulative_focus_minutes_today()))
	var last: String = str(GameManager.get_state().get(GameStateKeys.LAST_POMODORO_END_AT, ""))
	var last_text: String = tr("ui_records_none")
	if last != "":
		last_text = Time.get_datetime_string_from_unix_time(int(float(last) + Time.get_time_zone_from_system().get("bias", 0) * 60), true)
	list.add_child(_value_row("LastRow", tr("ui_records_focus_last"), last_text))
	var note: Label = Label.new()
	note.name = "FocusNote"
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("ui_records_focus_note")
	list.add_child(note)


func _value_row(row_name: String, caption_text: String, value_text: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.theme_type_variation = &"SheetHeadingLabel"
	value.text = value_text
	line.add_child(value)
	return row


# --- キャラの情報（⚠ 行を押すとその人の育成） ------------------------------

func _build_characters() -> void:
	sheet_body.add_child(_heading("ui_records_tab_characters"))
	var list: VBoxContainer = _scroll_list()
	var stat_keys: Array[String] = [GameStateKeys.STAT_HP, GameStateKeys.STAT_ATK, GameStateKeys.STAT_MAG, GameStateKeys.STAT_DEF]
	for raw: Variant in GameManager.get_party_candidates():
		var character_id: String = str(raw)
		var row: LedgerRow = LedgerRow.new()
		row.name = "Character_" + character_id
		row.compact = true
		row.pressed.connect(_on_character_pressed.bind(character_id))
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		line.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"photo", THEME_TYPE)))
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(column)
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.theme_type_variation = &"SheetHeadingLabel"
		name_label.text = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
		column.add_child(name_label)
		var level: Label = Label.new()
		level.name = "LevelLabel"
		level.theme_type_variation = &"CaptionLabel"
		var role: String = character_id if GameManager.is_debug_character(character_id) else tr("ui_role_" + character_id)
		level.text = "%s ／ %s %d" % [role, tr("ui_dossier_lv"), int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))]
		column.add_child(level)
		var stats: Dictionary = GameManager.get_effective_stats(character_id)
		for stat_key: String in stat_keys:
			var stat: Label = Label.new()
			stat.name = "Stat_" + stat_key
			stat.custom_minimum_size.x = float(get_theme_constant(&"stat_width", THEME_TYPE))
			stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stat.text = "%s %d" % [tr("ui_training_stat_" + stat_key), int(stats.get(stat_key, 0))]
			line.add_child(stat)
		list.add_child(row)


func _on_character_pressed(character_id: String) -> void:
	SceneManager.open_detour(TRAINING_PATH, {TransferKeys.CHARACTER_ID: character_id},
		RECORDS_PATH, {TransferKeys.RECORDS_TAB: _tab})


# --- ダンジョンの情報（⚠ 話ごとの済・難ダンジョンの途中） --------------------

func _build_dungeons() -> void:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	var cleared: int = 0
	for stage_id: Variant in order:
		if GameManager.is_stage_cleared(str(stage_id)):
			cleared += 1
	sheet_body.add_child(_heading("ui_records_tab_dungeons", "%d / %d" % [cleared, order.size()]))
	var list: VBoxContainer = _scroll_list()
	var normal: Label = Label.new()
	normal.theme_type_variation = &"CaptionLabel"
	normal.text = tr("ui_quest_tab_normal")
	list.add_child(normal)
	for index: int in range(order.size()):
		var stage_id: String = str(order[index])
		var title: String = "%s　%s" % [tr("ui_quest_episode") % (index + 1), tr(str(MasterDataLoader.get_stage(stage_id).get("name_key", stage_id)))]
		var state_key: String = "ui_records_cleared" if GameManager.is_stage_cleared(stage_id) else "ui_records_not_cleared"
		if GameManager.is_in_floor() and str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")) == stage_id:
			state_key = "ui_records_in_progress"
		list.add_child(_value_row("Stage_" + stage_id, title, tr(state_key)))
	var hard: Label = Label.new()
	hard.theme_type_variation = &"CaptionLabel"
	hard.text = tr("ui_quest_tab_hard")
	list.add_child(hard)
	var current_dungeon: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")) if GameManager.is_in_dungeon() else ""
	for dungeon_id: String in MasterDataLoader.get_all_dungeon_ids():
		var name_text: String = tr(str(MasterDataLoader.get_dungeon(dungeon_id).get("name_key", dungeon_id)))
		list.add_child(_value_row("Dungeon_" + dungeon_id, name_text, tr("ui_records_in_progress") if dungeon_id == current_dungeon else tr("ui_records_none")))


# --- 終わったタスク（2026-10-04・`TK-8`・`TK-9`＝上限なし） ---------------------
#   ⚠ 2026-10-05（モック8）：⚠ 年 → 月 → 日で畳む（⚠ 何百件になっても開いた月だけ並ぶ）・⚠ タグで絞る・⚠ 見出しの右に「ぜんぶで n件　集中 ◯」。
#   ⚠ 新しいものが上。⚠ 開いている年と月は画面の中だけで持つ（⚠ 既定は新しい年と月だけ開く）。⚠ 1行＝色の印・題・タグ・集中した時間（`TK-5`）。

var _task_filter: String = ""
var _task_open: Dictionary = {}   # "2026" / "2026-10" -> bool


func _build_tasks() -> void:
	var task_log: Array = GameManager.get_task_log()
	var total_sec: int = 0
	var tags: Array[String] = []
	for raw: Variant in task_log:
		total_sec += int((raw as Dictionary).get(GameStateKeys.TASK_FOCUS_SEC, 0))
		for tag: Variant in (raw as Dictionary).get(GameStateKeys.TASK_TAGS, []):
			if not (str(tag) in tags):
				tags.append(str(tag))
	if _task_filter != "" and not (_task_filter in tags):
		_task_filter = ""
	sheet_body.add_child(_heading("ui_records_tab_tasks", tr("ui_records_tasks_total") % [task_log.size(), GameManager.task_focus_text(total_sec)]))
	if not tags.is_empty():
		var filter: HFlowContainer = HFlowContainer.new()
		filter.name = "TaskFilter"
		var choices: Array[String] = [""]
		choices.append_array(tags)
		for tag: String in choices:
			var choice: Button = UiButton.create_paper_choice("ui_task_filter_all" if tag == "" else "")
			choice.name = "TaskFilter_all" if tag == "" else "TaskFilter_" + tag
			if tag != "":
				choice.text = tr("ui_task_tag") % tag
			if tag == _task_filter:
				choice.theme_type_variation = &"PaperChoiceSelected"
			choice.pressed.connect(_on_task_filter_pressed.bind(tag))
			filter.add_child(choice)
		sheet_body.add_child(filter)
	var list: VBoxContainer = _scroll_list()
	if task_log.is_empty():
		list.add_child(EmptyState.create("ui_records_tasks_empty", "ui_records_tasks_empty_hint"))
		return
	# ⚠ 新しいものから：⚠ 年 → 月 → 日に分ける（⚠ 日付は朝4:00 区切り＝終えた日のゲーム内の日付）。
	var groups: Dictionary = {}   # year -> {month -> {date -> [entry]}}
	var years: Array[String] = []
	for i: int in range(task_log.size() - 1, -1, -1):
		var entry: Dictionary = task_log[i] as Dictionary
		if _task_filter != "" and not (_task_filter in (entry.get(GameStateKeys.TASK_TAGS, []) as Array)):
			continue
		var date: String = GameDate.get_game_date_string(float(int(entry.get(GameStateKeys.TASK_DONE_AT, 0))))
		var year: String = date.substr(0, 4)
		var month: String = date.substr(0, 7)
		if not groups.has(year):
			groups[year] = {}
			years.append(year)
		var months: Dictionary = groups[year]
		if not months.has(month):
			months[month] = {}
		var days: Dictionary = months[month]
		if not days.has(date):
			days[date] = []
		(days[date] as Array).append(entry)
	years.sort()
	years.reverse()
	for year: String in years:
		var months: Dictionary = groups[year]
		var year_open: bool = bool(_task_open.get(year, year == years[0]))
		list.add_child(_task_band("Year_" + year, tr("ui_records_tasks_year") % int(year), _group_entries(months), year_open, year, &"TaskYearBand", &"TaskBandLabel"))
		if not year_open:
			continue
		var month_keys: Array = months.keys()
		month_keys.sort()
		month_keys.reverse()
		for month: Variant in month_keys:
			var days: Dictionary = months[month]
			var month_open: bool = bool(_task_open.get(str(month), year == years[0] and month == month_keys[0]))
			var entries: Array = []
			for date: Variant in days:
				entries.append_array(days[date])
			list.add_child(_task_band("Month_" + str(month), tr("ui_records_tasks_month") % int(str(month).substr(5, 2)), entries, month_open, str(month), &"TaskMonthBand", &"Label"))
			if not month_open:
				continue
			var day_keys: Array = days.keys()
			day_keys.sort()
			day_keys.reverse()
			for date: Variant in day_keys:
				var day_label: Label = Label.new()
				day_label.name = "Day_" + str(date)
				day_label.theme_type_variation = &"CaptionLabel"
				var parts: PackedStringArray = str(date).split("-")
				day_label.text = tr("ui_records_tasks_day") % [int(parts[1]), int(parts[2]), tr("ui_weekday_%d" % TaskParts.weekday(str(date)))]
				list.add_child(day_label)
				for raw: Variant in days[date]:
					list.add_child(_done_task_row(raw as Dictionary))


func _group_entries(months: Dictionary) -> Array:
	var entries: Array = []
	for month: Variant in months:
		for date: Variant in months[month]:
			entries.append_array(months[month][date])
	return entries


# 年・月の帯（⚠ 押すと開く・畳む）：⚠ 左に「▼ 2026年」・右に「n件　◯時間」。
func _task_band(band_name: String, title: String, entries: Array, is_open: bool, key: String, panel_type: StringName, label_type: StringName) -> PanelContainer:
	var band: PanelContainer = PanelContainer.new()
	band.name = band_name
	band.theme_type_variation = panel_type
	var line: HBoxContainer = HBoxContainer.new()
	band.add_child(line)
	var head: Label = Label.new()
	head.name = "TitleLabel"
	head.theme_type_variation = label_type
	head.text = "%s %s" % [tr("ui_records_tasks_open") if is_open else tr("ui_records_tasks_closed"), title]
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(head)
	var seconds: int = 0
	for raw: Variant in entries:
		seconds += int((raw as Dictionary).get(GameStateKeys.TASK_FOCUS_SEC, 0))
	var sum: Label = Label.new()
	sum.name = "SumLabel"
	sum.theme_type_variation = label_type
	sum.text = tr("ui_records_tasks_sum") % [entries.size(), GameManager.task_focus_text(seconds)]
	line.add_child(sum)
	var _hit: Button = UiButton.attach_hit(band, _on_task_band_pressed.bind(key, is_open))
	return band


func _done_task_row(entry: Dictionary) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "DoneTask_" + str(entry.get(GameStateKeys.TASK_ID, ""))
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	line.add_child(TaskColorMark.create(int(entry.get(GameStateKeys.TASK_COLOR, 0))))
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = str(entry.get(GameStateKeys.TASK_TITLE, ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(title)
	var tag_texts: PackedStringArray = PackedStringArray()
	for tag: Variant in entry.get(GameStateKeys.TASK_TAGS, []):
		tag_texts.append(tr("ui_task_tag") % str(tag))
	if not tag_texts.is_empty():
		var tags: Label = Label.new()
		tags.name = "TagsLabel"
		tags.theme_type_variation = &"CaptionLabel"
		tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tags.text = " ".join(tag_texts)
		line.add_child(tags)
	var focus: Label = Label.new()
	focus.name = "FocusLabel"
	focus.custom_minimum_size.x = float(get_theme_constant(&"stat_width", THEME_TYPE))
	focus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus.text = GameManager.task_focus_text(int(entry.get(GameStateKeys.TASK_FOCUS_SEC, 0)))
	line.add_child(focus)
	return row


func _on_task_band_pressed(key: String, was_open: bool) -> void:
	_task_open[key] = not was_open
	# ⚠ 押した帯を押している最中に外さない（⚠ 次のフレームで描き直す）。
	_rebuild.call_deferred()


func _on_task_filter_pressed(tag: String) -> void:
	if tag == _task_filter:
		return
	_task_filter = tag
	_rebuild.call_deferred()


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)


# 入手先の窓から戻ってきたときの姿（⚠ 同じタブ）。
func _source_return_data() -> Dictionary:
	return {TransferKeys.RECORDS_TAB: _tab}
