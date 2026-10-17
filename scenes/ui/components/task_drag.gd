class_name TaskDrag
extends RefCounted

# タスクをドラッグで動かす（2026-10-16・`TK-19`・人間「⚠ タスクは、ドラッグで移動させられるように」→「⚠ 並べ替え＋フォルダへ移す」
#   → 10-17「⚠ サイドバーと拠点のdragも」）。
# ⚠ タスクの画面・ポモドーロのサイドバー・拠点の紙の3つで使う＝scenes/ui/components/（AGENTS.md）。
# ⚠ 行に落とす＝その行のフォルダの、⚠ 上半分なら前・下半分なら後ろ ／ ⚠ フォルダの箱（見出し・空き）に落とす＝そのフォルダの一番後ろ。
# ⚠ 状態を変えるのは `GameManager.move_task_to()` の1本だけ（⚠ 判定を全部終えてから状態を変える）。
# ⚠ 画面ごとの「つまんでよいか」（⚠ タスクの画面はタグで絞っているときはつままない）は `can_drag` で渡す。

const DATA_TASK_ID: String = "drag_task_id"
# 落とす場所の目印（2026-10-17・見る回・人間「⚠ つまむ乙須が分かんない　目印を出して」・`TK-20`）。
# ⚠ 行の上＝前に入る線 ／ ⚠ 行の下＝後ろに入る線 ／ ⚠ フォルダ＝箱を囲む枠（⚠ 一番後ろに入る）。
# ⚠ 目印は落とす先の子（⚠ top_level＝並びを崩さない）。⚠ ドラッグが終わる・指が外れると自分で消える。
const MARKER_NAME: String = "TaskDropMarker"
const THEME_TYPE: StringName = &"TaskDrag"
enum Mark { BEFORE, AFTER, FOLDER }


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
		func(at_position: Vector2, data: Variant) -> bool:
			var ok: bool = can_drop(data, task_id)
			if ok:
				show_marker(row, Mark.AFTER if is_after(row, at_position) else Mark.BEFORE)
			return ok,
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
				var ok: bool = can_drop(data, "")
				if ok:
					show_marker(box, Mark.FOLDER)
				return ok,
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
	var after: bool = is_instance_valid(row) and is_after(row, at_position)
	return GameManager.move_task_to(str((data as Dictionary)[DATA_TASK_ID]), folder_id, onto_task_id, after)


static func drop_on_folder(data: Variant, folder_id: String) -> bool:
	if not can_drop(data, ""):
		return false
	return GameManager.move_task_to(str((data as Dictionary)[DATA_TASK_ID]), folder_id)


# ⚠ 行の下半分か（⚠ 落とす所と目印が同じ判定を使う）。
static func is_after(row: Control, at_position: Vector2) -> bool:
	return at_position.y > row.size.y * 0.5


# 目印を出す（⚠ 同じ先なら置き直すだけ）。⚠ 戻りは目印（⚠ 検査が読む）。
static func show_marker(target: Control, mark: Mark) -> DropMarker:
	var marker: DropMarker = target.get_node_or_null(MARKER_NAME) as DropMarker
	if marker == null:
		marker = DropMarker.new()
		marker.name = MARKER_NAME
		target.add_child(marker)
	# ⚠ 目印は1つだけ（⚠ フォルダの中の行に重ねたとき、箱の枠を残さない）。
	var viewport: Viewport = target.get_viewport()
	if viewport != null:
		var last: Variant = viewport.get_meta(MARKER_NAME) if viewport.has_meta(MARKER_NAME) else null
		if last is DropMarker and is_instance_valid(last) and last != marker:
			(last as DropMarker).visible = false
		viewport.set_meta(MARKER_NAME, marker)
	marker.mark = mark
	marker.visible = true
	marker.follow()
	return marker


# 落とす先の上に重ねる目印。⚠ 入力は受けない（⚠ 下の行にドラッグが届くように）。
class DropMarker extends Control:
	var mark: int = Mark.BEFORE

	func _init() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 10

	# ⚠ 親（落とす先）に重ねる。⚠ 指が親から外れたら消える（⚠ 次の先が自分の目印を出す）。
	func _process(_delta: float) -> void:
		if not visible:
			return
		var parent: Control = get_parent() as Control
		if parent == null or not parent.get_global_rect().has_point(parent.get_global_mouse_position()):
			visible = false
			return
		follow()

	func follow() -> void:
		var parent: Control = get_parent() as Control
		if parent == null:
			return
		global_position = parent.global_position
		size = parent.size
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			visible = false

	func _draw() -> void:
		var color: Color = get_theme_color(&"marker", THEME_TYPE)
		var width: float = float(get_theme_constant(&"marker_px", THEME_TYPE))
		if mark == Mark.FOLDER:
			draw_rect(Rect2(Vector2.ZERO, size).grow(-width * 0.5), color, false, width)
			return
		var y: float = 0.0 if mark == Mark.BEFORE else size.y
		draw_line(Vector2(0.0, y), Vector2(size.x, y), color, width)
		# ⚠ 左端に小さな丸（⚠ 線だけだと罫と見分けにくい）。
		draw_circle(Vector2(0.0, y), width * 1.5, color)
