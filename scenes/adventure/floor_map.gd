# res://scenes/adventure/floor_map.gd
# フロアのマップ画面（段階14-c・EXEC_SCENARIO_MAP_SCREEN.md）。
#
# ⚠ この画面は状態を持たない。正は GameManager.get_floor_run() の1本だけ。
#   ⚠ ノードの並びも現在地も踏破済みも、毎回あちらから引き直して描く。
# ⚠ 進めるかの判定を自分で書かない。GameManager.get_available_moves() に聞く。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
# ⚠ ScrollContainer を使わない。中は scenario=layout で測れない。
# ⚠⚠ 層の並び・マス・つながりの線は難ダンジョンと同じ部品（RunMapView・2026-09-19・人間の決定
#   「全部推奨で」）。⚠ 画面は分けたまま（⚠ スタミナ・宝箱の演出・レリックの行はこちらだけ）。
#   ⚠ 線は色だけ（⚠ シナリオの通路には効果が無いので、⚠ 真ん中の字は出さない）。

extends Control

const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
# ⚠ レリック選択は難ダンジョンと1枚（2026-09-19）。⚠ ランの種類を渡す。
const RELIC_SELECT_PATH: String = "res://scenes/adventure/run_relic_select.tscn"
const SHOP_PATH: String = "res://scenes/adventure/floor_shop.tscn"
# ⚠ 拾いものの画面（2026-09-18）。⚠ 難ダンジョンと同じ画面を「シナリオの鞄」で使い回す。
const LOOT_WINDOW_SCENE: PackedScene = preload("res://scenes/adventure/run_loot_window.tscn")

# 中身が見えていないマスの表示（段階14-e）。
const HIDDEN_TEXT: String = "？"

# 宝箱を見つけたときの演出（段階14-g）。
#
# ⚠ 台帳 §4-5「レアリティは開封前から見た目で判別できる。隠さず全て可視化する」。
# ⚠ レアリティの綴りは GameManager から受け取る。chest_id から切り出さないこと。
#
# ⚠ 色そのものはここに持たない。Balance.icon（IconConfig）の10色ランプの
#   1 / 4 / 7 / 10 番目が、以前ここにあった 灰 / 青 / 紫 / 金 と同じ値になっている
#   （2026-08-31・仮アセットのアイコンと同じ見た目の言語に揃えた）。
#   ⚠ ここに const で色を戻さないこと。宝箱とアイコンで色が食い違う。
# ⚠ ここが持つのは「どのレアリティが何段目か」の綴りだけ。
# ⚠⚠ 2026-09-18：表は `GameManager.CHEST_RARITY_TIERS` へ移した（⚠ 宝箱の一覧でも同じ色を使う）。
# 演出の長さ（秒）。⚠ ここを 0 にしないこと。0 にすると戦闘マスでは
#   遷移が即座に走り、見つけたことが一度も見えない（それが直前の症状）。
const CHEST_POPUP_SEC: float = 0.9

# ⚠ マスと線の色は RunMapView が持つ（2026-09-19）。⚠ ここに戻さないこと。

@onready var floor_name_label: Label = $Layout/Header/FloorNameLabel
@onready var chest_label: Label = $Layout/Header/ChestLabel
@onready var chest_popup: Label = $ChestPopup
# ⚠ 2026-09-26（人間「⚠ ヘッダーにレリックを並べる」「⚠ フッターにHPなどを」「⚠ シナリオは同じUI」）：
#   ⚠ レリックはヘッダーのマス（⚠ 押すとまとめて見る窓）。⚠ 3人の HP はフッター。⚠ 難ダンジョンと同じ形。
@onready var relic_grid: ItemGrid = $Layout/Header/RelicGrid
@onready var party_list: RunPartyStrip = $Layout/Footer/PartyList
# ⚠ ヘッダーのレリックのホバーの詳細 ／ 右上の通貨の幅ぶんの空き。
var _detail_popup: ItemDetailPopup = null
var _hud_spacer: Control = null
@onready var message_label: Label = $Layout/MessageLabel
@onready var map_view: RunMapView = $Layout/MapView

# ⚠⚠ 鞄のマス目（2026-09-18・人間の決定「難ダンジョンのインベントリをシナリオでも適用」）。
#   ⚠ .tscn を触らずコードで作る（⚠ レリックの行の下）。⚠ 中身は GameManager の鞄の口に聞く。
var _bag_grid: ItemGrid = null
# 重ねて出している拾いものの画面。⚠ 二重に開かない。
var _loot_overlay: RunLootWindow = null


func _ready() -> void:
	SceneManager.consume_transfer_data()
	# ⚠⚠ シナリオでは右上の通貨を**出す**（2026-09-20・人間の指示「⚠ シナリオにもリソースを」）。
	#   ⚠ 消すのは難ダンジョンだけ（⚠ あちらは一時通貨で回すので拠点の資源が要らない）。
	#   ⚠ 既定で出るので、⚠ ここでは何もしない（SceneManager が画面を移るたびに出す）。

	# フロアに入っていないのにここへ来た（セーブを消した直後など）。
	# ⚠ 空のマップを描かず、冒険選択へ戻す。
	if not GameManager.is_in_floor():
		push_warning("[FloorMap] フロアに入っていないので冒険選択へ戻る")
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return

	message_label.text = ""
	# ⚠⚠ 「戻る」と「フロアを降りる」は右上のメニューへ（⚠ 難ダンジョンと同じ）。
	var menu: RunMenuButton = RunMenuButton.new()
	$Layout/Header.add_child(menu)
	var _back_item: UiButton = menu.add_item(tr("ui_common_suspend_to_base"), _on_back_pressed)
	var _relic_item: UiButton = menu.add_item(tr("ui_relic_list_open"), _open_relic_list)
	var _abandon_item: UiButton = menu.add_item(tr("ui_floor_abandon"), _on_abandon_pressed, true)
	relic_grid.slot_pressed.connect(func(_entry: Dictionary, _index: int) -> void: _open_relic_list())
	_detail_popup = ItemDetailPopup.adopt(self, ItemDetail.new())
	if _detail_popup != null:
		_detail_popup.watch(relic_grid)
	# ⚠ 右上の通貨（⚠ シナリオでは出す）とメニューが重ならないよう、⚠ 通貨の幅だけ空ける（⚠ `ScreenHeader` と同じ）。
	_hud_spacer = Control.new()
	_hud_spacer.name = "HudSpacer"
	_hud_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Layout/Header.add_child(_hud_spacer)
	_apply_hud_width(ResourceHud.reserved_width())
	var hud: ResourceHud = ResourceHud.get_instance()
	if hud != null:
		hud.width_changed.connect(_apply_hud_width)
	GameManager.floor_run_changed.connect(_on_floor_run_changed)
	GameManager.floor_chest_found.connect(_on_chest_found)
	map_view.node_pressed.connect(_on_node_pressed)
	# ⚠ スクロールを持たない画面なので層の間隔を詰める（⚠ 44 だと縦に 2px はみ出した）。
	map_view.layer_separation = RunMapView.LAYER_SEPARATION_NO_SCROLL
	# ⚠ 紙を上下にはみ出させない（⚠ 下のフッターの HP に重なるため・2026-09-26）。
	map_view.sheet_bleed_vertical = false
	_build_bag_grid()
	_rebuild()
	# ⚠ 戦闘・ショップ・レリックから戻ってきたとき、⚠ 拾い待ちがあれば選ぶ画面を出す。
	_open_pickup_if_needed()


# 鞄のマス目を作る（2026-09-18）。⚠ 1回だけ。
func _build_bag_grid() -> void:
	_bag_grid = ItemGrid.new()
	_bag_grid.name = "BagGrid"
	_bag_grid.columns = maxi(1, GameManager.get_run_bag_slots(GameManager.RUN_KIND_FLOOR))
	# ⚠ 鞄はヘッダーのすぐ下（⚠ 前はレリックの行の下＝その行は 2026-09-26 に消した）。
	var header: Node = $Layout/Header
	var layout: Node = header.get_parent()
	layout.add_child(_bag_grid)
	layout.move_child(_bag_grid, header.get_index() + 1)


func _rebuild_bag() -> void:
	if _bag_grid == null:
		return
	_bag_grid.rebuild(
		GameManager.get_run_bag_slot_layout(GameManager.RUN_KIND_FLOOR),
		GameManager.get_run_bag_slots(GameManager.RUN_KIND_FLOOR)
	)


# 拾い待ちがあれば、⚠ 難ダンジョンと同じ拾いものの画面をマップの上に重ねて出す（2026-09-18）。
#
# ⚠ 出どころ（宝箱・道中の戦利品）は渡さない。⚠ 拾い待ちの欄が正。
# ⚠ 閉じると残りは捨てられる（⚠ 向こうの「戻る」が捨てる＝難ダンジョンと同じ）。
func _open_pickup_if_needed() -> void:
	if not GameManager.has_run_pending_loot(GameManager.RUN_KIND_FLOOR):
		return
	if _loot_overlay != null and is_instance_valid(_loot_overlay):
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LootOverlayLayer"
	var overlay: RunLootWindow = LOOT_WINDOW_SCENE.instantiate()
	overlay.open_as_overlay("", false, GameManager.RUN_KIND_FLOOR)
	overlay.closed.connect(_on_loot_overlay_closed.bind(layer))
	layer.add_child(overlay)
	add_child(layer)
	_loot_overlay = overlay


# ⚠ remove_child() してから queue_free()（AGENTS.md「再描画に await を持たせない」）。
func _on_loot_overlay_closed(layer: CanvasLayer) -> void:
	# ⚠ 閉じたときに自動で入れた結果を見せる（決定40・モック v2 §8）。⚠ 難ダンジョンと同じ見せ方。
	if _loot_overlay != null and is_instance_valid(_loot_overlay):
		var line: String = RunLootWindow.present_auto_result(self, _loot_overlay.get_auto_result())
		if line != "":
			message_label.modulate = Color.WHITE
			message_label.text = line
	_loot_overlay = null
	if is_instance_valid(layer):
		remove_child(layer)
		layer.queue_free()
	_rebuild()


func _on_floor_run_changed(_floor_id: String) -> void:
	if not GameManager.is_in_floor():
		return
	_rebuild()


func _rebuild() -> void:
	_update_header()
	_rebuild_layers()
	_rebuild_bag()


func _update_header() -> void:
	var run: Dictionary = GameManager.get_floor_run()
	var floor_id: String = str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, ""))
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	floor_name_label.text = tr(str(stage.get("name_key", floor_id)))

	# 数値のみなので tr() は通さない（AGENTS.md）。
	# ⚠⚠ 2026-09-18：⚠ 数字は**鞄の使用数／枠**（⚠ ボスを倒すと中身を持ち帰る・負けたら失う）。
	#   ⚠ 前は「このフロアで出た宝箱の数」（`get_floor_chest_count()`＝最低1回保証の数え方）だった。
	chest_label.text = "%s %d/%d  %s %d(%d%s)" % [
		tr("ui_dungeon_bag"),
		GameManager.get_run_bag_used(GameManager.RUN_KIND_FLOOR),
		GameManager.get_run_bag_slots(GameManager.RUN_KIND_FLOOR),
		tr("ui_floor_torch"), GameManager.get_floor_torch_grade(),
		GameManager.get_floor_reveal_layers(), tr("ui_floor_torch_layers"),
	]
	_update_relic_line()
	# ⚠⚠ スタミナはこの行に出さない（2026-09-20）。⚠ 右上の常駐の通貨（ResourceHud）が
	#   ⚠ 金・ジェム・スタミナをまとめて出す（⚠ 人間の指示「⚠ シナリオにもリソースを」）。⚠ 同じ数字を2箇所に出さない。


# いま持っているレリック（段階14-d → 2026-09-26 にヘッダーのマスへ）。
#
# ⚠ 1人用は「誰に付いているか」をマスの詳細（ホバー）とまとめて見る窓に出す（⚠ 選んだ意味が確かめられること）。
# ⚠ 3人の HP もここで描き直す（⚠ 戦闘から戻るたびに変わる）。
func _update_relic_line() -> void:
	var entries: Array = GameManager.get_run_relic_slot_entries(GameManager.RUN_KIND_FLOOR)
	relic_grid.rebuild(entries, entries.size())
	relic_grid.visible = not entries.is_empty()
	party_list.refresh(GameManager.RUN_KIND_FLOOR)


# 層を縦に並べる。⚠ 下が入口・上がボス。
#
# ⚠ 並べ方・マス・線は RunMapView（2026-09-19）。⚠ ここは「描く材料」に直して渡すだけ。
#   ⚠ 進めるか・見えているかは GameManager に聞いた結果を渡す。
func _rebuild_layers() -> void:
	var run: Dictionary = GameManager.get_floor_run()
	var nodes: Dictionary = run.get(GameStateKeys.FLOOR_RUN_NODES, {})
	var visited: Dictionary = run.get(GameStateKeys.FLOOR_RUN_VISITED, {})
	var position: String = str(run.get(GameStateKeys.FLOOR_RUN_POSITION, ""))
	var moves: Array = GameManager.get_available_moves()

	# ⚠ Dictionary のキー順は不定なので、必ず綴り順で回す（⚠ 線の重なり順も揃う）。
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
			RunMapView.NODE_LAYER: int(node.get(GameStateKeys.FLOOR_NODE_LAYER, 1)),
			RunMapView.NODE_TEXT: _node_text(node_id, node),
			RunMapView.NODE_STATE: state,
			RunMapView.NODE_HIDDEN: not GameManager.is_floor_node_revealed(node_id),
			RunMapView.NODE_BOSS: str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_BOSS,
		})
		# ⚠ つながり（FLOOR_NODE_NEXT は [node_id]）。⚠ 効果は無いので色は「見えているか」だけ。
		#   ⚠ 見えているかは行き先のマスで決める（⚠ 難ダンジョンの is_dungeon_edge_revealed と同じ考え）。
		for entry: Variant in (node.get(GameStateKeys.FLOOR_NODE_NEXT, []) as Array):
			var to_id: String = str(entry)
			map_edges.append({
				RunMapView.EDGE_FROM: node_id,
				RunMapView.EDGE_TO: to_id,
				RunMapView.EDGE_TONE: (
					RunMapView.TONE_PLAIN if GameManager.is_floor_node_revealed(to_id)
					else RunMapView.TONE_HIDDEN
				),
			})
	# ⚠ 層の目盛り（2026-09-19・モック v2）。⚠ シナリオに区画は無いので切れ目は無し。
	var captions: Dictionary = {}
	for raw: Variant in nodes.values():
		var layer: int = int((raw as Dictionary).get(GameStateKeys.FLOOR_NODE_LAYER, 1))
		captions[layer] = tr("ui_floor_layer_no") % layer
	# ⚠ たいまつの暗さ（2026-09-19・モック v2 §0）。⚠ シナリオにもたいまつがあるので同じ見せ方。
	map_view.torch_reveal_layers = GameManager.get_floor_reveal_layers()
	map_view.set_map(map_nodes, map_edges, captions)


# マスの文字。⚠ ▶ ✓ と札の見た目は RunMapView が付ける。
#
# 視界（段階14-e）。⚠ 見えるかどうかの判定は GameManager の1本に聞く。
#   ⚠ 「押せるか」とは別物。次の層は必ず押せるが、たいまつが弱いと中身は伏せられる。
# ⚠ 絵文字＋文字（2026-09-19・難ダンジョンに揃えた）。⚠ 絵文字だけにしない（⚠ 文字が保険）。
func _node_text(node_id: String, node: Dictionary) -> String:
	var kind: String = str(node.get(GameStateKeys.FLOOR_NODE_KIND, ""))
	if GameManager.is_floor_node_revealed(node_id):
		return "%s %s" % [Glyphs.for_floor_node(kind), tr("ui_floor_node_" + kind)]
	return "%s %s" % [Glyphs.NODE_HIDDEN, HIDDEN_TEXT]


# この移動で見つけた宝箱。⚠ move_to_node() の途中でシグナルが飛んでくるので、
#   ⚠ ここで受けてから遷移の前に演出を出す（段階14-g）。
var _found_chest_id: String = ""
var _found_rarity: String = ""


# 宝箱が出た。⚠ ここでは記録するだけ。演出は _on_node_pressed() が出す。
#
# ⚠ ここで直接 change_scene しないこと。move_to_node() の途中で呼ばれているので、
#   状態を書き終える前に画面が消える。
func _on_chest_found(chest_id: String, rarity: String) -> void:
	_found_chest_id = chest_id
	_found_rarity = rarity


# マスを押した。⚠ 進んでから種類で分ける。
#   ⚠ 進めなければ GameManager が false を返すので、こちらでは判定しない。
func _on_node_pressed(node_id: String) -> void:
	_found_chest_id = ""
	_found_rarity = ""
	# ⚠ 前の移動でレアリティの色に染めているので、必ず白へ戻す。
	#   戻さないと「休憩した」がレジェンダリーの金色で出る。
	message_label.modulate = Color.WHITE
	if not GameManager.move_to_node(node_id):
		message_label.text = tr("ui_floor_cannot_move")
		return

	# 宝箱が出ていたら、⚠ 先に見せてから先へ進む（段階14-g）。
	#   ⚠ 戦闘マスへの移動はすぐ遷移するので、⚠ 待たせないと一度も見えない。
	if _found_chest_id != "":
		_play_chest_popup(node_id)
		return
	_enter_node(node_id)


# 宝箱の演出。⚠ 終わってから _enter_node() を呼ぶ。
#
# ⚠ await を使わず、Tween の finished に繋ぐ。await にすると、途中で
#   画面が外れたときに解放済みのノードを触る。
func _play_chest_popup(node_id: String) -> void:
	var chest: Dictionary = MasterDataLoader.get_chest(_found_chest_id)
	var chest_name: String = tr(str(chest.get(GameManager.CHEST_NAME_KEY, _found_chest_id)))
	var color: Color = Balance.icon.color_of_grade(
		Balance.icon.grade_of_tier(int(GameManager.CHEST_RARITY_TIERS.get(_found_rarity, 1)), false)
	)

	chest_popup.text = "%s\n%s" % [tr("ui_floor_chest_found"), chest_name]
	chest_popup.modulate = Color(color.r, color.g, color.b, 0.0)
	chest_popup.scale = Vector2(0.6, 0.6)
	chest_popup.visible = true
	# メッセージ行にも残す。⚠ 演出は消えるが、こちらは次の移動まで読める。
	message_label.text = "%s %s" % [tr("ui_floor_chest_found"), chest_name]
	message_label.modulate = color
	_update_header()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(chest_popup, "modulate:a", 1.0, CHEST_POPUP_SEC * 0.3)
	tween.tween_property(chest_popup, "scale", Vector2(1.0, 1.0), CHEST_POPUP_SEC * 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(CHEST_POPUP_SEC * 0.4)
	tween.tween_property(chest_popup, "modulate:a", 0.0, CHEST_POPUP_SEC * 0.3)
	tween.finished.connect(_enter_node.bind(node_id))


# 踏んだマスの中身へ進む。⚠ 種類ごとの分岐はここ1本。
func _enter_node(node_id: String) -> void:
	chest_popup.visible = false
	var node: Dictionary = GameManager.get_floor_node(node_id)
	var kind: String = str(node.get(GameStateKeys.FLOOR_NODE_KIND, ""))

	match kind:
		GameStateKeys.FLOOR_NODE_KIND_BATTLE, GameStateKeys.FLOOR_NODE_KIND_BOSS:
			_enter_battle(node_id)
		GameStateKeys.FLOOR_NODE_KIND_REST:
			var _ok: bool = GameManager.rest_at_node()
			message_label.text = tr("ui_floor_rested")
			# ⚠ 休憩はマップに留まる。⚠ 途中で拾った宝箱があればここで選ばせる（2026-09-18）。
			_open_pickup_if_needed()
		GameStateKeys.FLOOR_NODE_KIND_RELIC:
			# ⚠ 選ばずに出られない画面へ移る（段階14-d）。踏んだら必ず1つ取る。
			SceneManager.change_scene_with_data(RELIC_SELECT_PATH, {
				TransferKeys.RUN_KIND: GameManager.RUN_KIND_FLOOR,
				TransferKeys.RUN_NODE_ID: node_id,
			})
		GameStateKeys.FLOOR_NODE_KIND_SHOP:
			# ⚠ 入店した瞬間に無料ガチャが1回引かれる（段階14-e）。
			SceneManager.change_scene(SHOP_PATH)
		_:
			# ⚠ 知らない種類。⚠ 行き止まりにしないこと。
			#   踏むと詰むノードがあるとフロアがクリアできない。
			push_warning("[FloorMap] 知らないノードの種類: " + kind)
			message_label.text = tr("ui_floor_node_not_ready")
			_rebuild()


func _enter_battle(node_id: String) -> void:
	SceneManager.change_scene_with_data(
		BATTLE_PATH,
		{
			TransferKeys.STAGE_ID: str(GameManager.get_floor_run().get(
				GameStateKeys.FLOOR_RUN_FLOOR_ID, ""
			)),
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
			TransferKeys.FLOOR_NODE_ID: node_id,
		}
	)


# フロアを降りる。⚠ 進行中のものは全部消える（たいまつ・レリック・持ち越しHP）。
# ⚠ 2026-09-26：⚠ メニューから呼ぶ。⚠ **確かめの窓を通す**（⚠ 前は押した瞬間に消えていた）。
func _on_abandon_pressed() -> void:
	var sure: bool = await Modal.confirm(self, "ui_floor_abandon_confirm", [], false, {
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_floor_abandon",
	})
	if not sure:
		return
	GameManager.abandon_floor()
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# 拠点へ。⚠ フロアは降りない。状態に残るので続きから再開できる。
func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)


func _open_relic_list() -> void:
	var _window: RunRelicListWindow = RunRelicListWindow.open(self, GameManager.RUN_KIND_FLOOR)


func _apply_hud_width(width: float) -> void:
	if _hud_spacer != null:
		_hud_spacer.custom_minimum_size = Vector2(maxf(0.0, width), 0.0)
