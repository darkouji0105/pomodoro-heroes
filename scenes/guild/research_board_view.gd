class_name ResearchBoardView
extends Control

# 研究のボード1枚（2026-10-18・回UI-1018-7・web版の手本 `04_research_b1.png` `04_research_b2.png`・決定 `GR-10`）。
#
# ⚠ コルク板に札（`ResearchCard`）を留め、⚠ 前の研究から糸を引く：⚠ 両方済み＝赤い糸 ／ ⚠ 前が済み＝墨の紐 ／ ⚠ まだ＝点線。
# ⚠ 段＝分類（戦闘・宝箱・鍛冶…）／ ⚠ 列＝前の研究からの深さ（⚠ 同じボードの前提だけ数える）。⚠ 置き場所はマスターから毎回計算（⚠ 座標を持たない）。
# ⚠ 右端に「完成の報酬」の札（⚠ 後ろに続く研究が無い札から糸）。⚠ 左上にボードの題（⚠ 閉じていれば開く条件）。
# ⚠ 札は並べない器（`Control`）に自分で置く＝⚠ 大きさは `custom_minimum_size`（⚠ 横に送る器に入れる）。
# ⚠ 寸法と色は Theme の `Research` 型。⚠ 研究の画面だけで使う＝scenes/guild/（AGENTS.md）。

signal card_pressed(node_id: String)
signal reward_pressed(board: int)

const THEME_TYPE: StringName = &"Research"


static func create(board: int) -> ResearchBoardView:
	var view: ResearchBoardView = ResearchBoardView.new()
	view.name = "BoardView"
	view._board = board
	return view


var _board: int = 1
var _cards: Dictionary = {}   # node_id -> ResearchCard
var _reward: ResearchCard = null
var _title: Label = null


func board() -> int:
	return _board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


# ⚠ 同じボードの前提からの深さ。
func _depths(ids: Array[String]) -> Dictionary:
	var depth: Dictionary = {}
	for _pass: int in range(ids.size() + 1):
		var changed: bool = false
		for node_id: String in ids:
			var best: int = 0
			for raw: Variant in MasterDataLoader.get_research_node(node_id).get(GameStateKeys.NODE_PREREQUISITES, []):
				var before: String = str(raw)
				if before in ids:
					best = maxi(best, int(depth.get(before, 0)) + 1)
			if int(depth.get(node_id, -1)) != best:
				depth[node_id] = best
				changed = true
		if not changed:
			break
	return depth


func _build() -> void:
	var ids: Array[String] = []
	for node_id: Variant in MasterDataLoader.get_all_research_nodes():
		if GameManager.get_research_board_of(str(node_id)) == _board:
			ids.append(str(node_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(MasterDataLoader.get_research_node(a).get("sort_order", 9999)) < int(MasterDataLoader.get_research_node(b).get("sort_order", 9999)))
	var depth: Dictionary = _depths(ids)
	var card_w: float = float(get_theme_constant(&"card_width", THEME_TYPE))
	var card_h: float = float(get_theme_constant(&"card_height", THEME_TYPE))
	var col_gap: float = float(get_theme_constant(&"col_gap", THEME_TYPE))
	var row_gap: float = float(get_theme_constant(&"row_gap", THEME_TYPE))
	var left: float = float(get_theme_constant(&"label_col", THEME_TYPE))
	var top: float = float(get_theme_constant(&"board_top", THEME_TYPE))
	var pad: float = float(get_theme_constant(&"board_pad", THEME_TYPE))
	var max_depth: int = 0
	var y: float = top
	for category: String in GameManager.get_research_categories():
		# ⚠ 分類ごとに、同じ深さの札を縦に積む（⚠ 段の高さ＝いちばん積んだ数）。
		var slots: Dictionary = {}
		var lines: int = 0
		for node_id: String in ids:
			if ResearchCard.category_of(node_id) != category:
				continue
			var d: int = int(depth.get(node_id, 0))
			var line: int = int(slots.get(d, 0))
			slots[d] = line + 1
			lines = maxi(lines, line + 1)
			max_depth = maxi(max_depth, d)
			var card: ResearchCard = ResearchCard.create(node_id)
			card.pressed.connect(_on_card_pressed.bind(node_id))
			add_child(card)
			card.position = Vector2(left + float(d) * (card_w + col_gap), y + float(line) * (card_h + row_gap))
			_cards[node_id] = card
		if lines == 0:
			continue
		var height: float = float(lines) * (card_h + row_gap) - row_gap
		var tag: Label = Label.new()
		tag.name = "Category_" + category
		tag.theme_type_variation = &"ResearchCategoryLabel"
		tag.text = "\n".join(tr("ui_research_category_" + category).split(""))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		tag.size = Vector2(float(get_theme_constant(&"label_width", THEME_TYPE)), maxf(height, tag.get_combined_minimum_size().y))
		tag.position = Vector2(pad, y + (height - tag.size.y) * 0.5)
		y += height + row_gap * 2.0
	# ⚠ 完成の報酬（⚠ 右端・縦の真ん中）。
	_reward = ResearchCard.create_reward(_board)
	_reward.pressed.connect(_on_reward_pressed)
	add_child(_reward)
	var bottom: float = maxf(y - row_gap * 2.0, top + card_h)
	_reward.position = Vector2(left + float(max_depth + 1) * (card_w + col_gap) + col_gap, top + (bottom - top - card_h) * 0.5)
	# ⚠ 題の紙（⚠ 閉じていれば開く条件）。
	_title = Label.new()
	_title.name = "BoardTitle"
	_title.theme_type_variation = &"ResearchBoardTitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_title.position = Vector2(pad, pad)
	refresh()
	custom_minimum_size = Vector2(_reward.position.x + card_w + pad * 2.0, bottom + pad * 2.0)


func refresh() -> void:
	for node_id: String in _cards:
		(_cards[node_id] as ResearchCard).refresh()
	if _reward != null:
		_reward.refresh()
	var progress: Dictionary = GameManager.get_research_board_progress(_board)
	var text: String = tr("ui_research_board_title") % [_board, int(progress.get("unlocked", 0)), int(progress.get("total", 0))]
	if not GameManager.is_research_board_open(_board):
		var before: int = _board - 1
		text += "　" + tr("ui_research_board_locked") % [before, GameManager.get_research_board_open_need(before), int(GameManager.get_research_board_progress(before).get("unlocked", 0))]
	_title.text = text
	_title.size = _title.get_combined_minimum_size()
	queue_redraw()


func select(id: String) -> void:
	for node_id: String in _cards:
		(_cards[node_id] as ResearchCard).selected = node_id == id
	if _reward != null:
		_reward.selected = id == ""


func card_of(node_id: String) -> ResearchCard:
	return _cards.get(node_id, null) as ResearchCard


func reward_card() -> ResearchCard:
	return _reward


func _on_card_pressed(node_id: String) -> void:
	card_pressed.emit(node_id)


func _on_reward_pressed() -> void:
	reward_pressed.emit(_board)


# ⚠ 糸（⚠ 前の研究の右 → この研究の左）。
func _draw() -> void:
	var done: Dictionary = {}
	var has_next: Dictionary = {}
	for node_id: String in _cards:
		done[node_id] = (_cards[node_id] as ResearchCard).card_state() == ResearchCard.State.DONE
	for node_id: String in _cards:
		for raw: Variant in MasterDataLoader.get_research_node(node_id).get(GameStateKeys.NODE_PREREQUISITES, []):
			var before: String = str(raw)
			if not _cards.has(before):
				continue
			has_next[before] = true
			_thread(_cards[before] as Control, _cards[node_id] as Control, bool(done[before]), bool(done[node_id]))
	# ⚠ 後ろに続く研究が無い札 → 完成の報酬。
	if _reward != null:
		var claimed: bool = GameManager.is_research_board_reward_claimed(_board)
		for node_id: String in _cards:
			if not has_next.has(node_id):
				_thread(_cards[node_id] as Control, _reward, bool(done[node_id]), claimed)


func _thread(from: Control, to: Control, from_done: bool, to_done: bool) -> void:
	var start: Vector2 = from.position + Vector2(from.size.x, from.size.y * 0.5)
	var end: Vector2 = to.position + Vector2(0.0, to.size.y * 0.5)
	var bend: float = maxf((end.x - start.x) * 0.5, 12.0)
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(0, 21):
		var t: float = float(step) / 20.0
		var u: float = 1.0 - t
		var c1: Vector2 = start + Vector2(bend, 0.0)
		var c2: Vector2 = end - Vector2(bend, 0.0)
		points.append(start * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + end * t * t * t)
	var width: float = float(get_theme_constant(&"thread_width", THEME_TYPE))
	if from_done and to_done:
		draw_polyline(points, get_theme_color(&"thread_done", THEME_TYPE), width, true)
	elif from_done:
		draw_polyline(points, get_theme_color(&"thread_next", THEME_TYPE), width, true)
		_arrow(end, get_theme_color(&"thread_next", THEME_TYPE))
	else:
		# ⚠ 点線（⚠ 曲線の刻みを1つおきに引く）。
		var color: Color = get_theme_color(&"thread_wait", THEME_TYPE)
		for i: int in range(points.size() - 1):
			if i % 2 == 0:
				draw_line(points[i], points[i + 1], color, width * 0.75)


func _arrow(tip: Vector2, color: Color) -> void:
	var s: float = float(get_theme_constant(&"arrow", THEME_TYPE))
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s, -s * 0.6), tip + Vector2(-s, s * 0.6)]), color)
