class_name TaskFolderHeader
extends LedgerRow

# タスクのフォルダの見出しの行（2026-10-09・回TK-F・`TK-18`・`EXEC_TASK_FOLDER.md`）。
# ⚠ 回TK-F2（10-09）から、⚠ 箱（`TaskFolderBox`）の上の帯として使う（⚠ 画面は箱ごと作る）。
#
# ⚠ 「▼ 仕事　3」。⚠ 押すと畳む／開く（⚠ 畳んだかはセーブに載る＝3つの画面で共通・人間「⚠ ３あ」）。
# ⚠ フォルダなし（folder_id ""）は畳まない・矢印を出さない（⚠ 一番下・人間「⚠ ５あ」）。
# ⚠ 右に足すもの（⚠ タスクの画面の「名前を変える」「消す」）は `actions` に入れる。
# ⚠ 並びは `GameManager.get_task_groups()` の1本。⚠ 3つの画面（タスクの画面・拠点の紙・ポモドーロのサイドバー）で使うので components/。

const ARROW_OPEN: String = "▼"
const ARROW_CLOSED: String = "▶"

var folder_id: String = ""
var actions: HBoxContainer = null
# ⚠ 10-09（回TK-F2）：⚠ 箱に中身が無い（畳んだ・空）＝⚠ 帯の下の角も丸める。⚠ 箱（`TaskFolderBox.finish()`）が決める。
var closed: bool = false:
	set(value):
		closed = value
		_apply()


# ⚠ 件数は「その組で出しているタスクの数」（⚠ 絞り込みのあとの数を渡してよい）。
static func create(group: Dictionary, count: int) -> TaskFolderHeader:
	var header: TaskFolderHeader = TaskFolderHeader.new()
	header.folder_id = str(group.get(GameManager.TASK_GROUP_FOLDER_ID, ""))
	header.name = "Folder_" + (header.folder_id if header.folder_id != "" else "none")
	header.compact = true
	# ⚠ 10-09（回TK-F2）：⚠ 箱（`TaskFolderBox`）の上の帯＝⚠ 下の罫は引かない（⚠ 帯の色で分かれる）。
	header.show_rule = false
	var collapsed: bool = bool(group.get(GameManager.TASK_GROUP_COLLAPSED, false))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(line)
	var title: Label = Label.new()
	title.name = "FolderTitle"
	title.theme_type_variation = &"TaskFolderTitleLabel"
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


# ⚠ 10-09（回TK-F2）：⚠ 面は箱の上の帯（`TaskFolderHeaderPanel`）。⚠ 台帳の行の面（`LedgerRow._apply()`）を差し替える。
# ⚠⚠ `super()` を呼ばない：⚠ 親が行の面に書き換え → ここで帯に戻す、を毎回やると Theme が変わった知らせが往復して
#   ⚠ 止まらない（⚠ `LedgerRow._notification` が THEME_CHANGED で `_apply()` を呼ぶ＝撮影で Stack overflow）。⚠ 同じ値なら書かない。
#   ⚠ 見出しは選ばない・使えなくしない＝⚠ 親の `selected` / `disabled` は見ない。
func _apply() -> void:
	var variation: StringName = &"TaskFolderHeaderClosedPanel" if closed else &"TaskFolderHeaderPanel"
	if theme_type_variation != variation:
		theme_type_variation = variation
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _on_pressed() -> void:
	var _changed: bool = GameManager.set_task_folder_collapsed(folder_id, not GameManager.is_task_folder_collapsed(folder_id))
