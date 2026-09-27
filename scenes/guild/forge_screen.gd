# res://scenes/guild/forge_screen.gd
# 鍛冶場（2026-09-27・回UI-仕組み①・手本 Forge / ForgeResult / ForgeResultFail）。
#
# ⚠ 人間「⚠ 1あ」＝画面 ＋ **失敗（`EQ-6`）と確定成功の札（`EQ-7`）**。⚠ 鍛冶のレベル（`EQ-5`）は右上の欄ごと後回し。
# ⚠ 人間「⚠ 2あ」＝作業場は「作る」タブ（⚠ いまはタブを押すと作業場の画面へ移る＝⚠ 作業場の中身はまだ作り直していない）。
# ⚠ 人間「⚠ 3あ」＝持ち物・育成の「鍛える」は、⚠ この画面をその品を選んだ状態で開く（`TransferKeys.FORGE_INSTANCE_ID`）。
# ⚠ 紙の左に鍛える装備の一覧 ／ ⚠ 右に「前 → 後・成功率・素材・札を使う・鍛える」。⚠ 右の列に札の数と「持ち物を見る」。
# ⚠ 鍛えると紙が「鍛冶の記録」に変わる（⚠ 前 → いま・成功／失敗の判・値・等級・使った素材）。⚠ 別の画面にはしない（⚠ 昇級申請書と同じ流れ）。
# ⚠ 判定と状態の変更は `GameManager.forge_equipment_roll()` の1本（⚠ ここで成功率や費用を計算しない）。
# ⚠ 素材は今の費用の形（⚠ 等級ごとに1種類）。⚠ 手本の「素材2つ」には合わせていない（⚠ 費用の器を変えないため）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 画面は自分の操作のあとに自分で描き直す（⚠ シグナルは購読しない）。

class_name ForgeScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"
const BELONGINGS_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const THEME_TYPE: StringName = &"Forge"
const TAB_KEYS: Array[String] = ["ui_forge_tab_forge", "ui_forge_tab_make"]
const TAB_MAKE: int = 1
# ⚠ 鍛えたあとの記録に、⚠ 鍛える前の値を持ち越す（⚠ `forge_equipment_roll()` の戻り値に足す字）。
const RESULT_STATS_BEFORE: String = "stats_before"
const RESULT_SLOTS_BEFORE: String = "slots_before"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Body/Main
@onready var sheet_body: HBoxContainer = $Margin/Layout/Body/Main/Sheet/SheetBody
@onready var side: VBoxContainer = $Margin/Layout/Body/Side

var _selected: String = ""
# ⚠ 空なら「鍛える」の紙 ／ ⚠ 中身があれば「鍛冶の記録」の紙。
var _result: Dictionary = {}
var _use_token: bool = false


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_selected = str(data.get(TransferKeys.FORGE_INSTANCE_ID, ""))
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.FORGE)
	side.custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
	var tabs: PaperTabs = PaperTabs.new()
	tabs.name = "Tabs"
	tabs.set_tabs(TAB_KEYS, 0)
	tabs.tab_changed.connect(_on_tab_changed)
	main_stack.add_child(tabs)
	main_stack.move_child(tabs, 0)
	_rebuild()


func _on_tab_changed(index: int) -> void:
	if index == TAB_MAKE:
		SceneManager.change_scene(WORKSHOP_PATH)


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	_clear(sheet_body)
	_clear(side)
	var views: Array = GameManager.get_owned_instances()
	if _selected == "" or GameManager.get_equipment_instance(_selected).is_empty():
		_selected = str((views[0] as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) if not views.is_empty() else ""
	if _result.is_empty():
		sheet_body.add_child(_build_list(views))
		sheet_body.add_child(VSeparator.new())
		sheet_body.add_child(_build_forge_page())
		_build_side_forge()
	else:
		sheet_body.add_child(_build_record())
		_build_side_record()


# --- 左：鍛える装備 -----------------------------------------------------

func _build_list(views: Array) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "List"
	column.custom_minimum_size.x = float(get_theme_constant(&"list_width", THEME_TYPE))
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_forge_list")
	column.add_child(caption)
	column.add_child(HSeparator.new())
	if views.is_empty():
		column.add_child(EmptyState.create("ui_forge_no_equipment", "ui_forge_no_equipment_hint"))
		return column
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for raw: Variant in views:
		var view: Dictionary = raw
		var instance_id: String = str(view.get(GameManager.INSTANCE_VIEW_ID, ""))
		var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		var row: LedgerRow = LedgerRow.new()
		row.name = "Item_" + instance_id
		row.compact = true
		row.selected = instance_id == _selected
		row.pressed.connect(_on_item_pressed.bind(instance_id))
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		line.add_child(ItemIcon.create(item_id, int(view.get(GameStateKeys.INSTANCE_GRADE, 1))))
		var name_label: Label = Label.new()
		name_label.text = tr(GameManager.item_name_key(item_id))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name_label)
		rows.add_child(row)
	return column


func _on_item_pressed(instance_id: String) -> void:
	_selected = instance_id
	_use_token = false
	_rebuild()


# --- 右：鍛える（前 → 後・成功率・素材・札） -------------------------------

func _build_forge_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "ForgePage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _selected == "":
		return page
	var instance: Dictionary = GameManager.get_equipment_instance(_selected)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	var at_max: bool = grade >= GameManager.get_max_equipment_grade()

	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr(GameManager.item_name_key(item_id))
	page.add_child(heading)

	var before: Dictionary = GameManager.get_instance_stats(_selected)
	var stat_key: String = _main_stat(before)
	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.name = "ArrowRow"
	arrow_row.theme_type_variation = &"ForgeArrowRow"
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(arrow_row)
	arrow_row.add_child(_icon_with_caption(item_id, grade, _stat_text(stat_key, before), &""))
	var pct: int = GameManager.get_forge_success_pct(_selected)
	if at_max:
		var done: Label = Label.new()
		done.name = "MaxLabel"
		done.theme_type_variation = &"CaptionLabel"
		done.text = tr("ui_forge_reject_max")
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow_row.add_child(done)
	else:
		arrow_row.add_child(_arrow())
		var after: Dictionary = GameManager.get_instance_stats_at_grade(_selected, grade + 1)
		arrow_row.add_child(_icon_with_caption(item_id, grade + 1, _stat_text(stat_key, after), &"GainLabel"))
		var chance: Label = Label.new()
		chance.name = "ChanceLabel"
		# ⚠ 必ず成功する段は緑、⚠ 失敗しうる段は強調（⚠ 札を使うなら緑）。
		chance.theme_type_variation = &"GainLabel" if (pct >= 100 or _use_token) else &"AccentLabel"
		chance.text = tr("ui_forge_chance") % (100 if _use_token else pct)
		chance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow_row.add_child(chance)

	# 素材（⚠ 等級ごとに1種類）。
	var cost: Dictionary = GameManager.get_forge_cost(_selected)
	var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	if not at_max:
		var cost_row: LedgerRow = LedgerRow.new()
		cost_row.name = "CostRow"
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line: HBoxContainer = HBoxContainer.new()
		cost_row.add_child(line)
		line.add_child(ItemIcon.create(material_id))
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

		# 確定成功の札（`EQ-7`）。⚠ 必ず成功する段・札が無いときは押せない。
		var tokens: int = GameManager.get_forge_token_count()
		var token_row: HBoxContainer = HBoxContainer.new()
		token_row.name = "TokenRow"
		# ⚠ `CheckBox` にしない（⚠ 紙のテーマは字の型しか持たない＝⚠ 字が明るいまま紙の上で読めない）。⚠ 紙の上の札で切り替える。
		var check: Button = UiButton.create_paper_choice("ui_forge_use_token")
		check.name = "TokenCheck"
		check.disabled = tokens <= 0 or pct >= 100
		if _use_token and not check.disabled:
			check.theme_type_variation = &"PaperChoiceSelected"
			check.text = tr("ui_forge_use_token_on")
		check.pressed.connect(_on_token_toggled.bind(not _use_token))
		token_row.add_child(check)
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token_row.add_child(gap)
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

	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	page.add_child(foot)
	var note: Label = Label.new()
	note.name = "NoteLabel"
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.text = tr("ui_forge_note")
	foot.add_child(note)
	var forge: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_forge_do")
	forge.name = "ForgeButton"
	forge.disabled = at_max or owned < amount
	forge.pressed.connect(_on_forge_pressed)
	foot.add_child(forge)
	return page


func _on_token_toggled(pressed: bool) -> void:
	_use_token = pressed
	_rebuild()


# 鍛える。⚠ 判定と乱数は `forge_equipment_roll()`。⚠ 前の値を控えてから呼ぶ（⚠ 記録に出す）。
func _on_forge_pressed() -> void:
	var stats_before: Dictionary = GameManager.get_instance_stats(_selected)
	var slots_before: int = GameManager.get_part_entries(_selected).size()
	var result: Dictionary = GameManager.forge_equipment_roll(_selected, _use_token)
	if not bool(result.get(GameManager.FORGE_RESULT_OK, false)):
		# ⚠ 押せない形にしてあるので来ないはず（⚠ 来たら理由を出す）。
		push_warning("[ForgeScreen] 鍛えられなかった: " + str(result.get(GameManager.FORGE_RESULT_REASON, "")))
		_rebuild()
		return
	result[RESULT_STATS_BEFORE] = stats_before
	result[RESULT_SLOTS_BEFORE] = slots_before
	_result = result
	_use_token = false
	_rebuild()


# --- 鍛冶の記録（鍛えたあと） ---------------------------------------------

func _build_record() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "RecordPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var instance: Dictionary = GameManager.get_equipment_instance(_selected)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var success: bool = bool(_result.get(GameManager.FORGE_RESULT_SUCCESS, false))
	var grade_before: int = int(_result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1))
	var grade_after: int = int(_result.get(GameManager.FORGE_RESULT_GRADE_AFTER, 1))

	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_forge_record"
	heading.ornament = true
	heading.ornament_below = true
	heading.centered = true
	page.add_child(heading)

	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.name = "ArrowRow"
	arrow_row.theme_type_variation = &"ForgeArrowRow"
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(arrow_row)
	arrow_row.add_child(_icon_with_caption(item_id, grade_before, tr("ui_forge_before"), &"CaptionLabel"))
	arrow_row.add_child(_arrow())
	arrow_row.add_child(_icon_with_caption(item_id, grade_after, tr("ui_forge_now"), &"CaptionLabel"))
	var seal: Stamp = Stamp.new()
	seal.name = "ResultStamp"
	seal.shape = Stamp.Shape.CIRCLE
	seal.label_key = "ui_forge_success" if success else "ui_forge_fail"
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow_row.add_child(seal)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tr(GameManager.item_name_key(item_id))
	page.add_child(name_label)

	# 値。
	var before: Dictionary = _result.get(RESULT_STATS_BEFORE, {})
	var after: Dictionary = GameManager.get_instance_stats(_selected)
	var stat_key: String = _main_stat(before)
	var value_before: String = _value_text(stat_key, before)
	var value_after: String = _value_text(stat_key, after)
	var diff: int = int(after.get(stat_key, 0)) - int(before.get(stat_key, 0))
	page.add_child(_record_row("StatRow", tr("ui_training_stat_" + stat_key) if stat_key != "" else "",
		value_before + (" → " + value_after if success else ""),
		("+%d" % diff) if success and diff > 0 else tr("ui_forge_unchanged"), success and diff > 0))
	# 等級（⚠ 失敗しても下がらない＝`EQ-6`）。
	var slots_before: int = int(_result.get(RESULT_SLOTS_BEFORE, 0))
	var slots_after: int = GameManager.get_part_entries(_selected).size()
	var grade_note: String = tr("ui_forge_not_lowered")
	if success:
		grade_note = tr("ui_forge_slot_opened") if slots_after > slots_before else ""
	page.add_child(_record_row("GradeRow", tr("ui_forge_grade"),
		"%d → %d" % [grade_before, grade_after] if success else str(grade_before), grade_note, success))
	# 使った素材（⚠ 失敗しても払う＝`EQ-6`）。
	var used: HBoxContainer = HBoxContainer.new()
	used.add_child(ItemIcon.create(str(_result.get(GameManager.FORGE_RESULT_MATERIAL_ID, "")), 0,
		int(_result.get(GameManager.FORGE_RESULT_AMOUNT, 0))))
	if bool(_result.get(GameManager.FORGE_RESULT_USED_TOKEN, false)):
		used.add_child(ItemIcon.create(GameStateKeys.ITEM_FORGE_GUARANTEE_TOKEN, 0, 1))
	page.add_child(_record_row("UsedRow", tr("ui_forge_used"), "", "" if success else tr("ui_forge_lost"), false, used))
	return page


# 記録の1行：左の見出し ／ 中身（字か絵）／ 右の小さな注記。
func _record_row(row_name: String, caption_text: String, value_text: String, note_text: String, gain: bool, content: Control = null) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.custom_minimum_size.x = float(get_theme_constant(&"list_width", THEME_TYPE)) * 0.4
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	if content != null:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(content)
	else:
		var value: Label = Label.new()
		value.name = "ValueLabel"
		value.theme_type_variation = &"SheetHeadingLabel"
		value.text = value_text
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(value)
	var note: Label = Label.new()
	note.name = "NoteLabel"
	note.theme_type_variation = &"GainLabel" if gain else &"CaptionLabel"
	note.text = note_text
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(note)
	return row


# --- 右の列 ------------------------------------------------------------

func _build_side_forge() -> void:
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "TokenSheet"
	var line: HBoxContainer = HBoxContainer.new()
	holder.sheet.add_child(line)
	line.add_child(ItemIcon.create(GameStateKeys.ITEM_FORGE_GUARANTEE_TOKEN))
	var label: Label = Label.new()
	label.text = tr("ui_res_" + GameStateKeys.ITEM_FORGE_GUARANTEE_TOKEN)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	var count: Label = Label.new()
	count.name = "TokenCount"
	count.theme_type_variation = &"DossierLevelLabel"
	count.text = str(GameManager.get_forge_token_count())
	line.add_child(count)
	side.add_child(holder)
	_add_side_spacer()
	var belongings: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_forge_to_belongings")
	belongings.name = "BelongingsButton"
	belongings.disabled = _selected == ""
	belongings.pressed.connect(_on_belongings_pressed)
	side.add_child(belongings)


func _build_side_record() -> void:
	_add_side_spacer()
	var success: bool = bool(_result.get(GameManager.FORGE_RESULT_SUCCESS, false))
	var again: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_forge_again" if success else "ui_forge_retry")
	again.name = "AgainButton"
	again.pressed.connect(_on_again_pressed)
	side.add_child(again)
	var belongings: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_forge_to_belongings")
	belongings.name = "BelongingsButton"
	belongings.pressed.connect(_on_belongings_pressed)
	side.add_child(belongings)


func _add_side_spacer() -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(spacer)


func _on_again_pressed() -> void:
	_result = {}
	_rebuild()


func _on_belongings_pressed() -> void:
	SceneManager.change_scene_with_data(BELONGINGS_PATH, {TransferKeys.WAREHOUSE_INSTANCE_ID: _selected})


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)


# --- 小さい道具 ----------------------------------------------------------

func _arrow() -> Label:
	var arrow: Label = Label.new()
	arrow.theme_type_variation = &"LevelArrowLabel"
	arrow.text = tr("ui_forge_arrow")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return arrow


# 絵（⚠ 等級つき）＋ 下の1行。
func _icon_with_caption(item_id: String, grade: int, caption: String, variation: StringName) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon: ItemIcon = ItemIcon.create(item_id, grade)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = caption
	column.add_child(label)
	return column


# ⚠ 出す値は1つ（⚠ 手本「HP +160」）。⚠ 絶対値の一番大きい軸（⚠ 伸ばす軸と下げる軸が対になる＝`EQ-3`）。
func _main_stat(stats: Dictionary) -> String:
	var best: String = ""
	var best_value: int = 0
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = absi(int(stats.get(stat_key, 0)))
		if value > best_value:
			best = stat_key
			best_value = value
	return best


# 「HP +160」。
func _stat_text(stat_key: String, stats: Dictionary) -> String:
	if stat_key == "":
		return ""
	var value: int = int(stats.get(stat_key, 0))
	return "%s %s%s" % [tr("ui_training_stat_" + stat_key), "+" if value >= 0 else "", _value_text(stat_key, stats)]


func _value_text(stat_key: String, stats: Dictionary) -> String:
	if stat_key == "":
		return ""
	var value: int = int(stats.get(stat_key, 0))
	return "%d%%" % value if GameManager.is_percent_stat(stat_key) else str(value)
