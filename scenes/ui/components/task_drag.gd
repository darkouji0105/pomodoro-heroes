class_name TaskDrag
extends RefCounted

# タスクをドラッグで動かす（2026-10-16・`TK-19`・人間「⚠ タスクは、ドラッグで移動させられるように」→「⚠ 並べ替え＋フォルダへ移す」
#   → 10-17「⚠ サイドバーと拠点のdragも」）。
# ⚠ タスクの画面・ポモドーロのサイドバー・拠点の紙の3つで使う＝scenes/ui/components/（AGENTS.md）。
# ⚠ 行に落とす＝その行のフォルダの、⚠ 上半分なら前・下半分なら後ろ ／ ⚠ フォルダの箱（見出し・空き）に落とす＝そのフォルダの一番後ろ。
# ⚠ 状態を変えるのは `GameManager.move_task_to()` の1本だけ（⚠ 判定を全部終えてから状態を変える）。
# ⚠ 画面ごとの「つまんでよいか」（⚠ タスクの画面はタグで絞っているときはつままない）は `can_drag` で渡す。

const DATA_TASK_ID: String = "drag_task_id"


# 行をつまめる・落とせるようにする。⚠ `can_drag` は引数なしで bool を返す（⚠ 空なら いつでも）。
static func attach_row(row: Control, task: Dictionary, can_drag: Callable = Callable()) -> void:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var title: String = str(task.get(GameStateKeys.TASK_TITLE, ""))
	var folder_id: String = str(task.get(GameStateKeys.TASK_FOLDER, ""))
	row.set_drag_forwarding(
		func(_at_position: Vector2) -> Variant:
			if can_drag.is_valid() and not bool(can_drag.call()):
				return null
			return drag_data(row, task_id, title),
		func(_at_position: Vector2, data: Variant) -> bool:
			return can_drop(data, task_id),
		func(at_position: Vector2, data: Variant) -> void:
			drop_on_row(at_position, data, task_id, folder_id, row),
	)


# フォルダの箱（⚠ 箱そのものと見出しの両方）に落とせるようにする。
static func attach_folder(box: TaskFolderBox) -> void:
	var folder_id: String = box.header.folder_id
	for target: Control in [box, box.header]:
		target.set_drag_forwarding(
			Callable(),
			func(_at_position: Vector2, data: Variant) -> bool:
				return can_drop(data, ""),
			func(_at_position: Vector2, data: Variant) -> void:
				drop_on_folder(data, folder_id),
		)


# 運ぶデータ。⚠ 指に付ける題は本当にドラッグしているときだけ（⚠ ドラッグの外で呼ぶと赤になり、⚠ 作った字が行き場を失って残る）。
static func drag_data(source: Control, task_id: String, title: String) -> Dictionary:
	if source != null and source.get_viewport() != null and source.get_viewport().gui_is_dragging():
		var preview: Label = Label.new()
		preview.text = title
		source.set_drag_preview(preview)
	return {DATA_TASK_ID: task_id}


# ⚠ 落とせるのはタスクだけ・⚠ 自分の行には落とせない。
static func can_drop(data: Variant, onto_task_id: String) -> bool:
	return data is Dictionary and (data as Dictionary).has(DATA_TASK_ID) and str((data as Dictionary)[DATA_TASK_ID]) != onto_task_id


static func drop_on_row(at_position: Vector2, data: Variant, onto_task_id: String, folder_id: String, row: Control) -> bool:
	if not can_drop(data, onto_task_id):
		return false
	var after: bool = is_instance_valid(row) and at_position.y > row.size.y * 0.5
	return GameManager.move_task_to(str((data as Dictionary)[DATA_TASK_ID]), folder_id, onto_task_id, after)


static func drop_on_folder(data: Variant, folder_id: String) -> bool:
	if not can_drop(data, ""):
		return false
	return GameManager.move_task_to(str((data as Dictionary)[DATA_TASK_ID]), folder_id)
