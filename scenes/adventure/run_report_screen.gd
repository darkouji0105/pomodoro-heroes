# res://scenes/adventure/run_report_screen.gd
# 帰還報告書（2026-09-29・回UI-仕組み④・手本 DungeonResult・`docs/02_exec/EXEC_RUN_REPORT.md`）。
#
# ⚠ 人間「⚠ 1い　⚠ 2あ　⚠ 3い」：⚠ 持ち帰り・倒れた・降りた・通常の依頼のクリアで出す ／ ⚠ 最深を更新したら判。
# ⚠ 左の紙＝報告（⚠ 踏破したフロアの数・1 → n・最深 更新の判・フロアごとのボス突破・3人と「装備・レベルはそのまま」）。
# ⚠ 右の紙＝持ち帰った品（⚠ 倒れた・降りた＝失った品）・⚠ 宝箱は宝物庫へ・⚠ 消えた品・置いてきた品 ／ ⚠ 右下に「宝箱を開けに行く」「本部へ戻る」。
# ⚠ 中身は `GameManager.get_last_run_report()` を読むだけ（⚠ ここで数え直さない・状態は変えない）。
# ⚠ ランの外の画面なので scenes/adventure/（⚠ 冒険の終わり）。

class_name RunReportScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const THEME_TYPE: StringName = &"RunReport"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body

var _report: Dictionary = {}


func _ready() -> void:
	SceneManager.consume_transfer_data()
	_report = GameManager.get_last_run_report()
	if _report.is_empty():
		push_warning("[RunReport] ⚠ 報告が無い（⚠ 直接開かれた）＝本部へ")
		SceneManager.change_scene.call_deferred(BASE_PATH)
		return
	GameManager.mark_run_report_seen()
	ResourceHud.set_shown(true)
	body.add_child(_build_report())
	body.add_child(_build_items())


func _end() -> String:
	return str(_report.get(GameManager.REPORT_END, GameManager.RUN_END_RETURNED))


func _is_lost() -> bool:
	return _end() != GameManager.RUN_END_RETURNED


func _is_dungeon() -> bool:
	return str(_report.get(GameManager.REPORT_KIND, "")) == GameManager.REPORT_KIND_DUNGEON


# 塔か（2026-10-09・回D-塔）。⚠ 塔は「12 → 15 階」（⚠ 層の字は出さない・人間「⚠ ６あ」）。
func _is_tower() -> bool:
	return _is_dungeon() and GameManager.is_tower_dungeon(str(_report.get(GameManager.REPORT_TARGET_ID, "")))


# --- 左：報告 -----------------------------------------------------------

func _build_report() -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(0)
	holder.name = "ReportSheet"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Report"
	holder.sheet.add_child(column)
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "ReportHeading"
	heading.title_key = "ui_report_title_" + _end()
	heading.right_text = tr("ui_quest_tab_hard") if _is_dungeon() else tr("ui_quest_tab_normal")
	column.add_child(heading)

	var floors: int = int(_report.get(GameManager.REPORT_FLOORS, 0))
	# ⚠⚠ 難ダンジョンは層で出す（2026-10-03・決定49・手本 DungeonResult「31 → 50 層」）。
	#   ⚠ `floors` は入口から数えたフロアの番号（⚠ ボスを倒したいちばん深いもの）。⚠ このランで倒したのは `start`〜`floors`。
	var start: int = maxi(1, int(_report.get(GameManager.REPORT_START_FLOOR, 1)))
	var per_floor: int = maxi(1, int(_report.get(GameManager.REPORT_LAYERS_PER_FLOOR, 1)))
	var cleared_from: int = start if _is_dungeon() else 1
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_report_cleared_caption")
	column.add_child(caption)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "FloorLine"
	column.add_child(line)
	var big: Label = Label.new()
	big.name = "FloorsLabel"
	big.theme_type_variation = &"RunReportBigLabel"
	big.text = str(floors)
	if _is_dungeon():
		big.text = tr("ui_report_layer_span") % [(start - 1) * per_floor + 1, floors * per_floor] if floors >= start else "0"
	line.add_child(big)
	var unit: Label = Label.new()
	unit.text = tr("ui_report_tower_unit") if _is_tower() else tr("ui_report_layer_unit") if _is_dungeon() else tr("ui_report_floor_unit")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(unit)
	var range_column: VBoxContainer = VBoxContainer.new()
	range_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(range_column)
	var target: Label = Label.new()
	target.name = "TargetLabel"
	target.theme_type_variation = &"SheetHeadingLabel"
	target.text = _target_name()
	range_column.add_child(target)
	var how: Label = Label.new()
	how.name = "HowLabel"
	how.theme_type_variation = &"CaptionLabel"
	how.text = tr("ui_report_how_" + _end())
	range_column.add_child(how)
	# ⚠ 最深 更新（⚠ 人間「⚠ 2あ」）。⚠ 更新しなかったときは今の最深を小さく。
	if _is_dungeon():
		if bool(_report.get(GameManager.REPORT_BEST_UPDATED, false)):
			var best_stamp: Stamp = Stamp.new()
			best_stamp.name = "BestStamp"
			best_stamp.label_key = "ui_report_best_updated"
			best_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(best_stamp)
		else:
			var best: Label = Label.new()
			best.name = "BestLabel"
			best.theme_type_variation = &"CaptionLabel"
			best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			best.text = tr("ui_report_tower_best" if _is_tower() else "ui_report_best") % (int(_report.get(GameManager.REPORT_BEST, 0)) * per_floor)
			line.add_child(best)

	# ⚠ フロアごとのボス突破（⚠ 手本の「40層　ボス：…　突破」）。
	if floors < cleared_from:
		var none: Label = Label.new()
		none.name = "NoBossLabel"
		none.theme_type_variation = &"CaptionLabel"
		none.text = tr("ui_report_no_boss")
		column.add_child(none)
	# ⚠ 行は深いほうから `boss_rows` 本まで（2026-10-03・決定49＝1ランで何十フロアも潜れる）。⚠ 残りは1行にまとめる。
	var rows_max: int = maxi(1, get_theme_constant(&"boss_rows", THEME_TYPE))
	var shown_from: int = maxi(cleared_from, floors - rows_max + 1)
	if shown_from > cleared_from:
		var more: Label = Label.new()
		more.name = "MoreBossLabel"
		more.theme_type_variation = &"CaptionLabel"
		more.text = tr("ui_report_boss_more") % (shown_from - cleared_from)
		column.add_child(more)
	for floor_number: int in range(shown_from, floors + 1):
		var row: LedgerRow = LedgerRow.new()
		row.name = "Boss_%d" % floor_number
		row.compact = true
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var boss_line: HBoxContainer = HBoxContainer.new()
		row.add_child(boss_line)
		var floor_label: Label = Label.new()
		floor_label.theme_type_variation = &"SheetHeadingLabel"
		floor_label.custom_minimum_size.x = float(get_theme_constant(&"floor_width", THEME_TYPE))
		floor_label.text = tr("ui_report_tower_floor" if _is_tower() else "ui_report_floor") % (floor_number * per_floor) if _is_dungeon() else _target_name()
		boss_line.add_child(floor_label)
		var boss: Label = Label.new()
		boss.theme_type_variation = &"CaptionLabel"
		boss.text = tr("ui_report_boss")
		boss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		boss_line.add_child(boss)
		var stamp: Stamp = Stamp.new()
		stamp.label_key = "ui_report_boss_cleared"
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		boss_line.add_child(stamp)
		column.add_child(row)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	# 3人（⚠ 装備・レベルは失わない＝決定7）。
	var party: HBoxContainer = HBoxContainer.new()
	party.name = "Party"
	column.add_child(party)
	for raw: Variant in _report.get(GameManager.REPORT_MEMBERS, []):
		party.add_child(CharacterAvatar.create(str(raw), get_theme_constant(&"photo", THEME_TYPE)))
	var keep: Label = Label.new()
	keep.theme_type_variation = &"CaptionLabel"
	keep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keep.text = tr("ui_report_kept")
	party.add_child(keep)
	return holder


func _target_name() -> String:
	var target_id: String = str(_report.get(GameManager.REPORT_TARGET_ID, ""))
	if _is_dungeon():
		return tr(str(MasterDataLoader.get_dungeon(target_id).get("name_key", target_id)))
	return tr(str(MasterDataLoader.get_stage(target_id).get("name_key", target_id)))


# --- 右：持ち帰った品 ／ 失った品 ------------------------------------------

func _build_items() -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "ItemsSheet"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Items"
	holder.sheet.add_child(column)
	var items: Dictionary = _report.get(GameManager.REPORT_LOST if _is_lost() else GameManager.REPORT_GRANTED, {})
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "ItemsHeading"
	heading.title_key = "ui_report_items_lost" if _is_lost() else "ui_report_items_granted"
	heading.right_text = tr("ui_report_kinds") % items.size()
	column.add_child(heading)
	var cards: HFlowContainer = HFlowContainer.new()
	cards.name = "Cards"
	cards.theme_type_variation = &"RecordsCells"
	column.add_child(cards)
	var ids: Array = items.keys()
	ids.sort()
	for raw: Variant in ids:
		var item_id: String = str(raw)
		var card: VBoxContainer = VBoxContainer.new()
		card.name = "Item_" + item_id
		card.custom_minimum_size.x = float(get_theme_constant(&"card_width", THEME_TYPE))
		var icon: ItemIcon = ItemIcon.create(item_id, 0, int(items[raw]))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# ⚠ 10-07：⚠ アイコンを押しても入手先の窓。
		ItemSourceWindow.attach_to(icon, item_id)
		if _is_lost():
			icon.modulate = get_theme_color(&"lost_tint", THEME_TYPE)
		card.add_child(icon)
		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"CaptionLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.text = tr(GameManager.item_name_key(item_id))
		card.add_child(name_label)
		cards.add_child(card)
	if ids.is_empty():
		var none: Label = Label.new()
		none.name = "NoItemsLabel"
		none.theme_type_variation = &"CaptionLabel"
		none.text = tr("ui_report_no_items")
		column.add_child(none)
	column.add_child(HSeparator.new())
	# ⚠ 注記の行（⚠ 手本：宝箱は宝物庫へ ／ ランの中だけの品は置いてきた）。
	if _has_chest(items) and not _is_lost():
		column.add_child(_note("ChestNote", tr("ui_report_note_chest")))
	# ⚠ 「持ち物が満杯で置いてきた」は消した（2026-10-03・回3-d・`BS-20`＝拠点に容量は無い）。
	for spec: Array in [[GameManager.REPORT_DISCARDED, "ui_report_note_discarded"]]:
		var extra: Dictionary = _report.get(str(spec[0]), {})
		for raw: Variant in extra:
			column.add_child(_note("Note_%s_%s" % [str(spec[0]), str(raw)], tr(str(spec[1])) % [tr(GameManager.item_name_key(str(raw))), int(extra[raw])]))
	if _is_lost():
		column.add_child(_note("LostNote", tr("ui_report_note_lost")))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	# ⚠ 宝箱を持ち帰ったときだけ（⚠ 手本「宝箱を開けに行く」）。
	if _has_chest(items) and not _is_lost():
		var chest: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_report_open_chests")
		chest.name = "ChestButton"
		chest.pressed.connect(_on_chest_pressed)
		buttons.add_child(chest)
	var home: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_report_home")
	home.name = "HomeButton"
	home.pressed.connect(_on_home_pressed)
	buttons.add_child(home)
	return holder


func _has_chest(items: Dictionary) -> bool:
	for raw: Variant in items:
		if GameManager.is_chest_item(str(raw)):
			return true
	return false


func _note(note_name: String, text: String) -> Label:
	var note: Label = Label.new()
	note.name = note_name
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = text
	return note


func _on_chest_pressed() -> void:
	SceneManager.change_scene(CHEST_PATH)


func _on_home_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
