# res://scenes/guild/research_screen.gd
# ギルド：研究画面（第1弾＝レベル上限の解放と全ステータス上昇）。
# 1画面のみ。育成画面と違い詳細は作らない（ノードあたりの情報量が少ないため）。
#
# ノード行は research.json から生成する。ノードIDを決め打ちしないこと。

class_name ResearchScreen
extends Control

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# research.json 側のキー。状態ではないため GameStateKeys には置かない。
const NODE_NAME_KEY: String = "name_key"
const NODE_SORT_ORDER: String = "sort_order"

# ⚠ カテゴリの見出しは、出てきた順にそのまま作る（段階10）。
#   ⚠ 画面に if を1つも書かないこと。研究の枝を増やす回に、ここを直さずに済ませるため
#     （ja.csv に "ui_research_category_<category>" を1行足せば見出しが出る）。
const CATEGORY_KEY_PREFIX: String = "ui_research_category_"

@onready var material_label: Label = $Margin/Layout/MaterialLabel
@onready var cap_label: Label = $Margin/Layout/CapLabel
@onready var node_list: VBoxContainer = $Margin/Layout/Scroll/NodeList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	# 解放の結果は戻り値ではなくシグナルで受けて描画し直す。
	# 素材は戦闘報酬でも増えるため material_changed にも繋ぐ。
	GameManager.research_node_unlocked.connect(_on_research_node_unlocked)
	GameManager.material_changed.connect(_on_material_changed)

	_refresh()


# --- 描画 ---

func _refresh() -> void:
	_refresh_header()
	_build_node_list()


func _refresh_header() -> void:
	# get_effective_level_cap() は character_id を使わない実装（全キャラ共通の上限）。
	# 代表キャラを決め打ちしないため空文字を渡す。
	var board: int = GameManager.get_current_research_board()
	var progress: Dictionary = GameManager.get_research_board_progress(board)
	cap_label.text = "%s　%s" % [
		tr("ui_research_cap") % GameManager.get_effective_level_cap(""),
		tr("ui_research_board") % [
			board,
			int(progress.get("unlocked", 0)),
			int(progress.get("total", 0)),
		],
	]

	# ⚠ 素材は1種類ではない（ノードごとに種類を変えて競合を分散させる・GAME_DESIGN 9-1）。
	#   ⚠ 出すのは「今のボードで使う素材」だけ。全16種を並べると読めない。
	var parts: Array[String] = []
	for material_id: String in _board_material_ids(board):
		parts.append("%s %d" % [
			tr("ui_res_" + material_id),
			GameManager.get_material_count(material_id),
		])
	material_label.text = "　".join(parts)


func _build_node_list() -> void:
	# ⚠ remove_child() してから queue_free() する。1回の解放で research_node_unlocked と
	#   material_changed が続けて飛ぶため、queue_free() だけだと行が二重に並ぶ
	#   （AGENTS.md「再描画は await を持たせない」・ショップで実際に踏んだ形）。
	for child in node_list.get_children():
		node_list.remove_child(child)
		child.queue_free()

	var tree: Dictionary = GameManager.get_research_tree()
	if tree.is_empty():
		# research.json が読めていない。押せるものが無いことを画面にも出す。
		notice_label.text = tr("ui_research_empty")
		return
	notice_label.text = ""

	# ⚠ 描くのは「今のボード」だけ。次のボードは、今のボードを全部解放すると出る。
	var board: int = GameManager.get_current_research_board()
	var shown: String = ""
	for node_id: String in _sorted_node_ids(tree, board):
		var category: String = _category_of(node_id)
		if category != shown:
			shown = category
			var heading: Label = Label.new()
			node_list.add_child(heading)
			heading.text = tr(CATEGORY_KEY_PREFIX + category)
		_add_node_row(node_id, tree[node_id])


func _add_node_row(node_id: String, node: Dictionary) -> void:
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)

	var unlocked: bool = bool(node.get(GameStateKeys.NODE_UNLOCKED, false))
	var prerequisites_met: bool = GameManager.can_unlock_research_node(node_id)

	var cost: Dictionary = GameManager.get_research_unlock_cost(node_id)
	var material_id: String = str(cost.get(GameManager.RESEARCH_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.RESEARCH_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	var enough: bool = owned >= amount

	var info: Label = Label.new()
	node_list.add_child(info)

	var lines: Array[String] = [
		"%s%s　%s" % [
			_milestone_mark(definition),
			tr(str(definition.get(NODE_NAME_KEY, ""))),
			_effect_text(node),
		]
	]
	if unlocked:
		lines.append(tr("ui_research_unlocked"))
	else:
		lines.append("%s  %s x%d　（%s %d）" % [
			tr("ui_research_cost"),
			tr("ui_res_" + material_id),
			amount,
			tr("ui_research_owned"),
			owned,
		])
		if not prerequisites_met:
			lines.append(tr("ui_research_locked") % _prerequisite_names(node))
	info.text = "\n".join(lines)

	var button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
	node_list.add_child(button)
	# label_key は使わず text を直接入れる（解放済みで文言が変わるため）。
	button.text = tr("ui_research_unlocked") if unlocked else tr("ui_research_unlock")
	# 押せてから失敗するより、押せないほうが分かりやすい（育成画面と同じ方針）。
	button.disabled = unlocked or not prerequisites_met or not enough
	button.pressed.connect(_on_unlock_pressed.bind(node_id))

	node_list.add_child(HSeparator.new())


# --- 操作 ---

func _on_unlock_pressed(node_id: String) -> void:
	# 戻り値は見ない。成功なら research_node_unlocked 経由で描画し直される。
	# 失敗（前提未達・素材不足）はボタンが押せない状態で防いでいる。
	GameManager.unlock_research_node(node_id)


func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)


# --- シグナル ---

func _on_research_node_unlocked(_node_id: String) -> void:
	# 上限表示と後続ノードの状態が同時に変わるため、種類を問わず引き直す。
	_refresh()


func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	_refresh()


# --- 内部ヘルパー ---

# そのボードのノードだけを、カテゴリ → sort_order の順に並べる。
# sort_order を持たないノードは末尾に回る。⚠ ノードIDを決め打ちしないこと。
func _sorted_node_ids(tree: Dictionary, board: int) -> Array[String]:
	var ids: Array[String] = []
	for node_id: String in tree:
		if GameManager.get_research_board_of(node_id) != board:
			continue
		ids.append(node_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var category_a: String = _category_of(a)
		var category_b: String = _category_of(b)
		if category_a != category_b:
			return category_a < category_b
		return _sort_order_of(a) < _sort_order_of(b)
	)
	return ids


func _category_of(node_id: String) -> String:
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	return str(definition.get(GameManager.RESEARCH_NODE_CATEGORY, ""))


# 中間・最後の区切り（GAME_DESIGN 9-1「区切りとして大きめのバフ」）。印が無ければ空文字。
func _milestone_mark(definition: Dictionary) -> String:
	match str(definition.get(GameManager.RESEARCH_NODE_MILESTONE, "")):
		GameManager.RESEARCH_MILESTONE_MID:
			return tr("ui_research_milestone_mid") + " "
		GameManager.RESEARCH_MILESTONE_FINAL:
			return tr("ui_research_milestone_final") + " "
	return ""


# そのボードのノードが要求する素材ID（重複を除き、出てきた順）。
func _board_material_ids(board: int) -> Array[String]:
	var ids: Array[String] = []
	for node_id: String in _sorted_node_ids(GameManager.get_research_tree(), board):
		var material_id: String = str(GameManager.get_research_unlock_cost(node_id).get(
			GameManager.RESEARCH_COST_MATERIAL_ID, ""))
		if material_id != "" and not (material_id in ids):
			ids.append(material_id)
	return ids


func _sort_order_of(node_id: String) -> int:
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	# JSON の数値は float で来る。int() で包まないと比較がずれる。
	return int(definition.get(NODE_SORT_ORDER, 9999))


func _effect_text(node: Dictionary) -> String:
	var effect_type: String = str(node.get(GameStateKeys.NODE_EFFECT_TYPE, ""))
	var value: int = int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	match effect_type:
		GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			return tr("ui_research_effect_cap") % value
		GameStateKeys.EFFECT_STAT_BOOST_ALL:
			# ⚠ target_stat が "all" でなければ軸1本だけの加算（段階10）。
			#   ⚠ 軸名は育成画面と同じ ui_training_stat_<軸> を使い回す（新しいキーを作らない）。
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, GameManager.STAT_BOOST_ALL_KEY))
			if stat != GameManager.STAT_BOOST_ALL_KEY:
				return tr("ui_research_effect_stat_axis") % [tr("ui_training_stat_" + stat), value]
			return tr("ui_research_effect_stat") % value
		GameStateKeys.EFFECT_CHEST_DRAW_BONUS:
			return tr("ui_research_effect_chest_draw") % value
		# ⚠ 作業場の枝（段階11）。⚠ 見出し（「作業場」）は ja.csv の1行だけで出る。
		#   ⚠ 効果の文言だけは画面が組み立てているので、ここに2枝が要る。
		GameStateKeys.EFFECT_CRAFT_SPEED_BONUS:
			return tr("ui_research_effect_craft_speed") % value
		GameStateKeys.EFFECT_CRAFT_SLOT_BONUS:
			return tr("ui_research_effect_craft_slot") % value
	return ""


# 前提ノードの表示名を「、」で連結する。
func _prerequisite_names(node: Dictionary) -> String:
	var names: Array[String] = []
	var prerequisites: Variant = node.get(GameStateKeys.NODE_PREREQUISITES, [])
	if prerequisites is Array:
		for prerequisite_id: Variant in (prerequisites as Array):
			var definition: Dictionary = MasterDataLoader.get_research_node(str(prerequisite_id))
			names.append(tr(str(definition.get(NODE_NAME_KEY, ""))))
	return "、".join(names)
