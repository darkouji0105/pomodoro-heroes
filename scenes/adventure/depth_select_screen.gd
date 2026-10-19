class_name DepthSelectScreen
extends Control

# 難ダンジョンの「潜る深さ」を選ぶ画面（2026-10-19・回SEE29-E・決定 `NAV-38`）。
#
# ⚠ 人間「⚠ 狭い　深さを選ぶ画面に分ける1っ回画面を挟む」（⚠ 出撃の準備で「潜る深さ」に押されて名簿が1段しか見えなかった）。
# ⚠ 流れ：⚠ 依頼掲示板の「この依頼で出撃」→ ⚠ この画面 → ⚠ 「この深さで出撃の準備へ」→ 出撃の準備（⚠ 準備には「◯層から」の小さい札だけ）。
#   ⚠ 「戻る」＝依頼掲示板 ／ ⚠ 出撃の準備の「戻る」・「深さを変える」＝この画面（⚠ 選んでいた深さのまま）。
# ⚠ 塔は選べない（`DG-3`）＝この画面を通らない ／ ⚠ 「すぐ出撃」も通らない（⚠ いちばん深い所から＝準備の札で変えられる）。
# ⚠ 中身は前の出撃の準備の「潜る深さ」の紙をそのまま移した（⚠ 縦図・◯層から・次の出口・出るものの下限・−10／+10／最深へ）。
#   ⚠ 選べる深さの判定は GameManager の1本（`get_dungeon_start_floor_options()`）。⚠ 画面は番号を持つだけ。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。

const THEME_TYPE: StringName = &"Sortie"
const SORTIE_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"
const BOARD_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const SCENE_PATH: String = "res://scenes/adventure/depth_select_screen.tscn"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: CenterContainer = $Margin/Layout/Body

var _dungeon_id: String = ""
var _start_floor: int = 0
var _column: VBoxContainer = null


# ⚠ 開く口（⚠ 掲示板・出撃の準備の「戻る」と「深さを変える」）。
static func open(dungeon_id: String, start_floor: int) -> void:
	SceneManager.change_scene_with_data(SCENE_PATH, {
		TransferKeys.SORTIE_DUNGEON_ID: dungeon_id,
		TransferKeys.SORTIE_START_FLOOR: start_floor,
	})


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_dungeon_id = str(data.get(TransferKeys.SORTIE_DUNGEON_ID, ""))
	_start_floor = int(data.get(TransferKeys.SORTIE_START_FLOOR, 0))
	header.back_pressed.connect(_on_back_pressed)
	header.set_subtitle_text(tr(str(MasterDataLoader.get_dungeon(_dungeon_id).get("name_key", _dungeon_id))))
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.theme_type_variation = &"SectionStack"
	_column.custom_minimum_size.x = float(get_theme_constant(&"depth_screen_width", THEME_TYPE))
	body.add_child(_column)
	_rebuild()


# ⚠ いま選んでいる入るフロア（⚠ 0 なら最深の次）。⚠ 出撃の準備と同じ決め方（`chosen_start_floor()`）。
static func chosen_start_floor(dungeon_id: String, start_floor: int) -> int:
	var options: Array[int] = GameManager.get_dungeon_start_floor_options(dungeon_id)
	if options.is_empty():
		return 1
	if start_floor in options:
		return start_floor
	return options[options.size() - 1]


func current_start_floor() -> int:
	return chosen_start_floor(_dungeon_id, _start_floor)


func _rebuild() -> void:
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_column.add_child(_build_depth_sheet())
	var go: Button = Button.new()
	go.name = "ToSortieButton"
	go.theme_type_variation = &"DeskBigButton"
	go.text = tr("ui_depth_to_sortie") % ((current_start_floor() - 1) * GameManager.get_dungeon_layers_per_floor(_dungeon_id) + 1)
	go.focus_mode = Control.FOCUS_NONE
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(_on_to_sortie_pressed)
	_column.add_child(go)


func _build_depth_sheet() -> TiltedSheet:
	var options: Array[int] = GameManager.get_dungeon_start_floor_options(_dungeon_id)
	var chosen: int = current_start_floor()
	var per_floor: int = GameManager.get_dungeon_layers_per_floor(_dungeon_id)
	var first_layer: int = (chosen - 1) * per_floor + 1
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "Depth"
	holder.sheet.theme_type_variation = &"SortiePaperPanel"
	var sheet_body: VBoxContainer = VBoxContainer.new()
	holder.sheet.add_child(sheet_body)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_depth_title"
	heading.right_text = tr("ui_depth_step") % per_floor
	sheet_body.add_child(heading)
	var row: HBoxContainer = HBoxContainer.new()
	sheet_body.add_child(row)
	var gauge: DepthGauge = DepthGauge.new()
	gauge.name = "DepthGauge"
	gauge.max_floors = GameManager.get_dungeon_max_floors()
	gauge.layers_per_floor = per_floor
	gauge.best_floor = GameManager.get_dungeon_best_floors(_dungeon_id)
	gauge.deepest_start = options[options.size() - 1] if not options.is_empty() else 1
	gauge.start_floor = chosen
	gauge.floor_picked.connect(_on_depth_picked)
	row.add_child(gauge)
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var from: Label = Label.new()
	from.name = "FromExitLabel"
	from.theme_type_variation = &"CaptionLabel"
	from.text = tr("ui_depth_from_entrance") if chosen <= 1 else tr("ui_depth_from_exit") % (first_layer - 1)
	info.add_child(from)
	var big_line: HBoxContainer = HBoxContainer.new()
	info.add_child(big_line)
	var big: Label = Label.new()
	big.name = "StartLayerLabel"
	big.theme_type_variation = &"DepthBigLabel"
	big.text = str(first_layer)
	big_line.add_child(big)
	var unit: Label = Label.new()
	unit.text = tr("ui_depth_from")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	big_line.add_child(unit)
	var next_exit: Label = Label.new()
	next_exit.name = "NextExitLabel"
	next_exit.theme_type_variation = &"SmallLabel"
	next_exit.text = tr("ui_depth_next_exit") % (chosen * per_floor)
	info.add_child(next_exit)
	# ⚠ 出るものの下限（2026-10-03・回4-b・手本 DungeonGate「出るものの下限［等級◯以上］」）。⚠ 入る層の帯で決まる。
	var equip_floor: Label = Label.new()
	equip_floor.name = "EquipGradeLabel"
	equip_floor.theme_type_variation = &"SmallLabel"
	equip_floor.text = tr("ui_depth_equip_grade") % GameManager.get_dungeon_equip_grade_range(_dungeon_id, first_layer).x
	info.add_child(equip_floor)
	# −10 ／ +10 ／ 最深へ（⚠ 端は押せない）。
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "DepthButtons"
	info.add_child(buttons)
	var deepest: int = options[options.size() - 1] if not options.is_empty() else 1
	for spec: Array in [
		["DepthMinusButton", tr("ui_depth_minus") % per_floor, chosen - 1, chosen <= 1],
		["DepthPlusButton", tr("ui_depth_plus") % per_floor, chosen + 1, chosen >= deepest],
		["DepthDeepestButton", tr("ui_depth_deepest"), deepest, chosen >= deepest],
	]:
		var button: Button = UiButton.create_paper_choice("")
		button.theme_type_variation = &"DepthStepButton"
		button.name = str(spec[0])
		button.text = str(spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(spec[3])
		button.pressed.connect(_on_depth_picked.bind(int(spec[2])))
		buttons.add_child(button)
	return holder


func _on_depth_picked(start_floor: int) -> void:
	if not (start_floor in GameManager.get_dungeon_start_floor_options(_dungeon_id)):
		return
	_start_floor = start_floor
	# ⚠ 押したボタンを押している最中に作り直さない（⚠ 次のフレームで）。
	_rebuild.call_deferred()


func _on_to_sortie_pressed() -> void:
	SceneManager.change_scene_with_data(SORTIE_PATH, {
		TransferKeys.SORTIE_STAGE_ID: "",
		TransferKeys.SORTIE_DUNGEON_ID: _dungeon_id,
		TransferKeys.SORTIE_START_FLOOR: current_start_floor(),
		TransferKeys.RETURN_PATH: SCENE_PATH,
	})


func _on_back_pressed() -> void:
	SceneManager.change_scene_with_data(BOARD_PATH, {TransferKeys.QUEST_TAB: 1})
