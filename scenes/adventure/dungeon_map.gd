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
# ⚠ ScrollContainer を使わない。中は scenario=layout で測れない。

extends Control

const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
# ⚠ 別画面に切り出したもの（段階17-e-3・人間の指示）。⚠ ここから遷移するだけ。
const RELIC_SELECT_PATH: String = "res://scenes/adventure/dungeon_relic_select.tscn"
const SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"

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

@onready var dungeon_name_label: Label = $Layout/Header/DungeonNameLabel
@onready var floor_label: Label = $Layout/Header/FloorLabel
@onready var currency_label: Label = $Layout/Header/CurrencyLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var party_list: HBoxContainer = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var layer_list: VBoxContainer = $Layout/LayerList
# 鞄はマス目（段階18-d）。⚠ 部品は倉庫と同じ。⚠ 引く先だけ別（器が別＝台帳 §7）。
# ボスの先のショップ（段階17-e）。⚠ 出るかどうかは GameManager に聞く。
@onready var shop_list: VBoxContainer = $Layout/ShopList
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

	message_label.text = ""
	descend_button.pressed.connect(_on_descend_pressed)
	retreat_button.pressed.connect(_on_retreat_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	bag_grid.columns = GameManager.get_dungeon_bag_slots()
	bag_grid.slot_pressed.connect(_on_bag_slot_pressed)
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
	_update_footer()


func _update_header() -> void:
	var run: Dictionary = GameManager.get_dungeon_run()
	var dungeon_id: String = str(run.get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
	dungeon_name_label.text = tr(str(dungeon.get("name_key", dungeon_id)))

	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	floor_label.text = "%s %d" % [tr("ui_dungeon_floor"), GameManager.get_dungeon_floor_index()]
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

	for layer: Variant in layers:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Layer_%d" % int(layer)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		for node_id: Variant in (by_layer[layer] as Array):
			row.add_child(_make_node_button(
				str(node_id), nodes[node_id], str(node_id) == position,
				visited.has(str(node_id)), str(node_id) in moves
			))
		layer_list.add_child(row)


func _make_node_button(
		node_id: String, node: Dictionary, is_current: bool, is_visited: bool, is_reachable: bool
) -> PrimaryButton:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = "Node_" + node_id
	var kind: String = str(node.get(GameStateKeys.DUNGEON_NODE_KIND, ""))
	# たいまつ（段階17-e・§4-7）。⚠ 見えるかの判定は GameManager の1本に聞く。
	#   ⚠ 「押せるか」とは別物。⚠ 次の層は必ず押せるが、⚠ たいまつが弱いと中身は伏せる。
	#   ⚠ ここで層を引き算しないこと。
	if GameManager.is_dungeon_node_revealed(node_id):
		button.text = tr("ui_dungeon_node_" + kind)
	else:
		button.text = HIDDEN_TEXT

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


# 続行・撤退はボスを倒した先だけ（決定15）。⚠ 判定は GameManager の1本に聞く。
func _update_footer() -> void:
	var can_retreat: bool = GameManager.can_retreat_from_dungeon()
	descend_button.visible = can_retreat
	retreat_button.visible = can_retreat
	# ⚠ 「その場で降りる」は常に出す。⚠ 消すと詰んだ人が閉じ込められる（§4-2）。
	abandon_button.visible = true


# マスを押した。⚠ 進めるかは GameManager が返す。こちらでは判定しない。
func _on_node_pressed(node_id: String) -> void:
	if not GameManager.move_in_dungeon(node_id):
		message_label.text = tr("ui_dungeon_cannot_move")
		return
	_enter_node(node_id)


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
