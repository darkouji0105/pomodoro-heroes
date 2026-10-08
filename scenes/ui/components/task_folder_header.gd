class_name TaskFolderHeader
extends LedgerRow

# タスクのフォルダの見出しの行（2026-10-09・回TK-F・`TK-18`・`EXEC_TASK_FOLDER.md`）。
#
# ⚠ 「▼ 仕事　3」。⚠ 押すと畳む／開く（⚠ 畳んだかはセーブに載る＝3つの画面で共通・人間「⚠ ３あ」）。
# ⚠ フォルダなし（folder_id ""）は畳まない・矢印を出さない（⚠ 一番下・人間「⚠ ５あ」）。
# ⚠ 右に足すもの（⚠ タスクの画面の「名前を変える」「消す」）は `actions` に入れる。
# ⚠ 並びは `GameManager.get_task_groups()` の1本。⚠ 3つの画面（タスクの画面・拠点の紙・ポモドーロのサイドバー）で使うので components/。

const ARROW_OPEN: String = "▼"
const ARROW_CLOSED: String = "▶"

var folder_id: String = ""
var actions: HBoxContainer = null


# ⚠ 件数は「その組で出しているタスクの数」（⚠ 絞り込みのあとの数を渡してよい）。
static func create(group: Dictionary, count: int) -> TaskFolderHeader:
	var header: TaskFolderHeader = TaskFolderHeader.new()
	header.folder_id = str(group.get(GameManager.TASK_GROUP_FOLDER_ID, ""))
	header.name = "Folder_" + (header.folder_id if header.folder_id != "" else "none")
	header.compact = true
	var collapsed: bool = bool(group.get(GameManager.TASK_GROUP_COLLAPSED, false))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(line)
	var title: Label = Label.new()
	title.name = "FolderTitle"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if header.folder_id == "":
		title.text = TranslationServer.translate("ui_task_folder_none")
	else:
		title.text = "%s %s" % [ARROW_CLOSED if collapsed else ARROW_OPEN, str(group.get(GameManager.TASK_GROUP_NAME, ""))]
	line.add_child(title)
	var count_label: Label = Label.new()
	count_label.name = "FolderCount"
	count_label.theme_type_variation = &"CaptionLabel"
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_label.text = TranslationServer.translate("ui_task_count") % count
	line.add_child(count_label)
	header.actions = HBoxContainer.new()
	header.actions.name = "Actions"
	line.add_child(header.actions)
	if header.folder_id != "":
		header.pressed.connect(header._on_pressed)
	else:
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return header


func _on_pressed() -> void:
	var _changed: bool = GameManager.set_task_folder_collapsed(folder_id, not GameManager.is_task_folder_collapsed(folder_id))
