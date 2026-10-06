# res://scenes/guild/forge_screen.gd
# 鍛冶場（2026-09-27・回UI-仕組み①・手本 Forge / ForgeResult / ForgeResultFail）。
#
# ⚠ 人間「⚠ 1あ」＝画面 ＋ **失敗（`EQ-6`）と確定成功の札（`EQ-7`）**。⚠ 鍛冶のレベル（`EQ-5`）は右上の欄ごと後回し。
# ⚠ 人間「⚠ 2あ」＝作業場は「作る」タブ（⚠ いまはタブを押すと作業場の画面へ移る＝⚠ 作業場の中身はまだ作り直していない）。
# ⚠ 人間「⚠ 3あ」＝持ち物・育成の「鍛える」は、⚠ この画面をその品を選んだ状態で開く（`TransferKeys.FORGE_INSTANCE_ID`）。
# ⚠ 紙の左に鍛える装備の一覧 ／ ⚠ 右に「前 → 後・成功率・素材・札を使う・鍛える」。⚠ 右の列に札の数と「持ち物を見る」。
# ⚠⚠ 鍛えると**結果の画面**（⚠ 手本 ForgeResult / ForgeResultFail）：⚠ タブと一覧を消し、紙いっぱいに「鍛冶の記録」
#   （⚠ 前 → いま・成功／失敗の判・値・等級・使った素材）／ ⚠ 右に「続けて鍛える（失敗は もう一度鍛える）」「持ち物で見る」。
#   ⚠ 09-27 は紙の窓だった → ⚠ 09-28 人間「⚠ 鍛冶の演出は、これも専用画面がいる」。⚠ 「戻る」は鍛える紙へ戻る。
#   ⚠ 「続けて鍛える」「もう一度鍛える」は**その場でもう一度鍛える**（⚠ 09-28 人間「⚠ 続けて鍛えるで元の画面に戻らないで」）。
#   ⚠ 鍛えるたびに**演出の画面**（`ForgeStrike`＝金床を槌で打つ）を被せ、⚠ 終わってから結果の画面（⚠ 09-28 人間「⚠ 別の画面でやる」）。
#   ⚠ 成功＝判が大きく押されて紙いっぱいが金に光り、⚠ 新しい絵がふくらむ ／ ⚠ 失敗＝紙が暗く沈んで震え、⚠ 絵が灰色になる
#   （⚠ 値は Theme の `Forge` 型）。⚠ 鍛冶の腕（`EQ-5`）と失敗の一言（手本の吹き出し）はまだ無い。
# ⚠ 判定と状態の変更は `GameManager.forge_equipment_roll()` の1本（⚠ ここで成功率や費用を計算しない）。
# ⚠ 素材は今の費用の形（⚠ 等級ごとに1種類）。⚠ 手本の「素材2つ」には合わせていない（⚠ 費用の器を変えないため）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 画面は自分の操作のあとに自分で描き直す（⚠ シグナルは購読しない）。

class_name ForgeScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"
const BELONGINGS_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const FORGE_PATH: String = "res://scenes/guild/forge_screen.tscn"
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
@onready var sheet: PaperSheet = $Margin/Layout/Body/Main/Sheet

var _selected: String = ""
var _use_token: bool = false
# ⚠ 空でなければ結果の画面（⚠ `forge_equipment_roll()` の戻り値 ＋ 前の値）。
var _result: Dictionary = {}
var _tabs: PaperTabs = null


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_selected = str(data.get(TransferKeys.FORGE_INSTANCE_ID, ""))
	header.back_pressed.connect(_on_back_pressed)
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに（⚠ 本部の右上の素材16件はやめた）。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX))
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.FORGE)
	side.custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
	var tabs: PaperTabs = PaperTabs.new()
	tabs.name = "Tabs"
	# ⚠ 「作る」（作業場）は作業場を解放してから（⚠ 09-28・鍛冶場は持ち物と同じ解放で帯に出る）。
	var keys: Array[String] = TAB_KEYS.duplicate()
	if not GameManager.is_screen_unlocked(GameStateKeys.SCREEN_WORKSHOP):
		keys = [TAB_KEYS[0]]
	tabs.set_tabs(keys, 0)
	tabs.tab_changed.connect(_on_tab_changed)
	main_stack.add_child(tabs)
	main_stack.move_child(tabs, 0)
	_tabs = tabs
	_rebuild()


func _on_tab_changed(index: int) -> void:
	if index == TAB_MAKE:
		SceneManager.swap_scene(WORKSHOP_PATH)


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _rebuild() -> void:
	_clear(sheet_body)
	_clear(side)
	var showing: bool = not _result.is_empty()
	_tabs.visible = not showing
	header.set_subtitle_text(tr("ui_forge_result_subtitle") if showing else "")
	if showing:
		sheet_body.add_child(_build_record(_result))
		_build_side_result()
		return
	var views: Array = GameManager.get_owned_instances()
	if _selected == "" or GameManager.get_equipment_instance(_selected).is_empty():
		_selected = str((views[0] as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) if not views.is_empty() else ""
	sheet_body.add_child(_build_list(views))
	sheet_body.add_child(VSeparator.new())
	sheet_body.add_child(_build_forge_page())
	_build_side_forge()


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
		# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓（⚠ 行った先の「戻る」でこの品を選んだ鍛冶場へ戻る）。
		# ⚠ 紙の上なので紙の札（⚠ Ghost は紙の上で読めない＝撮った絵）。
		var source: Button = UiButton.create_paper_choice("ui_source_open")
		source.name = "SourceButton"
		source.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		source.pressed.connect(ItemSourceWindow.open.bind(self, material_id, amount, {TransferKeys.FORGE_INSTANCE_ID: _selected}))
		line.add_child(source)
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
	_use_token = false
	# ⚠ 鍛える演出の画面を被せ、⚠ 終わってから結果の画面（⚠ 09-28 人間「⚠ 鍛冶場で鍛えるとき、演出を入れたい　⚠ 別の画面でやる」）。
	#   ⚠ 状態はもう変わっている（⚠ 演出は見せるだけ）。⚠ 結果の判の演出は結果の画面を出したときに流れる。
	var item_id: String = str(GameManager.get_equipment_instance(_selected).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var strike: ForgeStrike = ForgeStrike.play(self, item_id, int(result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1)),
		bool(result.get(GameManager.FORGE_RESULT_SUCCESS, false)))
	strike.finished.connect(_show_result.bind(result))


func _show_result(result: Dictionary) -> void:
	if not is_inside_tree():
		return
	_result = result
	_rebuild()


# 結果の画面から鍛える紙へ戻る（⚠ 「続けて鍛える」「戻る」）。⚠ 選んでいる品はそのまま。
func _leave_result() -> void:
	_result = {}
	_rebuild()


# --- 鍛冶の記録（⚠ 結果の画面の紙・09-28 人間「⚠ これも専用画面がいる」） ---------------

func _build_record(result: Dictionary) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "RecordPage"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_forge_record"
	heading.centered = true
	heading.ornament_below = true
	page.add_child(heading)
	var instance: Dictionary = GameManager.get_equipment_instance(_selected)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var success: bool = bool(result.get(GameManager.FORGE_RESULT_SUCCESS, false))
	var grade_before: int = int(result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1))
	var grade_after: int = int(result.get(GameManager.FORGE_RESULT_GRADE_AFTER, 1))

	var arrow_row: HBoxContainer = HBoxContainer.new()
	arrow_row.name = "ArrowRow"
	arrow_row.theme_type_variation = &"ForgeArrowRow"
	arrow_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(arrow_row)
	arrow_row.add_child(_icon_with_caption(item_id, grade_before, tr("ui_forge_before"), &"CaptionLabel"))
	arrow_row.add_child(_arrow())
	var now: VBoxContainer = _icon_with_caption(item_id, grade_after, tr("ui_forge_now"), &"CaptionLabel")
	now.name = "NowIcon"
	arrow_row.add_child(now)
	# ⚠ 判は器（素の Control）に入れる（⚠ `Container` は子の位置と大きさを毎回戻す＝震えと大きさの演出が効かない）。
	var seal_holder: Control = Control.new()
	seal_holder.name = "SealHolder"
	seal_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow_row.add_child(seal_holder)
	var seal: Stamp = Stamp.new()
	seal.name = "ResultStamp"
	seal.shape = Stamp.Shape.CIRCLE
	seal.label_key = "ui_forge_success" if success else "ui_forge_fail"
	seal_holder.add_child(seal)
	seal.ready.connect(_play_record_fx.bind(seal_holder, seal, now, success))

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tr(GameManager.item_name_key(item_id))
	page.add_child(name_label)

	# 値。
	var before: Dictionary = result.get(RESULT_STATS_BEFORE, {})
	var after: Dictionary = GameManager.get_instance_stats(_selected)
	var stat_key: String = _main_stat(before)
	var value_before: String = _value_text(stat_key, before)
	var value_after: String = _value_text(stat_key, after)
	var diff: int = int(after.get(stat_key, 0)) - int(before.get(stat_key, 0))
	page.add_child(_record_row("StatRow", tr("ui_training_stat_" + stat_key) if stat_key != "" else "",
		value_before + (" → " + value_after if success else ""),
		("+%d" % diff) if success and diff > 0 else tr("ui_forge_unchanged"), success and diff > 0))
	# 等級（⚠ 失敗しても下がらない＝`EQ-6`）。
	var slots_before: int = int(result.get(RESULT_SLOTS_BEFORE, 0))
	var slots_after: int = GameManager.get_part_entries(_selected).size()
	var grade_note: String = tr("ui_forge_not_lowered")
	if success:
		grade_note = tr("ui_forge_slot_opened") if slots_after > slots_before else ""
	page.add_child(_record_row("GradeRow", tr("ui_forge_grade"),
		"%d → %d" % [grade_before, grade_after] if success else str(grade_before), grade_note, success))
	# 使った素材（⚠ 失敗しても払う＝`EQ-6`）。
	var used: HBoxContainer = HBoxContainer.new()
	used.add_child(ItemIcon.create(str(result.get(GameManager.FORGE_RESULT_MATERIAL_ID, "")), 0,
		int(result.get(GameManager.FORGE_RESULT_AMOUNT, 0))))
	if bool(result.get(GameManager.FORGE_RESULT_USED_TOKEN, false)):
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


# 結果の画面の右の列（⚠ 手本：下に「続けて鍛える」「持ち物で見る」）。
func _build_side_result() -> void:
	_add_side_spacer()
	var success: bool = bool(_result.get(GameManager.FORGE_RESULT_SUCCESS, false))
	# ⚠ 押すと**その場でもう一度鍛える**（⚠ 09-28 人間「⚠ 続けて鍛えるで元の画面に戻らないで」）。⚠ 札は使わない（⚠ 使うなら「戻る」で鍛える紙から）。
	var grade: int = int(GameManager.get_equipment_instance(_selected).get(GameStateKeys.INSTANCE_GRADE, 1))
	var cost: Dictionary = GameManager.get_forge_cost(_selected)
	var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	var at_max: bool = grade >= GameManager.get_max_equipment_grade()
	var again: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_forge_continue" if success else "ui_forge_retry")
	again.name = "ContinueButton"
	again.disabled = at_max or owned < amount
	again.pressed.connect(_on_forge_pressed)
	side.add_child(again)
	if again.disabled:
		# ⚠ 押せない理由（⚠ 最大の等級 ／ 素材が足りない）。
		var reason: Label = Label.new()
		reason.name = "ContinueReason"
		reason.theme_type_variation = &"CaptionLabel" if at_max else &"ErrorLabel"
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason.text = tr("ui_forge_reject_max") if at_max else "%s %s" % [tr("ui_res_" + material_id), tr("ui_forge_need") % [amount, owned]]
		side.add_child(reason)
	var belongings: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_forge_to_belongings")
	belongings.name = "BelongingsButton"
	belongings.pressed.connect(_on_belongings_pressed)
	side.add_child(belongings)


func _add_side_spacer() -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(spacer)


func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


# 記録の演出（⚠ 人間「⚠ 個別の演出を」「⚠ 専用画面がいる」）。⚠ Tween は判・絵・光に結びつける（⚠ 画面を離れれば一緒に止まる）。
#   ⚠ 成功：判が大きく現れて押し付けられ、⚠ 紙いっぱいが金に光り、⚠ 新しい絵が一度ふくらんで光る。
#   ⚠ 失敗：判が押し付けられて左右に震え、⚠ 紙が暗く沈んで紙ごと震え、⚠ 新しい絵（＝前と同じ）が灰色に沈む。
func _play_record_fx(holder: Control, seal: Stamp, now: Control, success: bool) -> void:
	var final_scale: float = float(get_theme_constant(&"fx_seal_scale_pct", THEME_TYPE)) / 100.0
	seal.size = seal.custom_minimum_size
	holder.custom_minimum_size = seal.custom_minimum_size * final_scale
	seal.position = (holder.custom_minimum_size - seal.size) * 0.5
	seal.pivot_offset = seal.size * 0.5
	var delay: float = float(get_theme_constant(&"fx_delay_ms", THEME_TYPE)) / 1000.0
	var slam: float = float(get_theme_constant(&"fx_slam_ms", THEME_TYPE)) / 1000.0
	var from_scale: float = float(get_theme_constant(&"fx_slam_scale_pct", THEME_TYPE)) / 100.0
	seal.scale = Vector2.ONE * from_scale
	seal.modulate.a = 0.0
	var tween: Tween = seal.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(seal, "modulate:a", 1.0, slam)
	tween.parallel().tween_property(seal, "scale", Vector2.ONE * final_scale, slam).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var after: float = float(get_theme_constant(&"fx_after_ms", THEME_TYPE)) / 1000.0
	_flash_sheet(delay + slam, success)
	if not success:
		_shake_sheet(delay + slam, after)
	var icon_tween: Tween = now.create_tween()
	icon_tween.tween_interval(delay + slam)
	# ⚠ 窓が並べ終わってから中心を合わせる（⚠ いまは大きさが 0 のことがある）。
	icon_tween.tween_callback(_center_pivot.bind(now))
	if success:
		var pulse: float = float(get_theme_constant(&"fx_pulse_pct", THEME_TYPE)) / 100.0
		icon_tween.tween_property(now, "scale", Vector2.ONE * pulse, after * 0.5)
		icon_tween.parallel().tween_property(now, "modulate", get_theme_color(&"fx_glow", THEME_TYPE), after * 0.5)
		icon_tween.tween_property(now, "scale", Vector2.ONE, after * 0.5)
		icon_tween.parallel().tween_property(now, "modulate", Color.WHITE, after * 0.5)
	else:
		var shake: float = float(get_theme_constant(&"fx_shake_px", THEME_TYPE))
		var steps: int = get_theme_constant(&"fx_shake_steps", THEME_TYPE)
		for i: int in range(steps):
			var offset: float = shake * (1.0 - float(i) / float(steps)) * (1.0 if i % 2 == 0 else -1.0)
			tween.tween_property(seal, "position:x", offset, after / float(steps))
		tween.tween_property(seal, "position:x", 0.0, after / float(steps))
		icon_tween.tween_property(now, "modulate", get_theme_color(&"fx_dim", THEME_TYPE), after)


# 判が押された瞬間に紙いっぱいを光らせる（⚠ 成功＝金 ／ 失敗＝暗く沈む）。⚠ 光は紙の子＝紙いっぱいに敷かれ、⚠ 消えたら自分で外れる。
func _flash_sheet(at: float, success: bool) -> void:
	var flash: ColorRect = ColorRect.new()
	flash.name = "RecordFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = get_theme_color(&"fx_flash" if success else &"fx_flash_fail", THEME_TYPE)
	flash.modulate.a = 0.0
	sheet.add_child(flash)
	var tween: Tween = flash.create_tween()
	tween.tween_interval(at)
	tween.tween_property(flash, "modulate:a", 1.0, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, float(get_theme_constant(&"fx_flash_ms", THEME_TYPE)) / 1000.0)
	tween.tween_callback(flash.queue_free)


# 紙ごと左右に震わせる（⚠ 相対で動かす＝最後は元の位置）。
func _shake_sheet(at: float, duration: float) -> void:
	var shake: float = float(get_theme_constant(&"fx_sheet_shake_px", THEME_TYPE))
	var steps: int = get_theme_constant(&"fx_shake_steps", THEME_TYPE)
	var tween: Tween = sheet.create_tween()
	tween.tween_interval(at)
	var last: float = 0.0
	for i: int in range(steps + 1):
		var offset: float = 0.0 if i == steps else shake * (1.0 - float(i) / float(steps)) * (1.0 if i % 2 == 0 else -1.0)
		tween.tween_property(sheet, "position:x", offset - last, duration / float(steps + 1)).as_relative()
		last = offset


# ⚠ 10-06（`NAV-18`）：⚠ 寄り道＝持ち物の「戻る」でこの品を選んだ鍛冶場へ。
func _on_belongings_pressed() -> void:
	SceneManager.open_detour(BELONGINGS_PATH, {TransferKeys.WAREHOUSE_INSTANCE_ID: _selected},
		FORGE_PATH, {TransferKeys.FORGE_INSTANCE_ID: _selected})


func _on_back_pressed() -> void:
	if not _result.is_empty():
		_leave_result()
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
