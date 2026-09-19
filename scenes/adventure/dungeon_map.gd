# res://scenes/adventure/dungeon_map.gd
# 難ダンジョンのマップ画面（段階17-d・PLAN_HARD_DUNGEON.md §5-0）。
#
# ⚠⚠ floor_map.gd とは画面を分けたまま、⚠ 部品だけ共有する（2026-09-19・人間の決定「全部推奨で」）。
#   ⚠ 共有するのは層の並び・マス・線（RunMapView）と拾いものの画面（DungeonChest）。
#   ⚠ 読むキーは別の定数（FLOOR_NODE_* ／ DUNGEON_NODE_*）で、⚠ 仕様も別（スタミナ無し・
#   引き返さない・撤退はボスの後だけ・全ロストがある）。⚠ 部品は GameManager を読まないので、
#   ⚠ 片方の仕様がもう片方に漏れない。⚠ 器（DUNGEON_RUN）は別のまま（台帳 §7）。
#   ⚠ 前はここに「1行も共有していない（台帳 §7）」と書いていたが、⚠ 台帳 §7 が禁じているのは
#     器（FLOOR_RUN）の使い回しだけで、⚠ 描画の共有は禁じていない。
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
# ⚠ レリック選択はシナリオと1枚（2026-09-19）。⚠ ランの種類を渡す。
const RELIC_SELECT_PATH: String = "res://scenes/adventure/run_relic_select.tscn"
const SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"
# ⚠ 宝箱も別画面（段階19-b・人間の決定21「遺物や宝箱やショップは別画面」）。
const CHEST_PATH: String = "res://scenes/adventure/dungeon_chest.tscn"
# ⚠ 決定36：⚠ 画面遷移ではなく重ねて出すので、⚠ 実体をここで持つ。
const CHEST_SCENE: PackedScene = preload("res://scenes/adventure/dungeon_chest.tscn")

# ⚠ マスと線の色・間隔・幅は RunMapView へ移した（2026-09-19）。⚠ ここに戻さないこと。
# ⚠ 脱落したキャラの色は Theme の ErrorLabel（2026-09-19）。⚠ 「居るのに出られない」が一目で分かること（§4-4-2）。
# 中身が見えていないマスの表示（段階17-e）。⚠ シナリオ側と同じ字にしてある。
const HIDDEN_TEXT: String = "？"

@onready var dungeon_name_label: Label = $Layout/Header/DungeonNameLabel
@onready var floor_label: Label = $Layout/Header/FloorLabel
# たいまつの等級（2026-09-19・モック v2 でフロアの行から分けた）。
@onready var torch_label: Label = $Layout/Header/TorchLabel
@onready var currency_label: Label = $Layout/Header/CurrencyLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
# ⚠⚠ 持っているレリック（決定46・2026-09-19・モック v2 §12）。⚠ ヘッダの右端に小さなマス目。
#   ⚠ 1人用は付けた人の印（`ItemSlot` の装備中の印）。⚠ 効果はホバーの詳細。
@onready var relic_grid: ItemGrid = $Layout/Header/RelicGrid
# ⚠ 3人の行は部品（RunPartyStrip・2026-09-19）。⚠ レリック選択・商人と同じ。
@onready var party_list: RunPartyStrip = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var map_scroll: ScrollContainer = $Layout/MapScroll
# 層の並び・マス・通路の線（2026-09-19 に RunMapView へ切り出した）。⚠ シナリオと同じ部品。
#   ⚠ 真ん中に置く（決定37・2026-09-19）。⚠ `MapCenter`（CenterContainer）が寄せる。
@onready var map_view: RunMapView = $Layout/MapScroll/MapCenter/MapArea
# 鞄はマス目（段階18-d）。⚠ 部品は倉庫と同じ。⚠ 引く先だけ別（器が別＝台帳 §7）。
# ボスの先のショップ（段階17-e）。⚠ 出るかどうかは GameManager に聞く。
@onready var shop_list: HBoxContainer = $Layout/ShopList
# 通路の宝箱の案内（段階19-c-2）。⚠ 開けずに戻ってきたときに出る。
@onready var corridor_chest_list: VBoxContainer = $Layout/CorridorChestList
# ⚠ 鞄は下の帯（2026-09-19・モック v2）。⚠ 左に「鞄 n/m」。
@onready var bag_grid: ItemGrid = $Layout/BagRow/BagGrid
@onready var bag_count_label: Label = $Layout/BagRow/BagCaption/BagCountLabel
@onready var bag_detail: ItemDetail = $Layout/BagDetail
@onready var descend_button: UiButton = $Layout/Footer/DescendButton
@onready var retreat_button: UiButton = $Layout/Footer/RetreatButton
@onready var abandon_button: UiButton = $Layout/Footer/AbandonButton
@onready var back_button: UiButton = $Layout/Header/BackButton

# 鞄のマスにホバーしたときの詳細（2026-09-07）。⚠ 押したときの「できること」は SlotActionPopover。
var _detail_popup: ItemDetailPopup = null

# ⚠ いま重ねている拾いもの／宝箱（決定36）。⚠ null なら出ていない。⚠ 二重に開かないための札。
var _loot_overlay: DungeonChest = null
# ⚠⚠ 重ねたものを閉じたあとに入るマス（決定36）。⚠ "" なら何もしない。
#   ⚠ これが無いと、⚠ 通路の宝箱を先に出したときに「着いたマスの中身」へ入り損ねる
#     （⚠ 不1 と同じ穴。⚠ 画面遷移ではなくなったので、⚠ 覚えておけば入り直せる）。
var _pending_node_entry: String = ""


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
	_say("")
	descend_button.pressed.connect(_on_descend_pressed)
	retreat_button.pressed.connect(_on_retreat_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	bag_grid.columns = GameManager.get_dungeon_bag_slots()
	bag_grid.slot_pressed.connect(_on_bag_slot_pressed)
	# ⚠ マスを押したら進む。⚠ 線を引き直すたびに（＝マスの位置が確定したら）スクロールを寄せる。
	map_view.node_pressed.connect(_on_node_pressed)
	map_view.laid_out.connect(_center_scroll_on_current)
	# ⚠ 詳細をドロップダウンへ移す（2026-09-07）。
	_detail_popup = ItemDetailPopup.adopt(self, bag_detail)
	if _detail_popup != null:
		_detail_popup.watch(bag_grid)
		_detail_popup.watch(relic_grid)
	_rebuild()

	# ⚠⚠ 戦闘から戻ったときの持ち物（決定31・決定36）。⚠ マップを組んでから重ねる。
	#   ⚠ 通路の宝箱が先（⚠ 「通路を歩いてから部屋に着く」の順）。
	#   ⚠ 「あとから開ける」ボタンは消した（⚠ 人間「宝箱はあとから開けれないようにしたい」）。
	#   ⚠ 開けずに閉じると捨てられるので、⚠ ここは二度は出ない。
	if GameManager.has_pending_dungeon_corridor_chest():
		_enter_corridor_chest()
	elif GameManager.has_dungeon_pending_loot():
		_enter_pickup()


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
	floor_label.text = "%s %d/%d" % [
		tr("ui_dungeon_floor"), GameManager.get_dungeon_floor_index(),
		GameManager.get_dungeon_max_floors(),
	]
	# ⚠⚠ たいまつの等級（決定32）。⚠ 2026-09-19 にフロアの行から分けた（モック v2 のヘッダ）。
	#   ⚠ 何層先まで見えているかが読めないと、⚠ ショップで買うかどうかを決められない。
	torch_label.text = "%s %s" % [
		Glyphs.TORCH,
		tr("ui_dungeon_torch_grade") % [
			GameManager.get_dungeon_torch_grade(), GameManager.get_dungeon_reveal_layers()
		],
	]
	currency_label.text = "%s %d" % [tr("ui_dungeon_currency"), GameManager.get_dungeon_currency()]
	var used: int = GameManager.get_dungeon_bag_used()
	var slots: int = GameManager.get_dungeon_bag_slots()
	bag_label.text = "%s %d/%d" % [tr("ui_dungeon_bag"), used, slots]
	# ⚠ 満杯ならヘッダの数字も赤（モック v2 §4）。⚠ 色は Theme の variation（⚠ 値を書かない）。
	bag_label.theme_type_variation = &"ErrorLabel" if used >= slots else &"MutedLabel"
	bag_count_label.text = "%d/%d" % [used, slots]
	_rebuild_relics()


# 持っているレリック（決定46）。⚠ 読む口は GameManager の1本（get_run_relic_slot_entries）。
func _rebuild_relics() -> void:
	var entries: Array = GameManager.get_run_relic_slot_entries(GameManager.RUN_KIND_DUNGEON)
	relic_grid.rebuild(entries, entries.size())
	# ⚠ 1つも無いときは区切りごと出さない（⚠ 空の欄を見せない）。
	relic_grid.visible = not entries.is_empty()
	$Layout/Header/RelicSep.visible = relic_grid.visible


# メッセージの行（2026-09-19・モック v2）。⚠ 良い知らせは緑・弾かれたら赤・ほかは素。
#   ⚠ 色は Theme の variation（GainLabel / ErrorLabel）。⚠ 値を書かない。
enum Tone { PLAIN, GOOD, WARN }


func _say(text: String, tone: Tone = Tone.PLAIN) -> void:
	message_label.text = text
	match tone:
		Tone.GOOD:
			message_label.theme_type_variation = &"GainLabel"
		Tone.WARN:
			message_label.theme_type_variation = &"ErrorLabel"
		_:
			message_label.theme_type_variation = &"MutedLabel"


# 3人の「戦闘時 MAX HP」。⚠ 素の MAX HP も併記する（§4-4）。
#
# ⚠ どれだけ目減りしたかが読めないと、ポーションを使う判断ができない。
# ⚠ 脱落は色と印で出す（§4-4-2）。⚠ 行ごと消さないこと。消すと「誰が欠けたか」が
#   分からないまま3人目で死亡する。
func _rebuild_party() -> void:
	party_list.refresh(GameManager.RUN_KIND_DUNGEON)


# いま立っているマスへスクロールを寄せる要求（段階20-c）。
#
# ⚠ 描き直したときに立て、⚠ 寄せたら下ろす。⚠ 毎回のレイアウトで寄せないため。
var _center_pending: bool = false


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
# ⚠⚠ 毎回は寄せない。⚠ 線はレイアウトのたびに引き直される（`laid_out`）ので、⚠ 毎回寄せると
#   手でスクロールできなくなる。⚠ 描き直したときだけ1回（`_center_pending`）。
func _center_scroll_on_current() -> void:
	if not _center_pending or map_scroll == null:
		return
	var position: String = str(
		GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")
	)
	var button: Control = map_view.get_node_button(position)
	if button == null:
		return
	# ⚠⚠ 中身が伸びるまで待つ。⚠ 伸びる前に入れても ScrollContainer が 0 に丸め、
	#   ⚠ 要求だけ消費して「先頭のまま」になる（⚠ 実測でそうなった）。
	#   ⚠ 消費しないで返る＝次のレイアウトでもう一度来る。
	var bar: ScrollBar = map_scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= map_scroll.size.y:
		return
	# ⚠⚠ `button.position` を使わない。⚠ あれは行（GridContainer）の中の座標で、
	#   ⚠ y がほぼ 0 になる（⚠ 最初はこれで書いてスクロールが 0 のままだった）。
	#   ⚠ 線を引くのと同じく global から MapArea の中の位置に直す。
	var center_y: float = (
		button.get_global_rect().get_center().y - map_view.get_global_rect().position.y
	)
	# ⚠ ScrollContainer が範囲の外を丸めてくれるので、⚠ ここで clamp しない。
	map_scroll.scroll_vertical = int(center_y - map_scroll.size.y * 0.5)
	_center_pending = false


# 通路の線の色の種類。⚠ 「良いか悪いか」だけを言う（⚠ 何が起きるかは絵文字）。
#   ⚠ 色そのものは RunMapView が持つ。
func _edge_tone(from_id: String, to_id: String, edge: Dictionary) -> String:
	if not GameManager.is_dungeon_edge_revealed(from_id, to_id):
		return RunMapView.TONE_HIDDEN
	match str(edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")):
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG:
			return RunMapView.TONE_TRAP
		GameStateKeys.DUNGEON_EDGE_EFFECT_CHEST, \
		GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE:
			return RunMapView.TONE_GAIN
	return RunMapView.TONE_PLAIN


# 層を縦に並べる。⚠ 下が入口・上がボス（引き返さない＝決定12）。
#
# ⚠ 並べ方・マス・線は RunMapView（2026-09-19）。⚠ ここは「描く材料」に直して渡すだけ。
#   ⚠ 進めるか・見えているか・通路に何があるかは GameManager に聞いた結果を渡す。
func _rebuild_layers() -> void:
	var run: Dictionary = GameManager.get_dungeon_run()
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var visited: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_VISITED, {})
	var position: String = str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var moves: Array = GameManager.get_dungeon_moves()

	# ⚠ 綴り順で回す（⚠ Dictionary のキー順は不定。⚠ 線の重なり順が起動ごとに変わらない）。
	var node_ids: Array = nodes.keys()
	node_ids.sort()
	var map_nodes: Array = []
	var map_edges: Array = []
	for raw_id: Variant in node_ids:
		var node_id: String = str(raw_id)
		var node: Dictionary = nodes[raw_id]
		var state: String = RunMapView.STATE_FAR
		if node_id == position:
			state = RunMapView.STATE_CURRENT
		elif visited.has(node_id):
			state = RunMapView.STATE_VISITED
		elif node_id in moves:
			state = RunMapView.STATE_REACHABLE
		map_nodes.append({
			RunMapView.NODE_ID: node_id,
			RunMapView.NODE_LAYER: int(node.get(GameStateKeys.DUNGEON_NODE_LAYER, 1)),
			RunMapView.NODE_TEXT: _node_text(node_id, node),
			RunMapView.NODE_STATE: state,
			RunMapView.NODE_HIDDEN: not GameManager.is_dungeon_node_revealed(node_id),
			RunMapView.NODE_BOSS: str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS,
		})
		# ⚠ 通路を読む口は get_dungeon_edges() の1本（台帳 §7「通路を str(entry) で読まない」）。
		for entry: Variant in GameManager.get_dungeon_edges(node_id):
			var edge: Dictionary = entry
			var to_id: String = str(edge.get(GameStateKeys.DUNGEON_EDGE_TO, ""))
			map_edges.append({
				RunMapView.EDGE_FROM: node_id,
				RunMapView.EDGE_TO: to_id,
				RunMapView.EDGE_TONE: _edge_tone(node_id, to_id, edge),
				RunMapView.EDGE_LABEL: _edge_label(node_id, to_id, edge),
			})
	# ⚠ たいまつの暗さ（2026-09-19・モック v2 §0）。⚠ 何層先まで見えるかは GameManager の1本に聞く。
	#   ⚠ ボスを倒したあと（⚠ 撤退できる＝決定15）は暗さを外す（モック §3「明かりが部屋いっぱいに広がる」）。
	map_view.torch_reveal_layers = (
		-1 if GameManager.can_retreat_from_dungeon() else GameManager.get_dungeon_reveal_layers()
	)
	# ⚠ 層の目盛りと区画の切れ目（2026-09-19・モック v2）。⚠ 切れ目の層は GameManager の1本に聞く。
	map_view.set_map(
		map_nodes, map_edges, _layer_captions(nodes, GameStateKeys.DUNGEON_NODE_LAYER,
			GameStateKeys.DUNGEON_NODE_KIND, GameStateKeys.DUNGEON_NODE_KIND_BOSS),
		GameManager.get_dungeon_segment_seams(), tr("ui_dungeon_segment_seam")
	)
	# ⚠⚠ 要求を立てるのは set_map() の「あと」（段階20-c）。
	#   ⚠ 先に立てると、⚠ set_map() の中で線を引いたときに消費されてしまう。⚠ そのときは
	#     まだレイアウト前でボタンの位置が 0 なので、⚠ スクロールが 0 のまま終わる
	#     （⚠ 実測でそうなった）。⚠ 次のレイアウトで寄せる。
	_center_pending = true


# 層の目盛りの字 {layer: "12層"}。⚠ ボスの層は 🏰 を前に付ける（モック v2）。
func _layer_captions(nodes: Dictionary, layer_key: String, kind_key: String, boss_kind: String) -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in nodes.values():
		var node: Dictionary = raw
		var layer: int = int(node.get(layer_key, 1))
		var text: String = tr("ui_dungeon_layer_no") % layer
		if str(node.get(kind_key, "")) == boss_kind:
			text = "%s %s" % [Glyphs.NODE_BOSS, text]
		result[layer] = text
	return result


# マスの文字。⚠ ▶ ✓ と札の見た目は RunMapView が付ける。
func _node_text(node_id: String, node: Dictionary) -> String:
	var kind: String = str(node.get(GameStateKeys.DUNGEON_NODE_KIND, ""))
	# たいまつ（段階17-e・§4-7）。⚠ 見えるかの判定は GameManager の1本に聞く。
	#   ⚠ 「押せるか」とは別物。⚠ 次の層は必ず押せるが、⚠ たいまつが弱いと中身は伏せる。
	#   ⚠ ここで層を引き算しないこと。
	# ⚠ 絵文字＋文字（段階19-a）。⚠ 対応表は Glyphs の1本だけ。
	#   ⚠ 絵文字だけにしない。⚠ フォントが入っていない環境で全部のマスが
	#     同じ豆腐になり、⚠ どれが何か分からなくなる（⚠ 文字が保険）。
	# ⚠ 通路の効果はここに出さない（段階20-c・人間の指示「通路の真ん中に表示して」）。
	if GameManager.is_dungeon_node_revealed(node_id):
		return "%s %s" % [Glyphs.for_dungeon_node(kind), tr("ui_dungeon_node_" + kind)]
	return "%s %s" % [Glyphs.NODE_HIDDEN, HIDDEN_TEXT]


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
	# ⚠ 描き直したら吹き出しは閉じる（⚠ 使い切って無くなっていることがある＝押しても何も起きないボタンになる）。
	_selected_bag_entry = {}
	SlotActionPopover.close_in(self)


func _on_bag_slot_pressed(entry: Dictionary, index: int) -> void:
	_selected_bag_entry = entry
	_open_bag_popover(index)


# 押した鞄のマスの近くに「できること」（2026-09-19・モック v2 §4）。⚠ ラン専用の品だけ「誰に使うか」が出る。
#
# ⚠⚠ 捨てる（決定41・2026-09-06。⚠ 人間「マップからアイテムを選んだら捨てられるように」）。
#   ⚠ 品の種類を問わず出す（⚠ 戦利品も捨てられる＝⚠ 鞄を空けるのが目的）。
#   ⚠ 口は `discard_dungeon_bag_item()` の1本。⚠ 入る・捨てるの判定を画面側に書かない。
#   ⚠ 文言は拾いもの画面と同じ `ui_dungeon_pickup_discard_bag`（⚠ 同じ意味に2つ目のキーを作らない）。
# ⚠ 脱落しているキャラのボタンは赤（⚠ 押しても use_dungeon_item() が弾く＝効く相手の判定を書かない）。
func _open_bag_popover(index: int) -> void:
	var item_id: String = str(_selected_bag_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	# ⚠ 空きマスを押したときは何も出さない（⚠ 押しても何も起きないボタンを作らない）。
	if item_id == "" or index >= bag_grid.get_child_count():
		SlotActionPopover.close_in(self)
		return
	var anchor: Rect2 = (bag_grid.get_child(index) as Control).get_global_rect()
	var pop: SlotActionPopover = SlotActionPopover.open(
		self, anchor, tr(GameManager.item_name_key(item_id)), ""
	)
	var usable: bool = GameManager.get_dungeon_item_effect(item_id) != ""
	if usable:
		for member: Variant in GameManager.get_party_members():
			var character_id: String = str(member)
			if character_id == "":
				continue
			var char_data: Dictionary = MasterDataLoader.get_character(character_id)
			var button: UiButton = pop.add_action(
				tr(str(char_data.get("name_key", character_id))),
				UiButton.Variant.DANGER if GameManager.is_dungeon_character_downed(character_id)
				else UiButton.Variant.SECONDARY,
				_on_use_potion_pressed.bind(item_id, character_id)
			)
			button.name = "Use_%s_%s" % [item_id, character_id]
	var discard: UiButton = pop.add_action(
		tr("ui_dungeon_pickup_discard_bag"), UiButton.Variant.GHOST,
		_on_discard_bag_pressed.bind(item_id)
	)
	discard.name = "Discard_" + item_id
	if usable:
		pop.set_note(tr("ui_dungeon_bag_use_note"))


# レリックのマス（段階17-e-2 → ⚠ 17-e-3 で別画面へ切り出した）。
#
# ⚠⚠ この画面には候補を出さない（人間の指示：「遺物や宝箱やショップは別画面でするべき」）。
#   ⚠ 出す先は `run_relic_select.tscn`（⚠ シナリオと1枚）。⚠ どのマスかは RUN_NODE_ID で渡す。
# ⚠ 候補を引くのは向こう。⚠ ここで引かないこと（⚠ 引く口を2箇所にしない）。
func _enter_relic_node(node_id: String) -> void:
	SceneManager.change_scene_with_data(
		RELIC_SELECT_PATH, {
			TransferKeys.RUN_KIND: GameManager.RUN_KIND_DUNGEON,
			TransferKeys.RUN_NODE_ID: node_id,
		}
	)


# 宝箱のマス（段階19-b → ⚠ 決定36 で重ねて出す形にした）。
#
# ⚠ 開ける／開けたかの判定はここに書かない。⚠ 向こうが GameManager に聞く。
func _enter_chest_node(node_id: String) -> void:
	_open_loot_overlay(node_id, false)


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

	# ⚠ 真鍮の主ボタン＋案内（2026-09-19・モック v2 §3）。⚠ ボスの後はここが一番押してほしい場所。
	var button: UiButton = UiButton.new()
	button.name = "ShopButton"
	button.variant = UiButton.Variant.PRIMARY
	button.text = "%s %s" % [Glyphs.NODE_SHOP, tr("ui_dungeon_shop_enter")]
	button.pressed.connect(_on_shop_pressed)
	shop_list.add_child(button)
	var caption: Label = Label.new()
	caption.name = "ShopCaption"
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_dungeon_shop_here")
	shop_list.add_child(caption)


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
	_open_loot_overlay("", true)


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
	# ⚠ 通路の罠で「戦闘時 MAX HP」がどれだけ減ったかを窓に出すため、⚠ 進む前の値を覚える（モック v2 §11）。
	#   ⚠ 読むだけ（⚠ 値は GameManager の口）。⚠ 減った量は GameManager の事件の記録が正。
	_hp_before_move = _party_max_hp()
	if not GameManager.move_in_dungeon(node_id):
		_say(tr("ui_dungeon_cannot_move"), Tone.WARN)
		return
	# ⚠⚠ 戦闘・ボスのマスは、割り込みより先に戦闘へ（不1・2026-09-05）。
	#   ⚠ 先に拾いもの／通路の宝箱の画面へ送ると、⚠ 戻ってきたときに「着いたマスの中身へ
	#     入る」口がもう無く、⚠ 戦闘が起きないまま次のマスへ進めてしまう
	#     （⚠ _ready() は拾い待ちしか見ない。⚠ _enter_node() を呼ぶのはここ1箇所だけ）。
	#   ⚠ 通路の宝箱と拾い待ちは戦闘から戻ったときに拾う（⚠ _ready() の末尾）。
	var kind: String = str(
		GameManager.get_dungeon_node(node_id).get(GameStateKeys.DUNGEON_NODE_KIND, "")
	)
	# 通路で何か起きたら知らせる（段階20-d・人間の指示「何かわかるような演出がしたい」）。
	# ⚠ マスの中身へ進む前に出す（⚠ 通路 → 部屋 の順と揃える）。
	_notify_edge_event()
	if kind == GameStateKeys.DUNGEON_NODE_KIND_BATTLE \
			or kind == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
		_enter_node(node_id)
		return
	# ⚠⚠ 通路の宝箱が先（段階19-c-2）。⚠ 着いたマスの中身より前に開けさせる
	#   （⚠ 「通路を歩いてから部屋に着く」の順。⚠ move_in_dungeon の中の順番と揃える）。
	#   ⚠ 開けずに閉じると捨てられる（決定31）。
	# ⚠⚠ 重ねて出すので、⚠ 閉じたあとに「着いたマスの中身」へ入り直す（決定36・_pending_node_entry）。
	if GameManager.has_pending_dungeon_corridor_chest():
		_pending_node_entry = node_id
		_enter_corridor_chest()
		return
	# ⚠⚠ 拾い待ちが出たら「何を鞄に入れるか」を選ばせる（段階20-e・人間の指示）。
	#   ⚠ 通路の資源がここに来る。⚠ 宝箱と同じ画面を使い回す（⚠ 人間の裁き）。
	if GameManager.has_dungeon_pending_loot():
		_pending_node_entry = node_id
		_enter_pickup()
		return
	_enter_node(node_id)


# 拾いものを出す（段階20-e → ⚠ 決定36 で重ねて出す形にした）。
#
# ⚠ 宝箱と同じ画面（⚠ 人間の裁き「宝箱の画面を使い回す」）。
# ⚠ どのマスかも通路かも渡さない。⚠ 拾い待ちの欄が正（⚠ 出どころに紐づかない）。
func _enter_pickup() -> void:
	_open_loot_overlay("", false)


# ⚠⚠ 拾いもの・宝箱をマップの上に重ねて出す（決定36・2026-09-05）。
#
# ⚠ 人間の指示「⚠ 戦闘と宝箱の報酬画面はモーダルで」。⚠ 4つの入口とも同じ扱い
#   （⚠ 戦闘 ／ マスの宝箱 ／ 通路の宝箱 ／ 通路の資源）。⚠ 同じ画面を2通りに描かない。
# ⚠⚠ 画面遷移をしないので、⚠ 戻ってきたときに「着いたマスの中身へ入る」口が要らない
#   （⚠ 不1 で踏んだ穴がそもそも開かない）。
# ⚠ CanvasLayer はここで作る（⚠ .tscn を触らない）。⚠ マップより手前に出す。
# ⚠ 二重に開かない。⚠ 開いているあいだにもう1枚積むと、⚠ 下の1枚が触れないまま残る。
func _open_loot_overlay(node_id: String, is_corridor: bool) -> void:
	if _loot_overlay != null and is_instance_valid(_loot_overlay):
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LootOverlayLayer"
	var overlay: DungeonChest = CHEST_SCENE.instantiate()
	overlay.open_as_overlay(node_id, is_corridor)
	overlay.closed.connect(_on_loot_overlay_closed.bind(layer))
	layer.add_child(overlay)
	add_child(layer)
	_loot_overlay = overlay


# 重ねたものが閉じた。⚠ 幕ごと片付けてから描き直す。
#
# ⚠ remove_child() してから queue_free()（AGENTS.md「再描画に await を持たせない」）。
# ⚠ 閉じたあとに拾い待ちが残っていることはない（⚠ 向こうの「戻る」が捨てる）。
func _on_loot_overlay_closed(layer: CanvasLayer) -> void:
	_loot_overlay = null
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	_rebuild()
	# ⚠⚠ 割り込みで後回しにしたマスの中身へ入り直す（決定36）。
	#   ⚠ 先に札を降ろすこと。⚠ _enter_node() が宝箱でもう1枚重ねる場合がある。
	if _pending_node_entry == "":
		return
	var next_node_id: String = _pending_node_entry
	_pending_node_entry = ""
	_enter_node(next_node_id)


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
			self, "ui_dungeon_edge_event_resource_full", [_item_names(left_behind)], false,
			_edge_window_options("resource_full", GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE,
				_item_cells(left_behind, true))
		)
		return

	# ⚠ 品を落とした／拾ったときは名前も出す。⚠ 無ければ数だけ。
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	var detail: String = _item_names(items) if not items.is_empty() else str(amount)
	# ⚠⚠ 窓の中身（2026-09-19・モック v2 §11）：罠（HP）＝3人の「前 → 後」 ／ 品が動いた＝マス目。
	var content: Control = null
	if effect == GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP:
		content = _hp_change_row()
	elif not items.is_empty():
		content = _item_cells(items, effect == GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG)
	var _dialog: ModalDialog = Modal.notify(
		self, "ui_dungeon_edge_event_" + effect, [detail], false,
		_edge_window_options(effect, effect, content)
	)


# 進む前の3人の「戦闘時 MAX HP」（⚠ 通路の罠の前後を並べるため）。
var _hp_before_move: Dictionary = {}


func _party_max_hp() -> Dictionary:
	var result: Dictionary = {}
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id != "":
			result[character_id] = GameManager.get_dungeon_character_max_hp(character_id)
	return result


# 窓の題（⚠ 絵文字＋何が起きたか）と中身。⚠ 題の絵文字は通路の字と同じ（Glyphs の1本）。
func _edge_window_options(title_suffix: String, glyph_effect: String, content: Control) -> Dictionary:
	var options: Dictionary = {
		Modal.OPTION_TITLE: "%s %s" % [
			Glyphs.for_dungeon_edge(glyph_effect), tr("ui_dungeon_edge_title_" + title_suffix)
		],
	}
	if content != null:
		options[Modal.OPTION_CONTENT] = content
	return options


# 3人の「前 → 後」（モック v2 §11「僧侶 98 → 58」）。⚠ 後の値は赤（ErrorLabel）。
func _hp_change_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "HpChange"
	row.theme_type_variation = &"WideRow"
	var after: Dictionary = _party_max_hp()
	for raw: Variant in after.keys():
		var character_id: String = str(raw)
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var cell: HBoxContainer = HBoxContainer.new()
		var before_label: Label = Label.new()
		before_label.theme_type_variation = &"MutedLabel"
		before_label.text = "%s %d →" % [
			tr(str(char_data.get("name_key", character_id))),
			int(_hp_before_move.get(character_id, after[raw])),
		]
		cell.add_child(before_label)
		var after_label: Label = Label.new()
		after_label.theme_type_variation = &"ErrorLabel"
		after_label.text = str(int(after[raw]))
		cell.add_child(after_label)
		row.add_child(cell)
	return row


# 品のマス目。⚠ 失ったものは薄く（⚠ 空きマスと同じ薄さ＝ItemSlot の値を使う）。
func _item_cells(items: Dictionary, lost: bool) -> Control:
	var grid: ItemGrid = ItemGrid.new()
	grid.name = "Items"
	grid.columns = 8
	var entries: Array = []
	var ids: Array = items.keys()
	ids.sort()
	for raw_id: Variant in ids:
		entries.append({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
			GameManager.SLOT_ENTRY_ITEM_ID: str(raw_id),
			GameManager.SLOT_ENTRY_INSTANCE_ID: "",
			GameManager.SLOT_ENTRY_GRADE: 0,
			GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
			GameManager.SLOT_ENTRY_COUNT: int(items[raw_id]),
		})
	grid.rebuild(entries, entries.size())
	if lost:
		grid.modulate = ItemSlot.EMPTY_MODULATE
	return grid


# {item_id: 個数} を「名前 xN, 名前 xN」の1行にする（段階20-d）。
#
# ⚠ 綴り順で並べる（⚠ Dictionary のキー順は不定。⚠ 起動ごとに並びが変わらない）。
# ⚠ 名前の翻訳キーは GameManager の1本（⚠ 宝箱は chests.json の name_key。⚠ 前は ui_res_ を決め打ちしていて、
#   ⚠ 罠（鞄）で宝箱を落とすと「ui_res_dungeon_chest」とキーがそのまま出ていた）。
func _item_names(items: Dictionary) -> String:
	var names: Array[String] = []
	var item_ids: Array = items.keys()
	item_ids.sort()
	for raw_id: Variant in item_ids:
		names.append("%s x%d" % [tr(GameManager.item_name_key(str(raw_id))), int(items[raw_id])])
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
			_say(tr("ui_dungeon_rested"), Tone.GOOD)
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
			_say(tr("ui_dungeon_node_not_ready"))
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
		_say(tr("ui_dungeon_potion_no_effect"), Tone.WARN)
		return
	_say(tr("ui_dungeon_potion_used"), Tone.GOOD)
	_rebuild()


# ⚠⚠ 鞄から1個捨てる（決定41）。⚠ 戻せない（⚠ 引き返さないので拾い直せない）。
#
# ⚠ 選んでいたものが無くなることがある（⚠ 最後の1個だった）。⚠ 選択を外してから描き直す
#   （⚠ 残すと「押しても何も起きないボタン」になる＝`_rebuild_bag()` と同じ理由）。
# ⚠ 確認は出していない。⚠ 倉庫（`ui_warehouse_discard_confirm`）と違い、
#   ⚠ ランの鞄は出れば全部消えるもの（決定7）なので、⚠ 取り返しのつかなさの度合いが違う。
func _on_discard_bag_pressed(item_id: String) -> void:
	if not GameManager.discard_dungeon_bag_item(item_id):
		_say(tr("ui_dungeon_bag_discard_failed"), Tone.WARN)
		return
	_say(tr("ui_dungeon_bag_discarded"))
	_selected_bag_entry = {}
	_rebuild()


# もう1枚潜る（決定15）。⚠ ランの MAX HP と鞄はそのまま持ち越す。
func _on_descend_pressed() -> void:
	if not GameManager.descend_dungeon_floor():
		_say(tr("ui_dungeon_cannot_descend"), Tone.WARN)
		return
	_say(tr("ui_dungeon_descended"), Tone.GOOD)
	_rebuild()


# 撤退する（鞄の中身を持ち帰ってラン終了）。⚠ ラン専用の品は消える（決定17）。
func _on_retreat_pressed() -> void:
	var result: Dictionary = GameManager.retreat_from_dungeon()
	var granted: Dictionary = result.get("granted", {})
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	_say("%s %d" % [tr("ui_dungeon_retreat_done"), granted.size()], Tone.GOOD)
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# その場で降りる＝全ロスト（§4-2）。⚠ 逃げ道は残す。⚠ ただしタダではない。
func _on_abandon_pressed() -> void:
	GameManager.abandon_dungeon_run()
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# 拠点へ。⚠ ランは終わらない（状態に残るので続きから再開できる）。
func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
