# res://scripts/utils/scroll_keeper.gd
# 描き直しのあとにスクロールの位置を戻す（2026-10-18・人間「⚠ スクロールのあるもので項目を選んだら　スクロールを上に戻される」）。
#
# ⚠ 原因：画面の多くは描き直しのたびに ScrollContainer ごと作り直す（⚠ remove_child → queue_free。CLAUDE.md 5番）。
#   ⚠ 新しい枠は 0 から始まるので、⚠ 行を押すたびに一番上へ戻っていた。
# ⚠ 使い方：⚠ 描き直しの頭で `capture(self)`、⚠ 最後に `restore(self, kept)`。⚠ タブを替えたときは `reset(self)` を先に呼ぶ（⚠ 別の一覧に前の位置を持ち越さない）。
# ⚠ 鍵は root からの道（⚠ 名前の無い枠は `@ScrollContainer@123` になり毎回変わる＝⚠ 戻せない。⚠ 戻したい枠には名前を付ける）。
# ⚠⚠ 入れた直後は中身の大きさが決まっておらず、⚠ 入れても 0 に丸められる（⚠ dungeon_map.gd の `_center_scroll_on_current()` と同じ罠）。
#   ⚠ だから棒の `changed`（⚠ 中身の大きさが決まったとき）で入れる。⚠ 枠が消えれば接続も一緒に消える（⚠ ラムダが消えた物を掴まない）。
# ⚠ await を持たない（CLAUDE.md 5番）。

class_name ScrollKeeper
extends RefCounted

# ⚠ 入れ直しを待つのは数フレームだけ（⚠ 待ち続けると、あとで手で動かした位置を引き戻してしまう）。
const WAIT_FRAMES: int = 3
const PENDING_META: StringName = &"scroll_keeper_pending"


static func capture(root: Node) -> Dictionary:
	var kept: Dictionary = {}
	if root == null:
		return kept
	for scroll: ScrollContainer in _scrolls_of(root):
		if scroll.name.begins_with("@"):
			continue
		var at: Vector2i = Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
		if at != Vector2i.ZERO:
			kept[str(root.get_path_to(scroll))] = at
	return kept


static func restore(root: Node, kept: Dictionary) -> void:
	if root == null:
		return
	for path: Variant in kept:
		var scroll: ScrollContainer = root.get_node_or_null(NodePath(str(path))) as ScrollContainer
		if scroll == null:
			continue
		_apply(scroll, kept[path] as Vector2i)


# ⚠ 1つの枠だけ（⚠ 枠は作り直さず、中身だけ作り直す画面＝育成のスキル）。
static func capture_one(scroll: ScrollContainer) -> Vector2i:
	if scroll == null:
		return Vector2i.ZERO
	return Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)


static func restore_one(scroll: ScrollContainer, at: Vector2i) -> void:
	if scroll == null or at == Vector2i.ZERO:
		return
	_apply(scroll, at)


# ⚠ いま出ている枠を全部いちばん上へ（⚠ タブを替える前に呼ぶ）。
static func reset(root: Node) -> void:
	if root == null:
		return
	for scroll: ScrollContainer in _scrolls_of(root):
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0


static func _apply(scroll: ScrollContainer, at: Vector2i) -> void:
	var deadline: int = Engine.get_process_frames() + WAIT_FRAMES
	_apply_bar(scroll.get_v_scroll_bar(), at.y, deadline)
	_apply_bar(scroll.get_h_scroll_bar(), at.x, deadline)


static func _apply_bar(bar: ScrollBar, value: int, deadline: int) -> void:
	if bar == null or value <= 0:
		return
	bar.value = value
	# ⚠ 届いていても待つ（⚠ 中身を作り直すと、このあと並べ直しで丸められることがある）。
	# ⚠ 前の待ちが残っていれば外す（⚠ 枠を作り直さない画面で2回続けて描き直したとき）。
	if bar.has_meta(PENDING_META):
		var old: Pending = bar.get_meta(PENDING_META) as Pending
		if old != null and bar.changed.is_connected(old.on_changed):
			bar.changed.disconnect(old.on_changed)
	var pending: Pending = Pending.new()
	pending.bar = bar
	pending.value = value
	pending.deadline = deadline
	# ⚠ Callable は RefCounted を掴まない（⚠ ObjectID だけ）＝⚠ 棒のメタに持たせて生かす。⚠ 棒が消えれば一緒に消える。
	bar.set_meta(PENDING_META, pending)
	bar.changed.connect(pending.on_changed)


# ⚠ 入れ直しを待っている1本。
class Pending:
	extends RefCounted
	var bar: ScrollBar = null
	var value: int = 0
	var deadline: int = 0

	func on_changed() -> void:
		if Engine.get_process_frames() <= deadline:
			bar.value = value
			return
		# ⚠ メタは外さない（⚠ 外すと自分の処理の途中で自分が消える）。⚠ 棒と一緒に消える。
		bar.changed.disconnect(on_changed)


static func _scrolls_of(root: Node) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	for node: Node in root.find_children("*", "ScrollContainer", true, false):
		found.append(node as ScrollContainer)
	return found
