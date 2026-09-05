# res://scenes/adventure/dungeon_map.gd
# 難ダンジョンのマップ画面（段階17-d・PLAN_HARD_DUNGEON.md §5-0）。
#
# ⚠⚠ floor_map.gd と1行も共有していない（台帳 §7）。⚠ 読むキーが別の定数で
#   （FLOOR_NODE_* ／ DUNGEON_NODE_*）、⚠ 仕様も別（スタミナ無し・引き返さない・
#   撤退はボスの後だけ・全ロストがある）。⚠ 共通化すると片方の仕様がもう片方に漏れる。
#   ⚠ 見た目が似ているのは意図どおり。⚠ 描画コードが2箇所にあることは受け入れている。
#
# ⚠ この画面は状態を持たない。正は GameManager.get_dungeon_run() の1本だけ。
# ⚠ 進めるかの判定を自分で書かない（get_dungeon_moves()）。
# ⚠ 撤退できるかの判定も自分で書かない（can_retreat_from_dungeon()）。
# ⚠ ポーションが効くかの判定も書かない（use_dungeon_item() が弾く）。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
#
# ⚠⚠ 段階19-e で ScrollContainer を入れた（人間の指示「画面をスクロールできるように」）。
#   ⚠ 層が 6 → 8 になり（19-d）、⚠ 通路の線も入って縦に伸びたため。
#   ⚠⚠ 代償：⚠ `scenario=layout` はこの画面の中身を測れなくなった（宿題68 と同じ穴）。
#     ⚠ 倉庫は 18-c で「Scroll をやめて固定グリッドにする」で解いたが、
#       ⚠ こちらは層数が可変なので固定にできない。⚠ 測れないことを受け入れる。

extends Control

const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
# ⚠ 別画面に切り出したもの（段階17-e-3・人間の指示）。⚠ ここから遷移するだけ。
const RELIC_SELECT_PATH: String = "res://scenes/adventure/dungeon_relic_select.tscn"
const SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"
# ⚠ 宝箱も別画面（段階19-b・人間の決定21「遺物や宝箱やショップは別画面」）。
const CHEST_PATH: String = "res://scenes/adventure/dungeon_chest.tscn"

# マスの見た目。⚠ 色はここに置く（floor_map.gd と同じ扱い。main_theme.tres に
#   対応する概念が無い）。⚠ 値まで揃えるかは見た目の判断なので人間が決める。
const COLOR_CURRENT: Color = Color(1.0, 0.95, 0.55)
const COLOR_VISITED: Color = Color(0.45, 0.45, 0.5)
const COLOR_REACHABLE: Color = Color(1.0, 1.0, 1.0)
const COLOR_FAR: Color = Color(0.6, 0.6, 0.65)
# 脱落したキャラの色。⚠ 「居るのに出られない」が一目で分かること（§4-4-2）。
const COLOR_DOWNED: Color = Color(0.85, 0.35, 0.35)
# 中身が見えていないマスの表示（段階17-e）。⚠ シナリオ側と同じ字にしてある。
const HIDDEN_TEXT: String = "？"

# 通路の線の色（段階19-e・人間の指示「通路用のグラフィックを用意したほうがいい」）。
#
# ⚠ 色はここに置く（⚠ マスの色と同じ扱い。⚠ main_theme.tres に対応する概念が無い）。
# ⚠⚠ 「良いか悪いか」だけを色で言う。⚠ 何が起きるかは絵文字が言う（⚠ 役割を分ける）。
# ⚠ 罠＝赤 ／ 得＝黄 ／ 何も無い＝灰 ／ 中身が見えていない＝暗い灰。
const COLOR_EDGE_TRAP: Color = Color(0.85, 0.35, 0.35)
const COLOR_EDGE_GAIN: Color = Color(0.95, 0.85, 0.4)
const COLOR_EDGE_PLAIN: Color = Color(0.45, 0.45, 0.5)
const COLOR_EDGE_HIDDEN: Color = Color(0.28, 0.28, 0.32)
# ⚠ いま立っているマスから出ている通路は太くする（⚠ 「次に選ぶのはここ」が読めること）。
const EDGE_WIDTH: float = 2.0
const EDGE_WIDTH_CURRENT: float = 4.0

# マスの並びの間隔（段階19-f・人間の指摘「⚠ も間隔をあけてほしい」）。
#
# ⚠ 層のあいだが狭いと線がほとんど点になり、⚠ どこへ繋がるかが読めない。
# ⚠ ここに直書きしていたのを const に出した（⚠ 2箇所に散らさない）。
# ⚠ バランスの数値ではなく見た目なので Config に出していない
#   （⚠ 色と同じ扱い。⚠ main_theme.tres に対応する概念が無い）。
const LAYER_SEPARATION: int = 44
const NODE_SEPARATION: int = 56

# マス1つの幅（段階20-g）。
#
# ⚠⚠ 列を揃えるのに要る。⚠ 揃えないと文字の長さで列がずれ（⚠ 「戦闘」と「レリック」）、
#   ⚠ 線が斜めになって重なる（⚠ 人間の指摘「左から右に行く道がやたら生成される」）。
# ⚠ 空の列にも同じ幅のものを置くこと。⚠ 置かないと列が詰まる。
const NODE_WIDTH: float = 104.0

# 線の端をマスの辺に沿ってどれだけ散らすか（マスの幅に対する割合。段階20-g）。
#
# ⚠ 0 にすると全部が中央から出て、⚠ 合流点の手前で線が完全に重なる。
# ⚠ 1 に近づけるとマスの角から出るので、⚠ どのマスから来たか分かりにくくなる。
const EDGE_ANCHOR_SPREAD: float = 0.55

@onready var dungeon_name_label: Label = $Layout/Header/DungeonNameLabel
@onready var floor_label: Label = $Layout/Header/FloorLabel
@onready var currency_label: Label = $Layout/Header/CurrencyLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var party_list: HBoxContainer = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var map_scroll: ScrollContainer = $Layout/MapScroll
@onready var map_area: Control = $Layout/MapScroll/MapArea
@onready var layer_list: VBoxContainer = $Layout/MapScroll/MapArea/LayerList
# 通路の線（段階19-e）。⚠ LayerList より前（下）に置いてある＝線がマスの下に描かれる。
@onready var edge_lines: DungeonEdgeLines = $Layout/MapScroll/MapArea/EdgeLines
# 鞄はマス目（段階18-d）。⚠ 部品は倉庫と同じ。⚠ 引く先だけ別（器が別＝台帳 §7）。
# ボスの先のショップ（段階17-e）。⚠ 出るかどうかは GameManager に聞く。
@onready var shop_list: VBoxContainer = $Layout/ShopList
# 通路の宝箱の案内（段階19-c-2）。⚠ 開けずに戻ってきたときに出る。
@onready var corridor_chest_list: VBoxContainer = $Layout/CorridorChestList
@onready var bag_grid: ItemGrid = $Layout/BagGrid
@onready var bag_detail: ItemDetail = $Layout/BagDetail
@onready var bag_action_row: HBoxContainer = $Layout/BagActionRow
@onready var descend_button: PrimaryButton = $Layout/Footer/DescendButton
@onready var retreat_button: PrimaryButton = $Layout/Footer/RetreatButton
@onready var abandon_button: PrimaryButton = $Layout/Footer/AbandonButton
@onready var back_button: PrimaryButton = $Layout/Footer/BackButton


func _ready() -> void:
	SceneManager.consume_transfer_data()

	# ランに入っていないのにここへ来た。⚠ 空のマップを描かず冒険選択へ戻す。
	if not GameManager.is_in_dungeon():
		push_warning("[DungeonMap] ランに入っていないので冒険選択へ戻る")
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return

	# ⚠⚠ 戦闘から戻ったときに拾い待ちがある（段階20-f・人間の指示「戦利品も選ばせる」）。
	#   ⚠ マップを描く前に拾いものの画面へ送る。⚠ 描いてから送ると1フレーム分ちらつく。
	#   ⚠ `_rebuild()` の中でやらないこと（⚠ 戻ってくるたびに遷移して止まらなくなる）。
	# ⚠⚠ 通路の宝箱が先（決定31・2026-09-05）。⚠ 戦闘から戻った直後に必ず1回だけ出す。
	#   ⚠ 「あとから開ける」ボタンは消した（⚠ 人間「宝箱はあとから開けれないようにしたい」）。
	#   ⚠ 開けずに戻ると discard_dungeon_corridor_chest() が捨てるので、⚠ ここは二度は出ない。
	if GameManager.has_pending_dungeon_corridor_chest():
		_enter_corridor_chest()
		return
	if GameManager.has_dungeon_pending_loot():
		_enter_pickup()
		return

	message_label.text = ""
	descend_button.pressed.connect(_on_descend_pressed)
	retreat_button.pressed.connect(_on_retreat_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	bag_grid.columns = GameManager.get_dungeon_bag_slots()
	bag_grid.slot_pressed.connect(_on_bag_slot_pressed)
	# ⚠⚠ 通路の線はマスの位置が確定してからでないと引けない（段階19-e）。
	#   ⚠ 並べ替えが終わるたびに引き直す。⚠ await を使わない（AGENTS.md）。
	#   ⚠ sort_children はレイアウトのたびに飛ぶので、⚠ ウィンドウを広げても追従する。
	layer_list.sort_children.connect(_redraw_edges)
	# ⚠ 層のあいだの間隔（段階19-f）。⚠ .tscn ではなくここで入れる
	#   （⚠ マスのあいだの間隔と同じ場所に並べて、⚠ 2箇所に散らさないため）。
	layer_list.add_theme_constant_override("separation", LAYER_SEPARATION)
	_rebuild()


# ⚠ ランが終わったとき（撤退・全ロスト）は dungeon_id が "" で飛んでくる。
#   ⚠ そのまま描き直すと空のマップになるので、押した側が遷移するまで何もしない。
func _on_dungeon_run_changed(dungeon_id: String) -> void:
	if dungeon_id == "":
		return
	_rebuild()


func _rebuild() -> void:
	_update_header()
	_rebuild_party()
	_rebuild_layers()
	_rebuild_bag()
	_rebuild_shop()
	_rebuild_corridor_chest()
	_update_footer()


func _update_header() -> void:
	var run: Dictionary = GameManager.get_dungeon_run()
	var dungeon_id: String = str(run.get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
	dungeon_name_label.text = tr(str(dungeon.get("name_key", dungeon_id)))

	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	# ⚠ 「3階のうち何階目か」を出す（段階20-a・決定26）。⚠ 残りが見えないと
	#   「もう1枚潜るか」の判断ができない。⚠ 階の数を画面で数えないこと。
	# ⚠⚠ たいまつの等級も出す（決定32・2026-09-05。⚠ 人間「a3は松明の等級も」）。
	#   ⚠ 何層先まで見えているかが読めないと、⚠ ショップで買うかどうかを決められない。
	#   ⚠ 欄を増やさずフロアの行に足す（⚠ .tscn を触らずに済ませる）。
	floor_label.text = "%s %d/%d　%s" % [
		tr("ui_dungeon_floor"), GameManager.get_dungeon_floor_index(),
		GameManager.get_dungeon_max_floors(),
		tr("ui_dungeon_torch_grade") % [
			GameManager.get_dungeon_torch_grade(), GameManager.get_dungeon_reveal_layers()
		],
	]
	currency_label.text = "%s %d" % [tr("ui_dungeon_currency"), GameManager.get_dungeon_currency()]
	bag_label.text = "%s %d/%d" % [
		tr("ui_dungeon_bag"), GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots()
	]


# 3人の「戦闘時 MAX HP」。⚠ 素の MAX HP も併記する（§4-4）。
#
# ⚠ どれだけ目減りしたかが読めないと、ポーションを使う判断ができない。
# ⚠ 脱落は色と印で出す（§4-4-2）。⚠ 行ごと消さないこと。消すと「誰が欠けたか」が
#   分からないまま3人目で死亡する。
func _rebuild_party() -> void:
	for child in party_list.get_children():
		party_list.remove_child(child)
		child.queue_free()

	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		var label: Label = Label.new()
		label.name = "Party_" + character_id
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var name_text: String = tr(str(char_data.get("name_key", character_id)))
		var max_hp: int = GameManager.get_dungeon_character_max_hp(character_id)
		var base_max_hp: int = GameManager.get_dungeon_base_max_hp(character_id)
		if GameManager.is_dungeon_character_downed(character_id):
			label.text = "%s %s" % [name_text, tr("ui_dungeon_downed")]
			label.modulate = COLOR_DOWNED
		else:
			label.text = "%s %d/%d" % [name_text, max_hp, base_max_hp]
		party_list.add_child(label)


# マスのボタン（段階19-e）。⚠ {node_id: PrimaryButton}。⚠ 通路の線を引くのに使う。
#
# ⚠ 描き直すたびに作り直す。⚠ 古いボタンを持ったままにしないこと
#   （⚠ queue_free() 済みのノードの位置を読むと落ちる）。
var _node_buttons: Dictionary = {}

# いま立っているマスへスクロールを寄せる要求（段階20-c）。
#
# ⚠ 描き直したときに立て、⚠ 寄せたら下ろす。⚠ 毎回のレイアウトで寄せないため。
var _center_pending: bool = false


# 通路を線で引く（段階19-e・人間の指示）。
#
# ⚠⚠ マスの位置が確定してからでないと引けない。⚠ 呼ぶのは
#   ①`_rebuild_layers()` の最後 ②`layer_list.sort_children` の2箇所だけ。
#   ⚠ `await` を使わない（AGENTS.md「再描画に await を持たせない」）。
# ⚠ 何が起きる通路かは絵文字が言う（マスの前）。⚠ 線が言うのは「良いか悪いか」だけ。
# ⚠ 効果があるかの判定を自分で書かない（GameManager.get_dungeon_edges）。
func _redraw_edges() -> void:
	if edge_lines == null or not GameManager.is_in_dungeon():
		return
	var run: Dictionary = GameManager.get_dungeon_run()
	var position: String = str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var lines: Array = []
	# ⚠ 綴り順で回す（⚠ Dictionary のキー順は不定。⚠ 重なり順が起動ごとに変わらない）。
	var from_ids: Array = _node_buttons.keys()
	from_ids.sort()

	# ⚠⚠ 入ってくる本数を先に数える（段階20-g）。⚠ 合流するマスで線を横にずらすため
	#   （⚠ 人間の指摘「線が重ならないようにしたい　合流はあってもいい」）。
	#   ⚠ ずらさないと、⚠ 合流点の手前で2〜3本が完全に重なって本数が読めない。
	var incoming_total: Dictionary = {}
	for raw_from: Variant in from_ids:
		for entry: Variant in GameManager.get_dungeon_edges(str(raw_from)):
			var to_key: String = str((entry as Dictionary).get(GameStateKeys.DUNGEON_EDGE_TO, ""))
			incoming_total[to_key] = int(incoming_total.get(to_key, 0)) + 1
	var incoming_used: Dictionary = {}

	for raw_from: Variant in from_ids:
		var from_id: String = str(raw_from)
		var from_button: Control = _node_buttons[from_id]
		if not is_instance_valid(from_button):
			continue
		var out_edges: Array = GameManager.get_dungeon_edges(from_id)
		var out_index: int = -1
		for entry: Variant in out_edges:
			var edge: Dictionary = entry
			out_index += 1
			var to_id: String = str(edge.get(GameStateKeys.DUNGEON_EDGE_TO, ""))
			if not _node_buttons.has(to_id):
				continue
			var to_button: Control = _node_buttons[to_id]
			if not is_instance_valid(to_button):
				continue
			var in_slot: int = int(incoming_used.get(to_id, 0))
			incoming_used[to_id] = in_slot + 1
			lines.append({
				# ⚠ 深い層が上なので、⚠ from は上辺・to は下辺でつなぐと線が交差しない。
				DungeonEdgeLines.LINE_FROM: _edge_anchor(
					from_button, true, out_index, out_edges.size()
				),
				DungeonEdgeLines.LINE_TO: _edge_anchor(
					to_button, false, in_slot, int(incoming_total.get(to_id, 1))
				),
				DungeonEdgeLines.LINE_COLOR: _edge_color(from_id, to_id, edge),
				DungeonEdgeLines.LINE_WIDTH: (
					EDGE_WIDTH_CURRENT if from_id == position else EDGE_WIDTH
				),
				# ⚠ 通路の真ん中に出す字（段階20-c・人間の指示）。
				DungeonEdgeLines.LINE_LABEL: _edge_label(from_id, to_id, edge),
			})
	edge_lines.set_lines(lines)
	_center_scroll_on_current()


# マスのボタンのつなぎ目（段階19-e）。⚠ top なら上辺の中央、⚠ でなければ下辺の中央。
#
# ⚠ 座標は EdgeLines と同じ親（MapArea）の中の位置。⚠ LayerList と EdgeLines は
#   同じ矩形に重ねてあるので、⚠ LayerList の中の位置をそのまま使える。
func _edge_anchor(button: Control, top: bool, slot: int = 0, slot_count: int = 1) -> Vector2:
	var rect: Rect2 = button.get_global_rect()
	var origin: Vector2 = edge_lines.get_global_rect().position
	# ⚠⚠ 何本も出る／入るときは、⚠ マスの辺に沿って少しずらす（段階20-g）。
	#   ⚠ 人間の指摘「⚠ 線が重ならないようにしたい　⚠ 合流はあってもいい」。
	#   ⚠ 全部を中央から出すと、⚠ 出口の近くで線が完全に重なって本数が読めない。
	#   ⚠ ずらすのは端だけ。⚠ 合流そのものは残す（⚠ 行き先は同じマス）。
	var span: float = rect.size.x * EDGE_ANCHOR_SPREAD
	var offset: float = 0.0
	if slot_count > 1:
		offset = (float(slot) / float(slot_count - 1) - 0.5) * span
	var center_x: float = rect.position.x + rect.size.x * 0.5 + offset
	var y: float = rect.position.y if top else rect.position.y + rect.size.y
	return Vector2(center_x, y) - origin


# 通路の真ん中に出す字（段階20-c・人間の指示「⚠ 通路にアイコンは、通路の真ん中に表示して」）。
#
# ⚠ 19-e まではマスのボタンの前に付けていた。⚠ 「そのマスへ入ってくる通路」の
#   まとめだったので、⚠ 合流するマスでは2つ並び、⚠ どの通路のことか分からなかった。
# ⚠ 通ったあとの通路には出さない（⚠ もう選べない）。
# ⚠ 効果が無い通路には何も出さない（⚠ Glyphs が "" を返す）。
func _edge_label(from_id: String, to_id: String, edge: Dictionary) -> String:
	var run: Dictionary = GameManager.get_dungeon_run()
	var visited: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_VISITED, {})
	if visited.has(to_id):
		return ""
	# ⚠⚠ たいまつが届いていない通路には何も出さない（段階20-c で `❔` をやめた）。
	#   ⚠ 1階が25層になり、⚠ 等級1 では1層先しか見えないので、⚠ `❔` を出すと
	#     104本のうち101本に付いて画面が埋まった（⚠ 実測で気づいた）。
	#   ⚠ 「見えていない」ことは線の色（暗い灰）が既に言っている。⚠ 二重に言わない。
	#   ⚠ 「何かある」ことも言わない（⚠ 言うと効果の無い通路との差が漏れる）。
	if not GameManager.is_dungeon_edge_revealed(from_id, to_id):
		return ""
	return Glyphs.for_dungeon_edge(str(edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")))


# いま立っているマスが真ん中に来るようにスクロールする（段階20-c・人間の指示）。
#
# ⚠⚠ 人間の言葉：「⚠ 地図に戻ると、そこを真ん中にするようにして、
#   ⚠ 今のままだと毎回下にスクロールしないといけない」。⚠ 25層になって縦に長くなったため。
# ⚠⚠ 毎回は寄せない。⚠ `sort_children` はレイアウトのたびに飛ぶので、⚠ 毎回寄せると
#   手でスクロールできなくなる。⚠ 描き直したときだけ1回（`_center_pending`）。
func _center_scroll_on_current() -> void:
	if not _center_pending or map_scroll == null:
		return
	var position: String = str(
		GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
	)
	if not _node_buttons.has(position):
		return
	var button: Control = _node_buttons[position]
	if not is_instance_valid(button):
		return
	# ⚠⚠ 中身が伸びるまで待つ。⚠ 伸びる前に入れても ScrollContainer が 0 に丸め、
	#   ⚠ 要求だけ消費して「先頭のまま」になる（⚠ 実測でそうなった）。
	#   ⚠ 消費しないで返る＝次のレイアウトでもう一度来る。
	var bar: ScrollBar = map_scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= map_scroll.size.y:
		return
	# ⚠⚠ `button.position` を使わない。⚠ あれは行（HBoxContainer）の中の座標で、
	#   ⚠ y がほぼ 0 になる（⚠ 最初はこれで書いてスクロールが 0 のままだった）。
	#   ⚠ 線を引くのと同じく global から MapArea の中の位置に直す。
	var center_y: float = (
		button.get_global_rect().get_center().y - map_area.get_global_rect().position.y
	)
	# ⚠ ScrollContainer が範囲の外を丸めてくれるので、⚠ ここで clamp しない。
	map_scroll.scroll_vertical = int(center_y - map_scroll.size.y * 0.5)
	_center_pending = false


# 通路の線の色。⚠ 「良いか悪いか」だけを言う（⚠ 何が起きるかは絵文字）。
func _edge_color(from_id: String, to_id: String, edge: Dictionary) -> Color:
	if not GameManager.is_dungeon_edge_revealed(from_id, to_id):
		return COLOR_EDGE_HIDDEN
	match str(edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")):
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG:
			return COLOR_EDGE_TRAP
		GameStateKeys.DUNGEON_EDGE_EFFECT_CHEST, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE:
			return COLOR_EDGE_GAIN
	return COLOR_EDGE_PLAIN


# 層を縦に並べる。⚠ 下が入口・上がボス（引き返さない＝決定12）。
func _rebuild_layers() -> void:
	for child in layer_list.get_children():
		layer_list.remove_child(child)
		child.queue_free()

	var run: Dictionary = GameManager.get_dungeon_run()
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var visited: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_VISITED, {})
	var position: String = str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var moves: Array = GameManager.get_dungeon_moves()

	# ⚠ Dictionary のキー順は不定なので、必ず綴り順で並べてから層に仕分ける。
	var by_layer: Dictionary = {}
	var node_ids: Array = nodes.keys()
	node_ids.sort()
	for node_id: Variant in node_ids:
		var node: Dictionary = nodes[node_id]
		var layer: int = int(node.get(GameStateKeys.DUNGEON_NODE_LAYER, 1))
		if not by_layer.has(layer):
			by_layer[layer] = []
		(by_layer[layer] as Array).append(str(node_id))

	var layers: Array = by_layer.keys()
	layers.sort()
	layers.reverse()  # 深い層（ボス）を上に。

	# ⚠ 通路の線を引くのに「どのマスがどこに居るか」が要る（段階19-e）。
	#   ⚠ ノード名で探し直さない。⚠ 作ったときに覚える（⚠ 探し直すと名前の綴りが2箇所になる）。
	_node_buttons.clear()

	# ⚠⚠ 列を固定する（段階20-g・人間の指摘「左から右に行く道がやたら生成される」）。
	#   ⚠ 層ごとにノード数が違う（通常3・区画帯6）のに中央揃えで並べていたため、
	#     ⚠ 3ノードの層と6ノードの層で端の位置が食い違い、⚠ 長い斜め線になっていた。
	#   ⚠ 全部の層を「その階の最大ノード数」の列に揃えると、⚠ 線は真下か隣にしか行かない。
	var columns: int = 1
	for layer: Variant in layers:
		columns = maxi(columns, (by_layer[layer] as Array).size())

	for layer: Variant in layers:
		var row: GridContainer = GridContainer.new()
		row.name = "Layer_%d" % int(layer)
		row.columns = columns
		row.add_theme_constant_override("h_separation", NODE_SEPARATION)
		var row_ids: Array = by_layer[layer]
		# ⚠ ノードを列へ割り当てる。⚠ 均等に散らして中央寄せ
		#   （⚠ 両端に寄せると、⚠ 2ノードの層が左端と右端に開いて斜めが復活する）。
		var column_of: Dictionary = {}
		var used_column: int = -1
		for i: int in range(row_ids.size()):
			var wanted: int = int(round(
				(float(i) + 0.5) * float(columns) / float(row_ids.size()) - 0.5
			))
			# ⚠ 同じ列に2つ来ないよう、⚠ 必ず前より右へ（⚠ 丸めで重なることがある）。
			used_column = clampi(maxi(wanted, used_column + 1), 0, columns - 1)
			column_of[used_column] = str(row_ids[i])

		for c: int in range(columns):
			if not column_of.has(c):
				# ⚠ 空の列にも同じ幅のものを置く。⚠ 置かないと列が詰まって揃わない。
				var spacer: Control = Control.new()
				spacer.name = "Gap_%d" % c
				spacer.custom_minimum_size = Vector2(NODE_WIDTH, 0.0)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(spacer)
				continue
			var node_id: String = str(column_of[c])
			var node_button: PrimaryButton = _make_node_button(
				node_id, nodes[node_id], node_id == position,
				visited.has(node_id), node_id in moves
			)
			# ⚠ 幅を揃える。⚠ 揃えないと文字の長さで列がずれる（⚠ 「戦闘」と「レリック」）。
			node_button.custom_minimum_size = Vector2(NODE_WIDTH, 0.0)
			_node_buttons[node_id] = node_button
			row.add_child(node_button)
		layer_list.add_child(row)

	# ⚠ 中身が縦に伸びたぶんスクロールできるように、⚠ 包みの最小の高さを合わせる（段階19-e）。
	#   ⚠ Control は子の最小サイズを自動では拾わない。⚠ ここで渡す。
	map_area.custom_minimum_size = layer_list.get_combined_minimum_size()
	_redraw_edges()
	# ⚠⚠ 要求を立てるのは `_redraw_edges()` の「あと」（段階20-c）。
	#   ⚠ 先に立てると、⚠ すぐ上の呼び出しで消費されてしまう。⚠ そのときは
	#     まだレイアウト前でボタンの位置が 0 なので、⚠ スクロールが 0 のまま終わる
	#     （⚠ 実測でそうなった）。⚠ 次の `sort_children` で寄せる。
	_center_pending = true


func _make_node_button(
		node_id: String, node: Dictionary, is_current: bool, is_visited: bool, is_reachable: bool
) -> PrimaryButton:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = "Node_" + node_id
	var kind: String = str(node.get(GameStateKeys.DUNGEON_NODE_KIND, ""))
	# たいまつ（段階17-e・§4-7）。⚠ 見えるかの判定は GameManager の1本に聞く。
	#   ⚠ 「押せるか」とは別物。⚠ 次の層は必ず押せるが、⚠ たいまつが弱いと中身は伏せる。
	#   ⚠ ここで層を引き算しないこと。
	# ⚠ 絵文字＋文字（段階19-a）。⚠ 対応表は Glyphs の1本だけ。
	#   ⚠ 絵文字だけにしない。⚠ フォントが入っていない環境で全部のマスが
	#     同じ豆腐になり、⚠ どれが何か分からなくなる（⚠ 文字が保険）。
	if GameManager.is_dungeon_node_revealed(node_id):
		button.text = "%s %s" % [Glyphs.for_dungeon_node(kind), tr("ui_dungeon_node_" + kind)]
	else:
		button.text = "%s %s" % [Glyphs.NODE_HIDDEN, HIDDEN_TEXT]
	# ⚠ 通路の効果はここに出さない（段階20-c・人間の指示「通路の真ん中に表示して」）。
	#   ⚠ 19-e まではここに前置きしていたが、⚠ 合流するマスでは複数並び、
	#     ⚠ どの通路のことか分からなかった。⚠ いまは線の中点（_edge_label）。

	if is_current:
		button.text = "▶ " + button.text
		button.modulate = COLOR_CURRENT
	elif is_visited:
		button.text = "✓ " + button.text
		button.modulate = COLOR_VISITED
	elif is_reachable:
		button.modulate = COLOR_REACHABLE
	else:
		button.modulate = COLOR_FAR

	button.disabled = not is_reachable
	if is_reachable:
		button.pressed.connect(_on_node_pressed.bind(node_id))
	return button


# ⚠ `_edge_prefix()`（マスの前に通路の効果を付ける）は段階20-c で消した。
#   ⚠ 人間の指示「通路にアイコンは、通路の真ん中に表示して」。
#   ⚠ 残すと描き方が2本になる。⚠ いまは `_edge_label()` の1本だけ。
#   ⚠ `GameManager.get_dungeon_incoming_edge_effects()` の呼び出し元もここで0件になった。


# 鞄（段階18-d・マス目）。
#
# ⚠⚠ 倉庫の口を借りない。⚠ 引くのは GameManager.get_dungeon_bag_slot_layout()
#   （⚠ 器が別＝PLAN_HARD_DUNGEON.md §7）。⚠ 部品（ItemGrid / ItemDetail）だけ共有する。
# ⚠ 空きマスも並ぶ（⚠ 「あと何個入るか」が見えること＝鞄が有限であることの表示）。
# ⚠ 押したら詳細と「誰に使うか」を出す。⚠ 押した瞬間に使わない（⚠ 倉庫と同じ流儀）。
# ⚠ 効く相手の判定を書かない（⚠ use_dungeon_item() が弾く。⚠ 判定を2箇所にしない）。
var _selected_bag_entry: Dictionary = {}


func _rebuild_bag() -> void:
	bag_grid.rebuild(GameManager.get_dungeon_bag_slot_layout(), GameManager.get_dungeon_bag_slots())
	# ⚠ 使い切って無くなっていることがある。⚠ 残すと押しても何も起きないボタンになる。
	if not _selected_bag_entry.is_empty():
		var item_id: String = str(_selected_bag_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		if int(GameManager.get_dungeon_bag().get(item_id, 0)) <= 0:
			_selected_bag_entry = {}
	_rebuild_bag_actions()


func _on_bag_slot_pressed(entry: Dictionary, _index: int) -> void:
	_selected_bag_entry = entry
	_rebuild_bag_actions()


# 選んだものに対してできること。⚠ ラン専用の品だけ「誰に使うか」が出る。
func _rebuild_bag_actions() -> void:
	for child in bag_action_row.get_children():
		bag_action_row.remove_child(child)
		child.queue_free()

	bag_detail.show_entry(_selected_bag_entry)
	if _selected_bag_entry.is_empty():
		return

	var item_id: String = str(_selected_bag_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	# ⚠ 使えない品（戦利品）にはボタンを出さない。⚠ 判定は GameManager の1本。
	if GameManager.get_dungeon_item_effect(item_id) == "":
		return

	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var button: PrimaryButton = PrimaryButton.new()
		button.name = "Use_%s_%s" % [item_id, character_id]
		button.text = tr(str(char_data.get("name_key", character_id)))
		button.pressed.connect(_on_use_potion_pressed.bind(item_id, character_id))
		bag_action_row.add_child(button)


# レリックのマス（段階17-e-2 → ⚠ 17-e-3 で別画面へ切り出した）。
#
# ⚠⚠ この画面には候補を出さない（人間の指示：「遺物や宝箱やショップは別画面でするべき」）。
#   ⚠ 出す先は `dungeon_relic_select.tscn`。⚠ どのマスかは DUNGEON_NODE_ID で渡す。
# ⚠ 候補を引くのは向こう。⚠ ここで引かないこと（⚠ 引く口を2箇所にしない）。
func _enter_relic_node(node_id: String) -> void:
	SceneManager.change_scene_with_data(
		RELIC_SELECT_PATH, {TransferKeys.DUNGEON_NODE_ID: node_id}
	)


# 宝箱のマス（段階19-b）。⚠ レリックと同じ形（⚠ 踏んだら別画面へ移る）。
#
# ⚠ 開ける／開けたかの判定はここに書かない。⚠ 向こうが GameManager に聞く。
func _enter_chest_node(node_id: String) -> void:
	SceneManager.change_scene_with_data(
		CHEST_PATH, {TransferKeys.DUNGEON_NODE_ID: node_id}
	)


# ボスの先のショップ（段階17-e → ⚠ 17-e-3 で別画面へ切り出した）。
#
# ⚠⚠ この画面には品を並べない（人間の指示）。⚠ 出す先は `dungeon_shop.tscn`。
# ⚠ 店が開いているかの判定は GameManager に聞く（⚠ 空なら店が無い）。⚠ phase を見ない。
func _rebuild_shop() -> void:
	for child in shop_list.get_children():
		shop_list.remove_child(child)
		child.queue_free()

	if GameManager.get_dungeon_shop_entries().is_empty():
		return

	var button: PrimaryButton = PrimaryButton.new()
	button.name = "ShopButton"
	button.text = tr("ui_dungeon_shop_enter")
	button.pressed.connect(_on_shop_pressed)
	shop_list.add_child(button)


func _on_shop_pressed() -> void:
	SceneManager.change_scene(SHOP_PATH)


# 通路の宝箱の案内（段階19-c-2）。⚠ 開けずに戻ってきたときだけ出る。
#
# ⚠⚠ 決定31（2026-09-05）で「あとから開ける」ボタンを消した。
#
# ⚠ 人間の指示「宝箱はあとから開けれないようにしたい」。⚠ 通路の宝箱は、⚠ 通路を通った
#   直後（_on_node_pressed）か、⚠ 戦闘から戻った直後（_ready）に必ず1回だけ画面が出る。
# ⚠ 開けずに「マップへ戻る」と捨てられる（⚠ dungeon_chest 側で discard する）。
# ⚠ 欄（CorridorChestList）は .tscn に残してあるが、⚠ 中身は常に空。
func _rebuild_corridor_chest() -> void:
	for child in corridor_chest_list.get_children():
		corridor_chest_list.remove_child(child)
		child.queue_free()


# 通路の宝箱の画面へ（段階19-c-2）。
#
# ⚠⚠ マスの宝箱と同じ画面（⚠ 人間の指示「通路にも同じ画面を出す」）。
# ⚠ どのマスかは渡さない。⚠ 通路の宝箱はノードに紐づかない（⚠ 持ち越しの欄が正）。
func _enter_corridor_chest() -> void:
	SceneManager.change_scene_with_data(
		CHEST_PATH, {TransferKeys.DUNGEON_CORRIDOR_CHEST: true}
	)


# 続行・撤退はボスを倒した先だけ（決定15）。⚠ 判定は GameManager の1本に聞く。
func _update_footer() -> void:
	var can_retreat: bool = GameManager.can_retreat_from_dungeon()
	# ⚠ 最後の階を突破したら「続行」は出さない（段階20-a・決定26）。
	#   ⚠ 撤退は出す。⚠ 判定は GameManager の2本に聞く（⚠ 階の数をここで数えない）。
	descend_button.visible = GameManager.can_descend_dungeon_floor()
	retreat_button.visible = can_retreat
	# ⚠ 「その場で降りる」は常に出す。⚠ 消すと詰んだ人が閉じ込められる（§4-2）。
	abandon_button.visible = true


# マスを押した。⚠ 進めるかは GameManager が返す。こちらでは判定しない。
func _on_node_pressed(node_id: String) -> void:
	if not GameManager.move_in_dungeon(node_id):
		message_label.text = tr("ui_dungeon_cannot_move")
		return
	# ⚠⚠ 戦闘・ボスのマスは、割り込みより先に戦闘へ（不1・2026-09-05）。
	#   ⚠ 先に拾いもの／通路の宝箱の画面へ送ると、⚠ 戻ってきたときに「着いたマスの中身へ
	#     入る」口がもう無く、⚠ 戦闘が起きないまま次のマスへ進めてしまう
	#     （⚠ _ready() は拾い待ちしか見ない。⚠ _enter_node() を呼ぶのはここ1箇所だけ）。
	#   ⚠ 通路の宝箱と拾い待ちは戦闘から戻ったときに拾う
	#     （⚠ 拾い待ち＝_ready() ／ ⚠ 通路の宝箱＝_rebuild() の案内ボタン）。
	var kind: String = str(
		GameManager.get_dungeon_node(node_id).get(GameStateKeys.DUNGEON_NODE_KIND, "")
	)
	if kind == GameStateKeys.DUNGEON_NODE_KIND_BATTLE \
			or kind == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
		_notify_edge_event()
		_enter_node(node_id)
		return
	# ⚠⚠ 通路の宝箱が先（段階19-c-2）。⚠ 着いたマスの中身より前に開けさせる
	#   （⚠ 「通路を歩いてから部屋に着く」の順。⚠ move_in_dungeon の中の順番と揃える）。
	#   ⚠ 開けずに戻ってきても持ち越しは残る（⚠ 下の _rebuild で案内が出る）。
	# ⚠ 宝箱にはモーダルを出さない（⚠ 画面そのものが演出になっている）。
	if GameManager.has_pending_dungeon_corridor_chest():
		_enter_corridor_chest()
		return
	# ⚠⚠ 拾い待ちが出たら「何を鞄に入れるか」を選ばせる（段階20-e・人間の指示）。
	#   ⚠ 通路の資源がここに来る。⚠ 宝箱と同じ画面を使い回す（⚠ 人間の裁き）。
	#   ⚠ モーダルは出さない（⚠ 画面のほうが中身を見せられる）。
	if GameManager.has_dungeon_pending_loot():
		_enter_pickup()
		return
	# 通路で何か起きたら知らせる（段階20-d・人間の指示「何かわかるような演出がしたい」）。
	# ⚠ マスの中身へ進む前に出す（⚠ 通路 → 部屋 の順と揃える）。
	_notify_edge_event()
	_enter_node(node_id)


# 拾いものの画面へ（段階20-e）。
#
# ⚠ 宝箱と同じ画面（⚠ 人間の裁き「宝箱の画面を使い回す」）。
# ⚠ どのマスかも通路かも渡さない。⚠ 拾い待ちの欄が正（⚠ 出どころに紐づかない）。
func _enter_pickup() -> void:
	SceneManager.change_scene(CHEST_PATH)


# 通路のできごとをモーダルで出す（段階20-d）。
#
# ⚠⚠ 人間の言葉：「⚠ 通路のイベントは、何かわかるような演出がしたい　モーダルとかなんかで」。
#   ⚠ 19-c-2 までは黙って効いていて、⚠ 画面に1文字も出ていなかった。
# ⚠ 何が起きたかは GameManager に聞く（⚠ 画面で数字を組み立て直さない）。
# ⚠ `await` しない。⚠ 待つと、⚠ このあとの戦闘への遷移が閉じるまで止まる。
func _notify_edge_event() -> void:
	var event: Dictionary = GameManager.get_last_dungeon_edge_event()
	var effect: String = str(event.get(GameStateKeys.DUNGEON_EDGE_EFFECT, ""))
	if effect == "":
		return
	var items: Dictionary = event.get("items", {})
	var left_behind: Dictionary = event.get("left_behind", {})
	var amount: int = int(event.get("amount", 0))

	# ⚠⚠ 「拾えなかった」と「何も起きなかった」を分ける（段階20-d）。
	#   ⚠ 分けないと、⚠ 鞄が満杯のときに「拾いものをした（0）」と嘘をつく（⚠ 実測で気づいた）。
	#   ⚠ 罠（鞄）で鞄が空だったときも、⚠ 何も落としていないので出さない。
	if items.is_empty() and amount <= 0:
		if left_behind.is_empty():
			return
		var _full: ModalDialog = Modal.notify(
			self, "ui_dungeon_edge_event_resource_full", [_item_names(left_behind)]
		)
		return

	# ⚠ 品を落とした／拾ったときは名前も出す。⚠ 無ければ数だけ。
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	var detail: String = _item_names(items) if not items.is_empty() else str(amount)
	var _dialog: ModalDialog = Modal.notify(
		self, "ui_dungeon_edge_event_" + effect, [detail]
	)


# {item_id: 個数} を「名前 xN, 名前 xN」の1行にする（段階20-d）。
#
# ⚠ 綴り順で並べる（⚠ Dictionary のキー順は不定。⚠ 起動ごとに並びが変わらない）。
func _item_names(items: Dictionary) -> String:
	var names: Array[String] = []
	var item_ids: Array = items.keys()
	item_ids.sort()
	for raw_id: Variant in item_ids:
		names.append("%s x%d" % [tr("ui_res_" + str(raw_id)), int(items[raw_id])])
	return ", ".join(names)


# 踏んだマスの中身へ進む。⚠ 種類ごとの分岐はここ1本。
#
# ⚠ 休憩は踏んだ時点で GameManager が効かせている（17-c）。⚠ ここで呼ばないこと
#   （2回効く）。⚠ ここでやるのはメッセージだけ。
func _enter_node(node_id: String) -> void:
	var kind: String = str(
		GameManager.get_dungeon_node(node_id).get(GameStateKeys.DUNGEON_NODE_KIND, "")
	)
	match kind:
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE, GameStateKeys.DUNGEON_NODE_KIND_BOSS:
			_enter_battle(node_id)
		GameStateKeys.DUNGEON_NODE_KIND_REST:
			message_label.text = tr("ui_dungeon_rested")
			_rebuild()
		GameStateKeys.DUNGEON_NODE_KIND_RELIC:
			# レリック（段階17-e-3）。⚠ 別画面へ移る（⚠ 踏んだら必ず選ぶ場所へ行く）。
			_enter_relic_node(node_id)
		GameStateKeys.DUNGEON_NODE_KIND_CHEST:
			# 宝箱（段階19-b）。⚠ 別画面へ移る。⚠ 開けるのは向こう。
			#   ⚠ ここで open_dungeon_chest() を呼ばないこと（⚠ 中身を見せる前に配ってしまう）。
			_enter_chest_node(node_id)
		_:
			push_warning("[DungeonMap] 知らないノードの種類: " + kind)
			message_label.text = tr("ui_dungeon_node_not_ready")
			_rebuild()


# 戦闘へ。⚠ 渡すのは DUNGEON_NODE_ID（段階17-b）。
#
# ⚠ FLOOR_NODE_ID を一緒に入れないこと。⚠ 入れると戦闘画面がフロアの枝に入り、
#   スタミナ・クリア記録・画面解放が動く（台帳 §7）。
# ⚠ stage_id は渡さない。⚠ ダンジョンは stages.json に1行も無い
#   （戦闘画面がランの dungeon_id をログの見出しに使う）。
func _enter_battle(node_id: String) -> void:
	SceneManager.change_scene_with_data(
		BATTLE_PATH,
		{
			TransferKeys.DUNGEON_NODE_ID: node_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
		}
	)


# ポーションを使う。⚠ 効かない相手なら false が返るだけ（鞄は減らない）。
func _on_use_potion_pressed(item_id: String, character_id: String) -> void:
	if not GameManager.use_dungeon_item(item_id, character_id):
		message_label.text = tr("ui_dungeon_potion_no_effect")
		return
	message_label.text = tr("ui_dungeon_potion_used")
	_rebuild()


# もう1枚潜る（決定15）。⚠ ランの MAX HP と鞄はそのまま持ち越す。
func _on_descend_pressed() -> void:
	if not GameManager.descend_dungeon_floor():
		message_label.text = tr("ui_dungeon_cannot_descend")
		return
	message_label.text = tr("ui_dungeon_descended")
	_rebuild()


# 撤退する（鞄の中身を持ち帰ってラン終了）。⚠ ラン専用の品は消える（決定17）。
func _on_retreat_pressed() -> void:
	var result: Dictionary = GameManager.retreat_from_dungeon()
	var granted: Dictionary = result.get("granted", {})
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	message_label.text = "%s %d" % [tr("ui_dungeon_retreat_done"), granted.size()]
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# その場で降りる＝全ロスト（§4-2）。⚠ 逃げ道は残す。⚠ ただしタダではない。
func _on_abandon_pressed() -> void:
	GameManager.abandon_dungeon_run()
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# 拠点へ。⚠ ランは終わらない（状態に残るので続きから再開できる）。
func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
