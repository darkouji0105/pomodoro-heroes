class_name TaskFolderBox
extends PanelContainer

# タスクのフォルダの箱（2026-10-09・回TK-F2・`TK-18`・人間「⚠ １い　２あ　３う」）。
#
# ⚠ 見出し（`TaskFolderHeader`）は箱の上の帯、⚠ 中のタスクの行は箱の中（`rows`）に並べる＝⚠ 「フォルダの中に入っている」。
# ⚠ 畳んだときは見出しだけ（⚠ 中身を出さない・「２あ」）。⚠ フォルダなしも同じ箱（「３う」）。
# ⚠ 使い方：`create()` → `rows.add_child(行)` を並べる → `finish()`（⚠ 最後の行の罫を消す＝箱の縁で閉じる）。
# ⚠ 値は Theme の `TaskFolderBox` / `TaskFolderHeaderPanel` / `TaskFolderInner` 型。⚠ 3つの画面で使うので components/。

var header: TaskFolderHeader = null
var rows: VBoxContainer = null


static func create(group: Dictionary, count: int) -> TaskFolderBox:
	var box: TaskFolderBox = TaskFolderBox.new()
	box.theme_type_variation = &"TaskFolderBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.header = TaskFolderHeader.create(group, count)
	box.name = "Box_" + (box.header.folder_id if box.header.folder_id != "" else "none")
	var inner: VBoxContainer = VBoxContainer.new()
	inner.name = "Inner"
	inner.theme_type_variation = &"TaskFolderInner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	inner.add_child(box.header)
	box.rows = VBoxContainer.new()
	box.rows.name = "Rows"
	box.rows.theme_type_variation = &"TaskFolderInner"
	box.rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(box.rows)
	return box


# ⚠ 行を並べ終えたら呼ぶ。⚠ 中身が無ければ（畳んだ・空）見出しだけの箱になる。
func finish() -> void:
	var count: int = rows.get_child_count()
	rows.visible = count > 0
	# ⚠ 中身が無い箱は見出しだけ（⚠ 下の余白と帯の下の角＝`TaskFolderBoxClosed` / `TaskFolderHeaderClosedPanel`）。
	theme_type_variation = &"TaskFolderBox" if count > 0 else &"TaskFolderBoxClosed"
	header.closed = count == 0
	if count > 0 and rows.get_child(count - 1) is LedgerRow:
		(rows.get_child(count - 1) as LedgerRow).show_rule = false
