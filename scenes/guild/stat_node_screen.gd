# res://scenes/guild/stat_node_screen.gd
# ステータスノード画面（レベルの役割転換・第1弾）。
#
# 育成画面の詳細パネルには置かない。3枝×20段のツリーが収まらないため、
# equipment_screen と同じく独立画面にし、TransferKeys.CHARACTER_ID で対象を受け取る。
#
# 枝の本数・並び順は characters.json の allocatable_stats が決める。
# ここで軸を決め打ちしないこと（10軸のとき equipment_screen.gd に2本目の軸配列があり、
# 片方だけ直す事故の元になっていた）。
#
# 購読するシグナルは character_growth_changed の1本だけ。
# ノードの解放も振り直しも素材を触らないため、material_changed は飛ばない。

class_name StatNodeScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# 解放済み / 解放できる / 前提が未解放
const MARK_UNLOCKED: String = "●"
const MARK_AVAILABLE: String = "○"
const MARK_LOCKED: String = "✕"

# --- ノード参照 ---
@onready var name_label: Label = $Margin/Layout/NameLabel
@onready var points_label: Label = $Margin/Layout/PointsLabel
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var reset_button: PrimaryButton = $Margin/Layout/ResetButton
@onready var branches: HBoxContainer = $Margin/Layout/Scroll/Branches
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

var _character_id: String = ""


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

	GameManager.character_growth_changed.connect(_on_character_growth_changed)

	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[StatNodeScreen] character_id が渡されていない")
	_rebuild()


# --- 描画 ---

func _rebuild() -> void:
	_clear(branches)
	if _character_id == "":
		name_label.text = ""
		points_label.text = ""
		reset_button.disabled = true
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	name_label.text = tr(str(char_data.get("name_key", "")))

	var total: int = GameManager.get_stat_node_total_points(_character_id)
	var remaining: int = GameManager.get_stat_node_remaining_points(_character_id)
	points_label.text = tr("ui_stat_node_points") % [remaining, total]

	# 解放が0件のときに押しても何も起きないので、押せなくしておく。
	reset_button.disabled = GameManager.get_stat_nodes(_character_id).is_empty()

	# 枝の本数と並び順は allocatable_stats が決める。列数を決め打ちしない。
	var allocatable: Variant = char_data.get("allocatable_stats", [])
	if not (allocatable is Array):
		push_warning("[StatNodeScreen] allocatable_stats が配列ではない: " + _character_id)
		return

	var all_nodes: Dictionary = MasterDataLoader.get_all_character_nodes()
	for stat_key: Variant in (allocatable as Array):
		_build_branch(str(stat_key), all_nodes, remaining)


# 1本の枝（1つの軸）を縦に組み立てる。
func _build_branch(stat_key: String, all_nodes: Dictionary, remaining: int) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	# 3列を等幅にする。
	# これを付けないと各列が中身の最小幅のまま並び、軸名の長さ（"HP" と "物理防御"）と
	# ％の有無（"+1" と "+1%"）で列の幅が変わる。stretch_ratio は既定の 1 のままでよい。
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branches.add_child(column)

	var header: Label = Label.new()
	header.text = tr("ui_training_stat_" + stat_key)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(header)

	var unlocked: Array = GameManager.get_stat_nodes(_character_id)

	for entry: Dictionary in _branch_nodes(stat_key, all_nodes):
		var node_id: String = str(entry.get("id", ""))
		var definition: Dictionary = entry.get("definition", {})
		var cost: int = int(definition.get(GameManager.STAT_NODE_COST, 0))
		var value: int = int(definition.get(GameManager.STAT_NODE_VALUE, 0))

		var is_unlocked: bool = node_id in unlocked
		var can_unlock: bool = GameManager.can_unlock_stat_node(_character_id, node_id)

		var mark: String = MARK_LOCKED
		if is_unlocked:
			mark = MARK_UNLOCKED
		elif can_unlock:
			mark = MARK_AVAILABLE

		var button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		column.add_child(button)
		# 列いっぱいに広げる。文字数でボタン幅が変わると段ごとに右端が揃わない。
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# label_key ではなく text を直接入れる（記号・数値・コストを1行にまとめるため）。
		button.text = "%s %s (%d)" % [mark, _value_text(stat_key, value), cost]
		# 押せてから失敗するより、押せないほうが分かりやすい
		# （training_screen.gd の level_up_button と同じ判断）。
		button.disabled = is_unlocked or not can_unlock or remaining < cost
		button.pressed.connect(_on_node_pressed.bind(node_id))


# 1つの軸に属するノードを段の順に並べて返す。
# 戻り値の要素: {"id": String, "definition": Dictionary, "tier": int}
#
# tier をここで int にして要素に持たせているのは、並べ替えの比較を1行に収めるため。
# MasterDataLoader は JSON をそのまま返すため tier は float で来る。
func _branch_nodes(stat_key: String, all_nodes: Dictionary) -> Array:
	var result: Array = []
	for node_id: Variant in all_nodes:
		var definition: Dictionary = all_nodes[node_id]
		if str(definition.get(GameManager.STAT_NODE_CHARACTER_ID, "")) != _character_id:
			continue
		if str(definition.get(GameManager.STAT_NODE_STAT, "")) != stat_key:
			continue
		result.append({
			"id": str(node_id),
			"definition": definition,
			"tier": int(definition.get(GameManager.STAT_NODE_TIER, 0)),
		})
	result.sort_custom(_compare_tier)
	return result


# _branch_nodes() の並べ替え用。段の小さい順。
func _compare_tier(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("tier", 0)) < int(b.get("tier", 0))


# remove_child してから queue_free する。await を挟むと再描画が並走し、行が二重に並ぶ
# （AGENTS.md「再描画は await を持たせない」）。
# 振り直しは1操作で60ノードが一斉に変わるため、ここが最も影響が大きい。
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ％系は "+5%" と出す。実数はそのまま "+5"。
# training_screen.gd の _stat_value_text() と同じ判定（GameManager.is_percent_stat）を使う。
func _value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "+%d%%" % value
	return "+%d" % value


# --- 操作 ---

func _on_node_pressed(node_id: String) -> void:
	if _character_id == "":
		return
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	GameManager.unlock_stat_node(_character_id, node_id)


func _on_reset_pressed() -> void:
	if _character_id == "":
		return
	GameManager.reset_stat_nodes(_character_id)


func _on_back_pressed() -> void:
	SceneManager.change_scene(TRAINING_PATH)


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
