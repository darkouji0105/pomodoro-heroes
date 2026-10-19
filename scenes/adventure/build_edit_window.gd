# res://scenes/adventure/build_edit_window.gd
# ビルドと装備の窓（2026-10-18・回UI-1018-5・web版の手本 `01_barracks_window.png` / `01_barracks_build_delete.png`・NOTES §1）。
#
# ⚠ 詰所の「中身を直す・着替える ›」「＋組む」から開く。⚠ 詰所の上に暗幕と紙を重ねる。
#   ⚠ 左：ビルド1〜3（⚠ 押すとそのビルドに切り替わる＝当てる ／「出撃で使う」＝いまの形と同じビルド ／ ゴミ箱＝消す）・ステータス10個。
#   ⚠ 真ん中：ビルド◯の中身＝名前（✎）・スキル2枠・装備5枠（⚠ 押すと右に候補）。
#   ⚠ 右：候補（⚠ 装備＝マス目と並べ替えの欄・ほかの人の物は暗い ／ スキル＝一覧）＋ 比べる欄 ＋ 着ける／外す。
#   ⚠ 下：変えたところ ／「残さずに閉じる」「別の番号に残す…」「ビルド◯に残して閉じる」。
# ⚠⚠ 中身を変えると**そのキャラのいまの形がすぐ変わる**（⚠ 本番の口 `equip_instance()` / `select_skill()`）。⚠ 「残す」でビルドに焼く（`save_character_preset()`）。
#   ⚠ 「残さずに閉じる」はビルドに焼かないだけ（⚠ いまの形は変えたまま）。
# ⚠ 判定は全部 `GameManager` の口。⚠ 詰所でしか使わないので scenes/adventure/（AGENTS.md）。
# ⚠⚠ 10-19（回SEE29-E・`GR-15`・人間「⚠ ６同じものを使うが、少し処理を変えるだけにする　呼び出し元が２個」→「⚠ １い　２い」）：
#   ⚠ 真ん中と右は共通の部品 `LoadoutEditor`（⚠ 育成の「スキル・装備」と同じもの）。⚠ この窓が持つのは左・頭・下の3つのボタンと、真ん中の上（「ビルド◯の中身」と名前）だけ。
#   ⚠ 部品は作り直さない（⚠ 選んでいる枠と候補が消える）＝⚠ 描き直すのは頭・左・下。⚠ スキルは窓で選ぶ（回SEE29-A の形）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。

class_name BuildEditWindow
extends Control

# ⚠ 閉じた（⚠ 詰所の帯に出す一言・⚠ 空なら出さない）。
signal closed(notice: String)

const THEME_TYPE: StringName = &"Sortie"

var _character_id: String = ""
var _index: int = 0
var _pending_name: String = ""
var _changes: Array[String] = []
var _tip: ItemTipCard = null
var _sheet_body: VBoxContainer = null
var _editor: LoadoutEditor = null
var _columns: HBoxContainer = null


static func open(host: Control, character_id: String, index: int) -> BuildEditWindow:
	var window: BuildEditWindow = BuildEditWindow.new()
	window.name = "BuildEditWindow"
	window._character_id = character_id
	window._index = index
	window._pending_name = GameManager.get_character_preset_name(character_id, index)
	host.add_child(window)
	return window


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = get_theme_color(&"result_scrim", &"Forge")
	add_child(scrim)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"BuildWindowMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	margin.add_child(sheet)
	_sheet_body = VBoxContainer.new()
	_sheet_body.name = "Body"
	sheet.add_child(_sheet_body)
	_tip = ItemTipCard.attach(self)
	# ⚠ 開いたビルドが焼いてあれば、⚠ そのビルドに切り替えてから直す（⚠ 「ビルド◯の中身」を直すため）。
	if _is_saved(_index) and GameManager.get_matching_character_preset(_character_id) != _index:
		var _report: Dictionary = GameManager.apply_character_preset(_character_id, _index)
	GameManager.character_growth_changed.connect(_on_growth_changed)
	_rebuild()


func _is_saved(index: int) -> bool:
	return bool(GameManager.get_character_preset(_character_id, index).get(GameStateKeys.PRESET_SAVED, false))


func _on_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()


func _rebuild() -> void:
	# ⚠ 最初の1回だけ器を組む（⚠ 頭 ／ 列＝左・仕切り・部品 ／ 線 ／ 下）。
	if _columns == null:
		_sheet_body.add_child(_build_head())
		_columns = HBoxContainer.new()
		_columns.name = "Columns"
		_columns.theme_type_variation = &"WideRow"
		_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_sheet_body.add_child(_columns)
		_columns.add_child(_build_left())
		_columns.add_child(VSeparator.new())
		_editor = LoadoutEditor.create(_character_id)
		_editor.tip = _tip
		_editor.top_builder = _build_editor_top
		_editor.changed.connect(_on_editor_changed)
		_columns.add_child(_editor)
		_sheet_body.add_child(HSeparator.new())
		_sheet_body.add_child(_build_foot())
		return
	_replace(_sheet_body, "Head", _build_head())
	_replace(_columns, "Left", _build_left())
	_replace(_sheet_body, "Foot", _build_foot())


# ⚠ 同じ名前の子を作り直した物と差し替える（⚠ 並びの位置は保つ・await を持たない）。
func _replace(parent: Node, child_name: String, fresh: Control) -> void:
	var old: Node = parent.get_node_or_null(child_name)
	if old == null:
		parent.add_child(fresh)
		return
	var at: int = old.get_index()
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(fresh)
	parent.move_child(fresh, at)


func _on_editor_changed(text: String) -> void:
	_note_change(text)
	_replace(_sheet_body, "Foot", _build_foot())


# --- 頭 ---

func _build_head() -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.add_child(CharacterAvatar.create(_character_id, get_theme_constant(&"mini_photo", THEME_TYPE) + 8))
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_build_window_title") % _name_of(_character_id)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var sub: Label = Label.new()
	sub.theme_type_variation = &"CaptionLabel"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level: int = int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	sub.text = "%s・%s %d" % [tr("ui_role_" + _character_id), tr("ui_dossier_lv"), level]
	head.add_child(sub)
	var close: Button = _small("ui_build_window_close")
	close.name = "CloseButton"
	close.pressed.connect(_close.bind(""))
	head.add_child(close)
	return head


# --- 左：ビルド1〜3 ／ ステータス ---

func _build_left() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Left"
	column.custom_minimum_size.x = float(get_theme_constant(&"build_left", THEME_TYPE))
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_build_window_builds"
	heading.right_text = tr("ui_build_window_builds_max") % GameManager.get_character_preset_count()
	column.add_child(heading)
	var matching: int = GameManager.get_matching_character_preset(_character_id)
	var presets: Array = GameManager.get_character_presets(_character_id)
	for i: int in range(presets.size()):
		column.add_child(_build_card(i, presets[i] as Dictionary, matching))
	var stats_heading: SheetHeading = SheetHeading.new()
	stats_heading.title_key = "ui_build_window_stats"
	column.add_child(stats_heading)
	var stats: Dictionary = GameManager.get_effective_stats(_character_id)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Stats"
	list.theme_type_variation = &"TightList"
	column.add_child(list)
	for stat_key: String in GameManager.get_stat_keys():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Stat_" + stat_key
		var caption: Label = Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = tr("ui_training_stat_" + stat_key)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var value: Label = Label.new()
		value.name = "Value"
		var number: int = int(stats.get(stat_key, 0))
		value.text = ("%d%%" % number) if GameManager.is_percent_stat(stat_key) else str(number)
		row.add_child(value)
		list.add_child(row)
	var note: Label = Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("ui_build_window_nodes_note")
	column.add_child(note)
	return column


# ビルドの札（⚠ 押すとそのビルドを直す＝当てる・⚠ 空きなら「押して組む」＝いまの形のまま直す先にする）。
func _build_card(index: int, preset: Dictionary, matching: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "BuildCard_%d" % index
	card.theme_type_variation = &"SkillSlotSelectedPanel" if index == _index else &"SkillSlotPanel"
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var saved: bool = bool(preset.get(GameStateKeys.PRESET_SAVED, false))
	var title: Label = Label.new()
	title.name = "BuildTitle"
	title.theme_type_variation = &"SheetHeadingLabel" if saved else &"CaptionLabel"
	title.text = "%d　%s" % [index + 1, _preset_name(index)] if saved else tr("ui_build_window_empty") % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	if saved:
		var used: Label = Label.new()
		used.name = "UsedLabel"
		used.theme_type_variation = &"ErrorLabel" if index == matching else &"CaptionLabel"
		used.text = tr("ui_build_window_in_use") if index == matching else ""
		used.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(used)
		var trash: Button = _small("ui_build_window_delete")
		trash.name = "DeleteBuild_%d" % index
		trash.pressed.connect(_on_delete_pressed.bind(index))
		top.add_child(trash)
		var icons: LoadoutIcons = LoadoutIcons.from_preset(preset, get_theme_constant(&"build_icon", THEME_TYPE))
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child: Node in icons.get_children():
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icons)
	UiButton.attach_hit(card, _on_build_card_pressed.bind(index))
	return card


func _on_build_card_pressed(index: int) -> void:
	if index == _index:
		return
	_index = index
	_pending_name = GameManager.get_character_preset_name(_character_id, index)
	if _is_saved(index):
		var report: Dictionary = GameManager.apply_character_preset(_character_id, index)
		_note_change(GameManager.format_apply_report(report))
	_rebuild()
	# ⚠ 真ん中の上（「ビルド◯の中身」と名前）を新しい番号で（⚠ 部品は作り直さない）。
	_editor.select_target("")


# ビルドを消す（⚠ 確かめの窓・手本 `01_barracks_build_delete.png`）。
func _on_delete_pressed(index: int) -> void:
	var ok: bool = await Modal.confirm(self, "ui_build_window_delete_confirm", [], false, {
		Modal.OPTION_TITLE: tr("ui_build_window_delete_title") % [index + 1, _preset_name(index)],
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_build_window_delete_go",
	})
	if not ok or not is_instance_valid(self):
		return
	if GameManager.clear_character_preset(_character_id, index):
		_note_change(tr("ui_build_window_deleted") % (index + 1))
	_rebuild()


# --- 真ん中の上：ビルド◯の中身・名前（⚠ 共通の部品 `LoadoutEditor` の `top_builder`） ---

func _build_editor_top(column: VBoxContainer) -> void:
	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr("ui_build_window_content") % (_index + 1)
	heading.right_text = tr("ui_build_window_content_hint")
	column.add_child(heading)
	var name_row: HBoxContainer = HBoxContainer.new()
	column.add_child(name_row)
	var name_caption: Label = Label.new()
	name_caption.theme_type_variation = &"CaptionLabel"
	name_caption.text = tr("ui_build_window_name")
	name_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_caption)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.theme_type_variation = &"PaperLineEdit"
	name_edit.text = _pending_name
	name_edit.placeholder_text = tr("ui_party_preset_build") % (_index + 1)
	name_edit.max_length = GameManager.CHARACTER_PRESET_NAME_MAX
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)


func _on_name_changed(text: String) -> void:
	_pending_name = text


# --- 下 ---

func _build_foot() -> HBoxContainer:
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	var changes: Label = Label.new()
	changes.name = "ChangesLabel"
	changes.theme_type_variation = &"CaptionLabel"
	changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	changes.text = tr("ui_build_window_changes") % "・".join(_changes) if not _changes.is_empty() else tr("ui_build_window_no_change")
	changes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(changes)
	var discard: Button = _small("ui_build_window_discard")
	discard.name = "DiscardButton"
	discard.pressed.connect(_close.bind(""))
	foot.add_child(discard)
	var other: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_build_window_save_other")
	other.name = "SaveOtherButton"
	other.pressed.connect(_on_save_other_pressed.bind(other))
	foot.add_child(other)
	var save: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "")
	save.name = "SaveButton"
	save.text = tr("ui_build_window_save") % (_index + 1)
	save.pressed.connect(_save_and_close.bind(_index))
	foot.add_child(save)
	return foot


func _on_save_other_pressed(anchor: Control) -> void:
	var pop: SlotActionPopover = SlotActionPopover.open(self, anchor.get_global_rect(), tr("ui_build_window_save_other"), "")
	for i: int in range(GameManager.get_character_preset_count()):
		var label: String = "%d　%s" % [i + 1, _preset_name(i) if _is_saved(i) else tr("ui_party_preset_empty")]
		var button: UiButton = pop.add_action(label, UiButton.Variant.SECONDARY, _save_and_close.bind(i))
		button.name = "SaveTo_%d" % i


# ⚠ いまの形をビルド◯に焼いて閉じる（⚠ 名前も）。
func _save_and_close(index: int) -> void:
	if not GameManager.save_character_preset(_character_id, index):
		return
	var _named: bool = GameManager.set_character_preset_name(_character_id, index, _pending_name)
	_close(tr("ui_build_window_saved") % [_name_of(_character_id), index + 1])


func _close(notice: String) -> void:
	if GameManager.character_growth_changed.is_connected(_on_growth_changed):
		GameManager.character_growth_changed.disconnect(_on_growth_changed)
	closed.emit(notice)
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


# --- 小さい道具 ---

func _note_change(text: String) -> void:
	if text != "" and not (text in _changes):
		_changes.append(text)


func _preset_name(index: int) -> String:
	var preset_name: String = GameManager.get_character_preset_name(_character_id, index)
	return preset_name if preset_name != "" else tr("ui_party_preset_build") % (index + 1)


func _name_of(character_id: String) -> String:
	return tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))


func _small(key: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"PaperToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(key)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button
