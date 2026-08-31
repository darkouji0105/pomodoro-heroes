# res://scenes/adventure/floor_map.gd
# フロアのマップ画面（段階14-c・EXEC_SCENARIO_MAP_SCREEN.md）。
#
# ⚠ この画面は状態を持たない。正は GameManager.get_floor_run() の1本だけ。
#   ⚠ ノードの並びも現在地も踏破済みも、毎回あちらから引き直して描く。
# ⚠ 進めるかの判定を自分で書かない。GameManager.get_available_moves() に聞く。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
# ⚠ ScrollContainer を使わない。中は scenario=layout で測れない。

extends Control

const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const RELIC_SELECT_PATH: String = "res://scenes/adventure/floor_relic_select.tscn"
const SHOP_PATH: String = "res://scenes/adventure/floor_shop.tscn"

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
const CHEST_RARITY_TIERS: Dictionary = {
	GameManager.CHEST_RARITY_COMMON: 1,
	GameManager.CHEST_RARITY_RARE: 2,
	GameManager.CHEST_RARITY_EPIC: 3,
	GameManager.CHEST_RARITY_LEGENDARY: 4,
}
# 演出の長さ（秒）。⚠ ここを 0 にしないこと。0 にすると戦闘マスでは
#   遷移が即座に走り、見つけたことが一度も見えない（それが直前の症状）。
const CHEST_POPUP_SEC: float = 0.9

# マスの見た目。⚠ 色はここに置く（main_theme.tres に対応する概念が無い。
#   adventure_config の pop_*_color と同じ扱い）。
const COLOR_CURRENT: Color = Color(1.0, 0.95, 0.55)
const COLOR_VISITED: Color = Color(0.45, 0.45, 0.5)
const COLOR_REACHABLE: Color = Color(1.0, 1.0, 1.0)
const COLOR_FAR: Color = Color(0.6, 0.6, 0.65)

@onready var floor_name_label: Label = $Layout/Header/FloorNameLabel
@onready var chest_label: Label = $Layout/Header/ChestLabel
@onready var stamina_value: ResourceDisplay = $Layout/Header/StaminaValue
@onready var chest_popup: Label = $ChestPopup
@onready var relic_label: Label = $Layout/RelicLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var layer_list: VBoxContainer = $Layout/LayerList
@onready var abandon_button: PrimaryButton = $Layout/Footer/AbandonButton
@onready var back_button: PrimaryButton = $Layout/Footer/BackButton


func _ready() -> void:
	SceneManager.consume_transfer_data()

	# フロアに入っていないのにここへ来た（セーブを消した直後など）。
	# ⚠ 空のマップを描かず、冒険選択へ戻す。
	if not GameManager.is_in_floor():
		push_warning("[FloorMap] フロアに入っていないので冒険選択へ戻る")
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return

	message_label.text = ""
	abandon_button.pressed.connect(_on_abandon_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.floor_run_changed.connect(_on_floor_run_changed)
	GameManager.resource_changed.connect(_on_resource_changed)
	GameManager.floor_chest_found.connect(_on_chest_found)
	_rebuild()


func _on_floor_run_changed(_floor_id: String) -> void:
	if not GameManager.is_in_floor():
		return
	_rebuild()


func _on_resource_changed(resource_type: String, _new_value: Variant) -> void:
	if resource_type == GameStateKeys.STAMINA:
		_update_header()


func _rebuild() -> void:
	_update_header()
	_rebuild_layers()


func _update_header() -> void:
	var run: Dictionary = GameManager.get_floor_run()
	var floor_id: String = str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, ""))
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	floor_name_label.text = tr(str(stage.get("name_key", floor_id)))

	# 数値のみなので tr() は通さない（AGENTS.md）。
	chest_label.text = "%s: %d  %s %d(%d%s)" % [
		tr("ui_floor_chest_count"), GameManager.get_floor_chest_count(),
		tr("ui_floor_torch"), GameManager.get_floor_torch_grade(),
		GameManager.get_floor_reveal_layers(), tr("ui_floor_torch_layers"),
	]
	_update_relic_line()

	var state: Dictionary = GameManager.get_state()
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	stamina_value.set_value_with_max(
		int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
		int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	)


# いま持っているレリックの1行（段階14-d・PLAN_SCENARIO_MAP.md §5-2-6）。
#
# ⚠ 専用の画面を作らない。フロア中はここが唯一の一覧なので、常に見えていること。
# ⚠ 1人用は「誰に付いているか」まで出す。出さないと選んだ意味が確かめられない。
func _update_relic_line() -> void:
	var relics: Array = GameManager.get_floor_relics()
	if relics.is_empty():
		relic_label.text = tr("ui_relic_none")
		return
	var parts: Array[String] = []
	for entry: Variant in relics:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var relic_id: String = str(row.get(GameStateKeys.FLOOR_RELIC_ID, ""))
		var name_text: String = tr(str(
			MasterDataLoader.get_relic(relic_id).get("name_key", relic_id)
		))
		var owner: String = str(row.get(GameStateKeys.FLOOR_RELIC_CHARACTER_ID, ""))
		if owner == "":
			parts.append(name_text)
			continue
		var char_data: Dictionary = MasterDataLoader.get_character(owner)
		parts.append("%s(%s)" % [name_text, tr(str(char_data.get("name_key", owner)))])
	relic_label.text = tr("ui_relic_held") + ": " + " / ".join(parts)


# 層を縦に並べる。⚠ 下が入口・上がボス。
func _rebuild_layers() -> void:
	# ⚠ queue_free() だけだと、同じフレームに2本走ったとき行が二重に並ぶ。
	for child in layer_list.get_children():
		layer_list.remove_child(child)
		child.queue_free()

	var run: Dictionary = GameManager.get_floor_run()
	var nodes: Dictionary = run.get(GameStateKeys.FLOOR_RUN_NODES, {})
	var visited: Dictionary = run.get(GameStateKeys.FLOOR_RUN_VISITED, {})
	var position: String = str(run.get(GameStateKeys.FLOOR_RUN_POSITION, ""))
	var moves: Array = GameManager.get_available_moves()

	# 層ごとに仕分ける。⚠ Dictionary のキー順は不定なので、必ず綴り順で並べる。
	var by_layer: Dictionary = {}
	var node_ids: Array = nodes.keys()
	node_ids.sort()
	for node_id: Variant in node_ids:
		var node: Dictionary = nodes[node_id]
		var layer: int = int(node.get(GameStateKeys.FLOOR_NODE_LAYER, 1))
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
	var kind: String = str(node.get(GameStateKeys.FLOOR_NODE_KIND, ""))
	# 視界（段階14-e）。⚠ 見えるかどうかの判定は GameManager の1本に聞く。
	#   ⚠ 「押せるか」とは別物。次の層は必ず押せるが、たいまつが弱いと中身は伏せられる。
	if GameManager.is_floor_node_revealed(node_id):
		button.text = tr("ui_floor_node_" + kind)
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

	# ⚠ 進める先だけ押せる。判定は GameManager に聞いた結果をそのまま使う。
	button.disabled = not is_reachable
	if is_reachable:
		button.pressed.connect(_on_node_pressed.bind(node_id))
	return button


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
		Balance.icon.grade_of_tier(int(CHEST_RARITY_TIERS.get(_found_rarity, 1)), false)
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
		GameStateKeys.FLOOR_NODE_KIND_RELIC:
			# ⚠ 選ばずに出られない画面へ移る（段階14-d）。踏んだら必ず1つ取る。
			SceneManager.change_scene(RELIC_SELECT_PATH)
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
func _on_abandon_pressed() -> void:
	GameManager.abandon_floor()
	SceneManager.change_scene(ADVENTURE_SELECT_PATH)


# 拠点へ。⚠ フロアは降りない。状態に残るので続きから再開できる。
func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
