class_name ItemGrid
extends GridContainer

# マス目の器（段階18-a・PLAN_INVENTORY.md §6）。
#
# ⚠ 「並べる」だけの部品。⚠ 何が並ぶか・何マスあるかは呼ぶ側が渡す。
#   ⚠ ここで GameManager を読まないこと。⚠ 倉庫（18-c）とダンジョンの鞄（18-d）で
#     引く先が別（台帳が別＝PLAN_HARD_DUNGEON.md §7）。⚠ 部品だけ共有する。
# ⚠ 中身より枠が多ければ空のマスが並ぶ。⚠ 中身のほうが多い場合は
#   「入り切らない」ので、⚠ 黙って切り捨てずに赤を出す（容量の判定は 18-b）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。remove_child してから queue_free。
#
# ⚠ .tscn を持たない。⚠ GridContainer に付けるだけの部品で、
#   置く側が columns と大きさを決める（AGENTS.md「迷ったら画面フォルダ」の逆で、
#   これは器なので components/ に置く）。

# 押されたマスの中身と、⚠ 何番目のマスか。
#
# ⚠⚠ 番号を必ず渡すこと。⚠ 空のマスは中身が全部同じ（空の Dictionary）なので、
#   ⚠ 中身だけでは「どの枠を押したか」が区別できない（⚠ 装備の5枠でこれを踏んだ）。
signal slot_pressed(entry: Dictionary, index: int)
# マウスが乗った／外れた（2026-09-07）。⚠ 番号を渡す理由は slot_pressed と同じ。
#
# ⚠ 出す先は `ItemDetailPopup.watch()` の1本。⚠ 画面ごとに繋ぎ替えないこと。
signal slot_hovered(entry: Dictionary, index: int)
signal slot_unhovered(index: int)
# マスを動かした（段階18-f・ドラッグ＆ドロップ）。⚠ 番号はこのマス目の中の番号。
#   ⚠ ページのぶんを足すのは画面側（⚠ この部品はページを知らない）。
signal slot_moved(from_index: int, to_index: int)
# 別のマス目から落とされた（2026-09-15）。⚠ 中身は `from_grid.get_entry_at(from_index)` で引く
#   （⚠ 荷物に中身を入れない＝ItemSlot の決まり）。⚠ to_index はこのマス目の中の番号。
signal slot_received(from_grid: ItemGrid, from_index: int, to_index: int)

# ⚠⚠ マスの下に出す字（2026-09-21・人間の指示「⚠ 枠と、頭などの部位を表すテキストを対応させて」）。
#   ⚠ 空なら出さない＝**今までの画面は1つも変わらない**（⚠ 倉庫・鞄・宝箱）。
#   ⚠ 入れると、⚠ マスを器（縦）で包んで下に字を置く。⚠ 列は `columns` のまま揃う。
#   ⚠ `rebuild()` より先に入れること。
var captions: PackedStringArray = PackedStringArray()

# 1行に並べるマスの数。⚠ ここは見た目の都合なので画面側が決める。
const DEFAULT_COLUMNS: int = 8
# 別のマス目から受ける器のグループ（2026-09-15・段3c）。⚠ OS の別窓から落とし先を探すときに引く。
const GROUP_DROP_TARGET: StringName = &"item_grid_drop_target"

# ⚠ この器の組の名前（2026-09-15）。⚠ 別のマス目がこれを見て受けるか決める。
#   ⚠ 名前は置く側が決める（⚠ ここは画面を知らない）。⚠ rebuild() より先に入れること。
var drag_group: String = ""
# ⚠ どの組のマス目から受けるか。⚠ 空なら別のマス目からは受けない（⚠ 既定）。
var accept_drop_groups: Array[String] = []

var _slots: Array[ItemSlot] = []
# ⚠ ホバーの枠（`ItemDetailPopup`）が見張っている器か（2026-09-10）。
#   ⚠ 真ならマスは素のツールチップを出さない（⚠ 名前が2枚重なるのを止める）。
#   ⚠ 入れるのは `ItemDetailPopup.watch()` の1本。⚠ 画面側で立てないこと。
#   ⚠ `watch()` は `rebuild()` より先に呼ばれることが多い（⚠ 倉庫は _ready で watch）。
#     ⚠ だから器が覚えておき、⚠ 作り直しのたびに新しいマスへ配る。
var _tooltip_suppressed: bool = false

func _ready() -> void:
	if columns <= 0:
		columns = DEFAULT_COLUMNS


# マス目を作り直す。
#
# entries … GameManager.get_inventory_slot_entries() の戻り（マス1つ＝1要素）
# slot_count … 枠の数。⚠ 0 以下なら entries の数ぶんだけ（＝容量が無い画面用）
func rebuild(entries: Array, slot_count: int = 0) -> void:
	# ⚠ 受ける組があるときだけ、⚠ 別窓からの落とし先として名乗る（段3c）。
	if accept_drop_groups.is_empty():
		if is_in_group(GROUP_DROP_TARGET):
			remove_from_group(GROUP_DROP_TARGET)
	else:
		add_to_group(GROUP_DROP_TARGET)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots.clear()

	var total: int = slot_count if slot_count > 0 else entries.size()
	if entries.size() > total:
		# ⚠ 黙って切り捨てない。⚠ 「持っているのに見えない」が一番たちが悪い。
		push_error("[ItemGrid] 中身 %d 件が枠 %d を超えている（容量の判定が抜けている）" % [
			entries.size(), total
		])
		total = entries.size()

	for i: int in range(total):
		var entry: Dictionary = entries[i] if i < entries.size() else {}
		var slot: ItemSlot = ItemSlot.create(entry)
		slot.name = "Slot_%d" % i
		slot.set_slot_index(i)
		slot.set_drag_origin(get_instance_id(), drag_group, accept_drop_groups)
		# ⚠ add_child() の前に入れる。⚠ マスは _ready() で1回だけ描くので、
		#   ⚠ ここで入れておけば描き直しが起きない。
		slot.set_tooltip_suppressed(_tooltip_suppressed)
		slot.slot_pressed.connect(_on_slot_pressed.bind(i))
		slot.slot_dropped.connect(_on_slot_dropped.bind(i))
		slot.slot_received.connect(_on_slot_received.bind(i))
		slot.slot_hovered.connect(_on_slot_hovered.bind(i))
		slot.slot_unhovered.connect(_on_slot_unhovered.bind(i))
		# ⚠ 字があるときだけ器で包む（⚠ 無いときは今までどおりマスを直に並べる）。
		if i < captions.size():
			var cell: VBoxContainer = VBoxContainer.new()
			cell.name = "Cell_%d" % i
			cell.theme_type_variation = &"TightList"
			cell.add_child(slot)
			var caption: Label = Label.new()
			caption.name = "Caption"
			caption.theme_type_variation = &"CaptionLabel"
			caption.text = captions[i]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(caption)
			add_child(cell)
		else:
			add_child(slot)
		_slots.append(slot)


func get_slot_count() -> int:
	return _slots.size()


# そのマスの中身。⚠ 範囲の外なら空の Dictionary。
func get_entry_at(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	return _slots[index].get_entry()


# 素のツールチップを器ごと止める／戻す。⚠ 呼ぶのは `ItemDetailPopup.watch()` の1本。
func set_tooltip_suppressed(value: bool) -> void:
	_tooltip_suppressed = value
	for slot: ItemSlot in _slots:
		slot.set_tooltip_suppressed(value)


func _on_slot_pressed(entry: Dictionary, index: int) -> void:
	slot_pressed.emit(entry, index)


func _on_slot_hovered(entry: Dictionary, index: int) -> void:
	slot_hovered.emit(entry, index)


func _on_slot_unhovered(index: int) -> void:
	slot_unhovered.emit(index)


# 落とされた。⚠ from はつまんだ側、⚠ to は落とされた側（bind で入る）。
func _on_slot_dropped(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index == to_index:
		return
	slot_moved.emit(from_index, to_index)


# 別のマス目から落とされた。⚠ to は落とされた側（bind で入る）。
func _on_slot_received(from_grid_id: int, from_index: int, to_index: int) -> void:
	var from_grid: Variant = instance_from_id(from_grid_id)
	if not (from_grid is ItemGrid) or from_index < 0:
		return
	slot_received.emit(from_grid as ItemGrid, from_index, to_index)


# OS の別窓からつまんで離したとき、⚠ 画面の上の位置から落とし先を探して落とす（2026-09-15・段3c）。
#
# ⚠ 呼ぶのは `ItemSlot._notification()` の1本（⚠ 標準の落としが成功しなかったときだけ）。
# ⚠ 落とすときは標準と同じ `_can_drop_data` / `_drop_data` を通す（⚠ 受ける判定を2本にしない）。
# ⚠ 対象は OS の窓に直に置かれた器だけ（⚠ ゲームの窓・OS の別窓）。⚠ 埋め込みの窓の中は探さない。
# ⚠ 窓が重なっていたら、⚠ いちばん手前の窓の器だけ（⚠ get_window_at_screen_position）。
#   ⚠ ヘッドレスは窓を持たないので、⚠ 手前の判定は飛ばす（⚠ 座標の変換だけ確かめられる）。
# 落とせたら true。
static func route_screen_drop(payload: Dictionary, screen_point: Vector2i, source_window: Window) -> bool:
	var tree: SceneTree = source_window.get_tree()
	if tree == null:
		return false
	var check_front: bool = DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	var front_id: int = DisplayServer.get_window_at_screen_position(screen_point) if check_front else DisplayServer.INVALID_WINDOW_ID
	for node: Node in tree.get_nodes_in_group(GROUP_DROP_TARGET):
		var grid: ItemGrid = node as ItemGrid
		if grid == null or not grid.is_visible_in_tree():
			continue
		var window: Window = grid.get_window()
		if window == null or window == source_window or window.is_embedded():
			continue
		if check_front and window.get_window_id() != front_id:
			continue
		var point: Vector2 = grid.screen_to_canvas(screen_point)
		for slot: ItemSlot in grid._slots:
			if not slot.get_global_rect().has_point(point):
				continue
			if not slot._can_drop_data(point, payload):
				return false
			slot._drop_data(point, payload)
			return true
	return false


# 画面の上の位置 → この器の画面の座標。⚠ 窓の位置と、⚠ stretch（canvas_items）の拡大を戻す。
func screen_to_canvas(screen_point: Vector2i) -> Vector2:
	var window: Window = get_window()
	var local: Vector2 = Vector2(screen_point - window.position)
	return window.get_final_transform().affine_inverse() * local
