# res://scenes/guild/stat_node_screen.gd
# ステータスノード画面（レベルの役割転換・第1弾）。
#
# 育成画面の詳細パネルには置かない。3枝×20段のツリーが収まらないため、
# equipment_screen と同じく独立画面にし、TransferKeys.CHARACTER_ID で対象を受け取る。
#
# ⚠⚠ 2026-09-11（人間の指示「⚠ ステータスノードもモックのように」）：
#   ⚠ **記号（● ○ ✕）をやめ、⚠ 枝を面（カード）に、⚠ 段を行にした**。
#   ⚠ 前は `● +5 (1)` のように印・値・コストを1つのボタンの文字列に詰めていた。
#   ⚠ いまは **解放ずみ＝値が緑 ／ 解放できる＝琥珀の枠 ／ 前提が未解放＝沈める**。
#   ⚠ ギルド・育成・スキルと同じ語彙（⚠ 画面ごとに記号を作り直さない）。
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

# --- ノード参照 ---
@onready var points_label: Label = $Margin/Layout/PointsBar/PointsRow/PointsLabel
@onready var notice_label: Label = $Margin/Layout/PointsBar/PointsRow/NoticeLabel
@onready var reset_button: UiButton = $Margin/Layout/PointsBar/PointsRow/ResetButton
@onready var branches: HBoxContainer = $Margin/Layout/Scroll/Branches
# ⚠ 題と戻るは `ScreenHeader` が持つ。⚠ ボタンを直接掴まない。
@onready var header: ScreenHeader = $Margin/Layout/Header

var _character_id: String = ""


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	reset_button.pressed.connect(_on_reset_pressed)
	header.back_pressed.connect(_on_back_pressed)

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
		points_label.text = ""
		reset_button.disabled = true
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	# ⚠ 戻る先はこのキャラの詳細。⚠ 文言もキャラの名前にする（⚠ 他の画面と揃える）。
	header.set_back_text(tr(str(char_data.get("name_key", ""))))

	var total: int = GameManager.get_stat_node_total_points(_character_id)
	var remaining: int = GameManager.get_stat_node_remaining_points(_character_id)
	points_label.text = tr("ui_stat_node_points") % [remaining, total]
	# ⚠ 余っているときだけ琥珀（⚠ 「次にやることを1つに絞る」）。
	points_label.theme_type_variation = &"AccentLabel" if remaining > 0 else &"CaptionLabel"
	notice_label.text = tr("ui_stat_node_hint") if remaining > 0 else ""

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


# 1本の枝（1つの軸）。⚠ 面（カード）にして、⚠ 中に段の行を積む。
func _build_branch(stat_key: String, all_nodes: Dictionary, remaining: int) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Branch_" + stat_key
	card.theme_type_variation = &"CompactCardPanel"
	# 3列を等幅にする。これを付けないと各列が中身の最小幅のまま並び、
	# 軸名の長さ（"HP" と "物理防御"）と ％の有無で列の幅が変わる。
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	branches.add_child(card)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = &"TightList"
	card.add_child(column)

	# 見出し（絵＋軸名）。⚠ 絵は育成の詳細の10軸と同じもの。
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	column.add_child(head)
	var texture: Texture2D = IconTextures.for_stat(stat_key)
	if texture != null:
		head.add_child(_create_icon(texture))
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = tr("ui_training_stat_" + stat_key)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var unlocked: Array = GameManager.get_stat_nodes(_character_id)
	for entry: Dictionary in _branch_nodes(stat_key, all_nodes):
		column.add_child(_create_node_row(stat_key, entry, unlocked, remaining))


# 段1つぶんの行。⚠ 記号を使わない。⚠ 3つの状態を面と色で示す。
#
# ⚠ 解放ずみ … 値が緑（`GainLabel`）
# ⚠ 解放できる … 琥珀の枠（`ActiveRowPanel`）＋押せる
# ⚠ 前提が未解放／ポイント不足 … 沈める（⚠ 押せない）
func _create_node_row(
	stat_key: String, entry: Dictionary, unlocked: Array, remaining: int
) -> PanelContainer:
	var node_id: String = str(entry.get("id", ""))
	var definition: Dictionary = entry.get("definition", {})
	var cost: int = int(definition.get(GameManager.STAT_NODE_COST, 0))
	var value: int = int(definition.get(GameManager.STAT_NODE_VALUE, 0))

	var is_unlocked: bool = node_id in unlocked
	var can_unlock: bool = GameManager.can_unlock_stat_node(_character_id, node_id)
	var affordable: bool = can_unlock and remaining >= cost

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Node_" + node_id
	panel.theme_type_variation = &"ActiveRowPanel" if affordable else &"CompactRowPanel"
	# ⚠ 届かない段は沈める（⚠ `✕` の代わり）。⚠ 消さない＝先に何が在るかは見せる。
	panel.modulate.a = 1.0 if (is_unlocked or affordable) else 0.4

	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	var value_label: Label = Label.new()
	value_label.name = "ValueLabel"
	value_label.theme_type_variation = &"GainLabel" if is_unlocked else &"SmallLabel"
	value_label.text = _value_text(stat_key, value)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)

	var cost_label: Label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.theme_type_variation = &"CaptionLabel"
	# ⚠ 解放ずみはコストではなく「入っている」ことを出す（⚠ もう払う数字ではない）。
	cost_label.text = tr("ui_stat_node_taken") if is_unlocked else tr("ui_stat_node_cost") % cost
	row.add_child(cost_label)

	# 押せてから失敗するより、押せないほうが分かりやすい
	# （training_screen.gd の level_up_button と同じ判断）。
	if affordable and not is_unlocked:
		UiButton.attach_hit(panel, _on_node_pressed.bind(node_id))
	return panel


# ⚠ 線画は 48px で読み込まれる。⚠ 器は必ず `EXPAND_IGNORE_SIZE`（§0-UI-B-1）。
func _create_icon(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var size_px: int = get_theme_font_size(&"font_size", &"Label")
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


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


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
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


# ⚠ 誰の割り振りを見ていたかを渡して戻る。⚠ 渡さないと一覧に落ちる。
func _on_back_pressed() -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: _character_id})


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
