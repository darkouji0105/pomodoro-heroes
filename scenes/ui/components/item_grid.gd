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

# 1行に並べるマスの数。⚠ ここは見た目の都合なので画面側が決める。
const DEFAULT_COLUMNS: int = 8

var _slots: Array[ItemSlot] = []
# ⚠ ホバーの枠（`ItemDetailPopup`）が見張っている器か（2026-09-10）。
#   ⚠ 真ならマスは素のツールチップを出さない（⚠ 名前が2枚重なるのを止める）。
#   ⚠ 入れるのは `ItemDetailPopup.watch()` の1本。⚠ 画面側で立てないこと。
#   ⚠ `watch()` は `rebuild()` より先に呼ばれることが多い（⚠ 倉庫は _ready で watch）。
#     ⚠ だから器が覚えておき、⚠ 作り直しのたびに新しいマスへ配る。
var _tooltip_suppressed: bool = false
# ⚠ マスの左下に個数を出すか（2026-09-10）。⚠ **素材タブだけ true**（⚠ `item_slot.gd` の注記）。
#   ⚠ `_tooltip_suppressed` と同じで、⚠ 器が覚えて作り直しのたびに配る。
var _count_shown: bool = false


func _ready() -> void:
	if columns <= 0:
		columns = DEFAULT_COLUMNS


# マス目を作り直す。
#
# entries … GameManager.get_inventory_slot_entries() の戻り（マス1つ＝1要素）
# slot_count … 枠の数。⚠ 0 以下なら entries の数ぶんだけ（＝容量が無い画面用）
func rebuild(entries: Array, slot_count: int = 0) -> void:
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
		# ⚠ add_child() の前に入れる。⚠ マスは _ready() で1回だけ描くので、
		#   ⚠ ここで入れておけば描き直しが起きない。
		slot.set_tooltip_suppressed(_tooltip_suppressed)
		slot.set_count_shown(_count_shown)
		slot.slot_pressed.connect(_on_slot_pressed.bind(i))
		slot.slot_dropped.connect(_on_slot_dropped.bind(i))
		slot.slot_hovered.connect(_on_slot_hovered.bind(i))
		slot.slot_unhovered.connect(_on_slot_unhovered.bind(i))
		add_child(slot)
		_slots.append(slot)


func get_slot_count() -> int:
	return _slots.size()


# 素のツールチップを器ごと止める／戻す。⚠ 呼ぶのは `ItemDetailPopup.watch()` の1本。
func set_tooltip_suppressed(value: bool) -> void:
	_tooltip_suppressed = value
	for slot: ItemSlot in _slots:
		slot.set_tooltip_suppressed(value)


# マスの左下に個数を出す／出さない。⚠ **素材タブだけ** true にする。
#   ⚠ 持ち物のマスで呼ばないこと（⚠ 同じ品が2個なら2マス並ぶので、⚠ 数が嘘になる）。
func set_count_shown(value: bool) -> void:
	_count_shown = value
	for slot: ItemSlot in _slots:
		slot.set_count_shown(value)


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
