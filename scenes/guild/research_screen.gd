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
	cap_label.text = tr("ui_research_cap") % GameManager.get_effective_level_cap("")

	var material_id: String = _primary_material_id()
	if material_id == "":
		material_label.text = ""
		return
	material_label.text = "%s  %d" % [
		tr("ui_res_" + material_id),
		GameManager.get_material_count(material_id),
	]


func _build_node_list() -> void:
	for child in node_list.get_children():
		child.queue_free()

	var tree: Dictionary = GameManager.get_research_tree()
	if tree.is_empty():
		# research.json が読めていない。押せるものが無いことを画面にも出す。
		notice_label.text = tr("ui_research_empty")
		return
	notice_label.text = ""

	for node_id: String in _sorted_node_ids(tree):
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
		"%s　%s" % [
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

# sort_order の昇順。sort_order を持たないノードは末尾に回る。
func _sorted_node_ids(tree: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for node_id: String in tree:
		ids.append(node_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return _sort_order_of(a) < _sort_order_of(b)
	)
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
			return tr("ui_research_effect_stat") % value
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


# 所持数をヘッダに出す素材。研究で使う素材が1種類である前提で、
# 最初のノードのコストから引く（ノードIDを決め打ちしないため）。
func _primary_material_id() -> String:
	var tree: Dictionary = GameManager.get_research_tree()
	for node_id: String in _sorted_node_ids(tree):
		var cost: Dictionary = GameManager.get_research_unlock_cost(node_id)
		var material_id: String = str(cost.get(GameManager.RESEARCH_COST_MATERIAL_ID, ""))
		if material_id != "":
			return material_id
	return ""
