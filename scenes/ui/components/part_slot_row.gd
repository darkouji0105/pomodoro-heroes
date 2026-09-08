class_name PartSlotRow
extends HBoxContainer

# 装飾の枠を1行に並べたもの（2026-09-08・人間のモック「⚠ 枠は種別ごとに改行せず、1〜2行に収める」）。
#
# ⚠ 並べるだけ。⚠ 「どの枠が開いているか」「何が刺さっているか」は
#   `GameManager.get_part_slot_defs()` / `get_part_entries()` が返したものをそのまま使う。
#   ⚠ ここで枠の並びを作らない（⚠ 作ると装備画面と食い違う）。
# ⚠⚠ 開いている枠だけ出す。⚠ 未開放の枠は1つも出さない（⚠ 2026-09-08・人間の指示）。
#   ⚠ 2026-09-07 の決定「⚠ いつ開くかは表示しなくていい」もそのまま生きている。
#   ⚠ ＝⚠ 等級を上げると枠が増える。⚠ 増える前の姿は画面に出ない。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

var _open_count: int = 0
var _filled_count: int = 0


# 枠の並びを作る。⚠ `defs` は `get_part_slot_defs()`（品）か
#   `get_part_entries()`（個体）の戻り。⚠ 前者は中身を持たないので全部「空き」になる。
static func create(defs: Array, grade: int) -> PartSlotRow:
	var row: PartSlotRow = PartSlotRow.new()
	row.name = "PartSlotRow"
	row.rebuild(defs, grade)
	return row


# 並べ直す。⚠ await を持たせない（AGENTS.md）。remove_child してから queue_free。
func rebuild(defs: Array, grade: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_open_count = 0
	_filled_count = 0

	for entry: Variant in defs:
		if not (entry is Dictionary):
			continue
		var view: Dictionary = entry
		# ⚠⚠ 開いていない枠は **1つも作らない**（⚠ 2026-09-08・人間の指示
		#   「⚠ 未開放は、そもそもスロットを表示しないように」）。
		# ⚠ この1本で2つ落ちる：
		#   ⚠ ① まだ等級が足りない枠 ／ ⚠ ② **どの部位にも無い枠**（`game_manager.gd:2889`。
		#      ⚠ 刺さる種類が空＝等級をいくら上げても開かない。⚠ アクセのルーン枠を
		#      ⚠ 2→1 にした余り・2026-09-07）。⚠ `is_part_slot_open()` は両方 false を返す。
		# ⚠ 表そのものは触らない（⚠ 長さが `PART_SLOT_COUNT` と合わなくなると赤が出る）。
		if not GameManager.is_part_slot_open(view, grade):
			continue
		var icon: PartSlotIcon = PartSlotIcon.create(view, grade)
		icon.name = "PartSlot_%d" % int(view.get(GameManager.PART_VIEW_INDEX, get_child_count()))
		add_child(icon)
		_open_count += 1
		if not icon.get_part_entry().is_empty():
			_filled_count += 1


# 「2 / 7」の左と右。⚠ 分母は **開いている枠の数**（⚠ 未開放は数えない）。
func get_filled_count() -> int:
	return _filled_count


func get_open_count() -> int:
	return _open_count


# 検証用の1行（⚠ 設計役は画面の絵を取れない）。⚠ ゲームのロジックから呼ばないこと。
func to_text() -> String:
	var parts: Array[String] = []
	for child in get_children():
		if child is PartSlotIcon:
			parts.append((child as PartSlotIcon).to_text())
	return " ".join(parts)
