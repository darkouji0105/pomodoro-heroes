# res://scenes/guild/stat_node_screen.gd
# ステータスノード画面（レベルの役割転換・第1弾）。
#
# 育成画面の詳細パネルには置かない。軸ごとの行と右の一覧が収まらないため、
# equipment_screen と同じく独立画面にし、TransferKeys.CHARACTER_ID で対象を受け取る。
#
# ⚠⚠ 2026-09-12（人間のモック「Stat node mock」）：⚠ **1軸を1行にした**。
#   ⚠ 前は **1軸が20行**（⚠ 3枝 × 20段 = 60行）で、⚠ ScrollContainer に頼っていた。
#   ⚠ いまは **軸ごとに1行**：⚠ 「絵・軸名・段数 ／ 点の列 ／ 合計 ／ 次の1段 ／ ＋」。
#   ⚠ 行は2列に流す（⚠ モックは12種を2列 × 6行に並べていた）。
#   ⚠ 右に「振ったあとのステータス」（⚠ 10軸の最終値と、⚠ 割り振りで増えた分）。
#
# ⚠⚠ **＋は1回に1段**（人間の決定・2026-09-12）。⚠ モックの帯には
#   ⚠ 「押した段まで一度に振れます」と書いてあったが、⚠ 説明文の
#   ⚠ 「押せるのは各段の先頭1個」のほうを採った（⚠ 人間に確認済み）。
#   ⚠ ＝ `unlock_stat_node()` を1回呼ぶだけ。⚠ GameManager に口を足していない。
#
# ⚠⚠ **行は allocatable_stats に従う**（⚠ いまは1キャラ3軸）。⚠ モックは12種だが、
#   ⚠ `nodes.json` に段が在るのは3軸ぶんだけ（人間の決定「⚠ 先に画面だけ作る」）。
#   ⚠ データを増やせば行はそのぶん増える。⚠ ここで軸を決め打ちしないこと。
# ⚠ モックの「シールド」「SP」は**この2軸が存在しない**（`GameManager._stat_keys()` は10軸）。
#   ⚠ 追加は戦闘まで波及するので別の回（人間の決定「⚠ 10軸で作る」）。
#
# 購読するシグナルは character_growth_changed の1本だけ。
# ノードの解放も振り直しも素材を触らないため、material_changed は飛ばない。

class_name StatNodeScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
# ⚠ パッシブの効果文の翻訳キーの接頭辞（⚠ スキル・アイテム・レリックと同じ `ui_desc_<id>`）。
const DESCRIPTION_PREFIX: String = "ui_desc_"

# --- ノード参照 ---
@onready var points_label: Label = $Margin/Layout/PointsBar/PointsRow/PointsLabel
@onready var points_caption: Label = $Margin/Layout/PointsBar/PointsRow/PointsCaption
@onready var notice_label: Label = $Margin/Layout/PointsBar/PointsRow/NoticeLabel
@onready var reset_button: UiButton = $Margin/Layout/PointsBar/PointsRow/ResetButton
@onready var branches: GridContainer = $Margin/Layout/Body/LeftColumn/Branches
@onready var passive_panel: PanelContainer = $Margin/Layout/Body/LeftColumn/PassivePanel
@onready var passive_title: Label = $Margin/Layout/Body/LeftColumn/PassivePanel/PassiveColumn/PassiveTitle
@onready var passive_note: Label = $Margin/Layout/Body/LeftColumn/PassivePanel/PassiveColumn/PassiveNote
@onready var passive_list: VBoxContainer = $Margin/Layout/Body/LeftColumn/PassivePanel/PassiveColumn/Passives
@onready var side_title: Label = $Margin/Layout/Body/SidePanel/SideColumn/SideTitle
@onready var stat_list: VBoxContainer = $Margin/Layout/Body/SidePanel/SideColumn/StatList
@onready var spent_caption: Label = (
	$Margin/Layout/Body/SidePanel/SideColumn/SpentRow/SpentCaption
)
@onready var spent_label: Label = $Margin/Layout/Body/SidePanel/SideColumn/SpentRow/SpentLabel
# ⚠ 題と戻るは `ScreenHeader` が持つ。⚠ ボタンを直接掴まない。
@onready var header: ScreenHeader = $Margin/Layout/Header

var _character_id: String = ""


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	reset_button.pressed.connect(_on_reset_pressed)
	header.back_pressed.connect(_on_back_pressed)

	GameManager.character_growth_changed.connect(_on_character_growth_changed)

	# ⚠ 動かない文言はここで1回だけ入れる（⚠ 再描画のたびに入れ直さない）。
	points_caption.text = tr("ui_stat_node_points")
	side_title.text = tr("ui_stat_node_after")
	spent_caption.text = tr("ui_stat_node_spent")
	passive_title.text = tr("ui_stat_node_passive_header")
	passive_note.text = tr("ui_stat_node_passive_note")
	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[StatNodeScreen] character_id が渡されていない")
	_rebuild()


# --- 描画 ---

func _rebuild() -> void:
	_clear(branches)
	_clear(stat_list)
	_clear(passive_list)
	if _character_id == "":
		points_label.text = ""
		spent_label.text = ""
		reset_button.disabled = true
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	# ⚠ 戻る先はこのキャラの詳細。⚠⚠ 文言は「戻る」（2026-09-14・人間の指示
	#   「⚠ 戻るという文字にしてほしい、⚠ キャラの名前ではなく」）。⚠ ヘッダーの既定のまま。
	# ⚠ モックはヘッダーにレベルを出していた。⚠ 副題の枠が既に在るのでそこへ入れる
	#   （⚠ `ScreenHeader` を作り替えない）。
	var growth: Dictionary = GameManager.get_character_growth(_character_id)
	header.set_subtitle_text(
		tr("ui_training_level") % int(growth.get(GameStateKeys.GROWTH_LEVEL, 1))
	)

	var remaining: int = GameManager.get_stat_node_remaining_points(_character_id)
	points_label.text = str(remaining)
	# ⚠ 余っていない間は数字を沈める（⚠ 「次にやることを1つに絞る」）。
	#   ⚠ 琥珀のままだと、⚠ 0 でも「まだ振れる」に見える。
	points_label.theme_type_variation = &"PointsLabel" if remaining > 0 else &"MutedLabel"
	notice_label.text = tr("ui_stat_node_hint") if remaining > 0 else ""
	spent_label.text = tr("ui_stat_node_cost") % GameManager.get_stat_node_spent_points(
		_character_id
	)

	# 解放が0件のときに押しても何も起きないので、押せなくしておく。
	reset_button.disabled = GameManager.get_stat_nodes(_character_id).is_empty()

	# 行の本数と並び順は allocatable_stats が決める。軸を決め打ちしない。
	var allocatable: Variant = char_data.get("allocatable_stats", [])
	if not (allocatable is Array):
		push_warning("[StatNodeScreen] allocatable_stats が配列ではない: " + _character_id)
		return

	var all_nodes: Dictionary = MasterDataLoader.get_all_character_nodes()
	var unlocked: Array = GameManager.get_stat_nodes(_character_id)
	# ⚠⚠ 段が1つも無いキャラ（⚠ `nodes.json` を持たない検証用キャラ・宿題80）は、
	#   ⚠ 軸の数だけ**中身の無いカード**が並んでいた。⚠ 「壊れて空」なのか「もともと無い」のか読めない。
	#   ⚠ 1軸でも段があれば今までどおり（⚠ 空の軸はカードだけ出す＝`_create_branch_row()` の注）。
	var total_entries: int = 0
	for stat_key: Variant in (allocatable as Array):
		total_entries += _branch_nodes(str(stat_key), all_nodes).size()
	if total_entries == 0:
		branches.add_child(EmptyState.create("ui_stat_node_empty"))
		_build_side_panel()
		_build_passives()
		return

	for stat_key: Variant in (allocatable as Array):
		branches.add_child(_create_branch_row(str(stat_key), all_nodes, unlocked, remaining))

	_build_side_panel()
	_build_passives()


# 1つの軸ぶんの行。⚠ モックの1枚のカード。
#
# ⚠ 上：絵・軸名・いま何段目 ／ 右に「合計」「次の1段とその値段」「＋」
# ⚠ 下：段の進みの点（`TierDots`）
# ⚠ 面ぜんぶは押せるようにしない（⚠ 中に本物の＋が居るので、
#   ⚠ どこを押しても振れると取り違える）。⚠ 押す場所は＋の1つだけ。
func _create_branch_row(
	stat_key: String, all_nodes: Dictionary, unlocked: Array, remaining: int
) -> PanelContainer:
	var entries: Array = _branch_nodes(stat_key, all_nodes)
	var done: int = 0
	var total_value: int = 0
	var next_entry: Dictionary = {}
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) in unlocked:
			done += 1
			total_value += int(entry.get("value", 0))
		elif next_entry.is_empty():
			next_entry = entry

	var card: PanelContainer = PanelContainer.new()
	card.name = "Branch_" + stat_key
	card.theme_type_variation = &"CompactCardPanel"
	# 列を等幅にする。これを付けないと各列が中身の最小幅のまま並び、
	# 軸名の長さ（"HP" と "物理防御"）と ％の有無で列の幅が変わる。
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = &"TightList"
	card.add_child(column)
	column.add_child(_create_head(stat_key, done, total_value, next_entry, remaining))

	# ⚠ 段が1つも無い軸（⚠ `nodes.json` にまだ書いていない軸）は点を出さない。
	#   ⚠ 0個の器を置くと、⚠ 行の高さだけが空く。
	if not entries.is_empty():
		var dots: TierDots = TierDots.new()
		dots.setup(entries.size(), done)
		column.add_child(dots)
	return card


# 行の上半分。⚠ 数字は3つ（⚠ いまの合計 ／ 次の1段 ／ その値段）。
func _create_head(
	stat_key: String, done: int, total_value: int, next_entry: Dictionary, remaining: int
) -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"

	var well: PanelContainer = _create_icon_well(IconTextures.for_stat(stat_key))
	if well != null:
		head.add_child(well)

	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = tr("ui_training_stat_" + stat_key)
	head.add_child(title)

	var tier: Label = Label.new()
	tier.name = "TierLabel"
	tier.theme_type_variation = &"CaptionLabel"
	tier.text = tr("ui_stat_node_tier") % done
	tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tier)

	# いまこの軸に入っている合計。⚠ 0 のときは緑にしない（⚠ 増えていない）。
	var total_label: Label = Label.new()
	total_label.name = "TotalLabel"
	total_label.theme_type_variation = &"GainLabel" if total_value > 0 else &"MutedLabel"
	total_label.text = _value_text(stat_key, total_value)
	total_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(total_label)

	head.add_child(_create_next_block(stat_key, next_entry))
	head.add_child(_create_add_button(next_entry, remaining))
	return head


# 「次の1段」の欄（⚠ 値とその値段を縦に2つ）。
# ⚠ 全段を振り終わった軸は「済」1つにする（⚠ 空欄にすると行が縮んで揃わない）。
func _create_next_block(stat_key: String, next_entry: Dictionary) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.name = "NextBlock"
	block.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var value_label: Label = Label.new()
	value_label.name = "NextLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var cost_label: Label = Label.new()
	cost_label.name = "NextCostLabel"
	cost_label.theme_type_variation = &"CaptionLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if next_entry.is_empty():
		value_label.theme_type_variation = &"MutedLabel"
		value_label.text = tr("ui_stat_node_taken")
		cost_label.text = ""
	else:
		value_label.theme_type_variation = &"AccentLabel"
		value_label.text = _value_text(stat_key, int(next_entry.get("value", 0)))
		cost_label.text = tr("ui_stat_node_cost") % int(next_entry.get("cost", 0))

	block.add_child(value_label)
	block.add_child(cost_label)
	return block


# ＋（1段ぶん振る）。⚠ 押せてから失敗するより、押せないほうが分かりやすい
#   （training_screen.gd の level_up_button と同じ判断）。
#
# ⚠ 真鍮（`PrimaryButton`）にしない。⚠ 「真鍮は1画面に1個まで」の決まりがあり、
#   ⚠ 軸のぶんだけ並ぶこのボタンは該当しない（⚠ モックは琥珀。⚠ 人間に報告する）。
func _create_add_button(next_entry: Dictionary, remaining: int) -> UiButton:
	var button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_stat_node_add")
	button.name = "AddButton"
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if next_entry.is_empty():
		button.disabled = true
		return button

	var node_id: String = str(next_entry.get("id", ""))
	var cost: int = int(next_entry.get("cost", 0))
	var can_unlock: bool = GameManager.can_unlock_stat_node(_character_id, node_id)
	button.disabled = not (can_unlock and remaining >= cost)
	button.pressed.connect(_on_node_pressed.bind(node_id))
	return button


# 右の「振ったあとのステータス」。⚠ 10軸ぜんぶ出す（⚠ 振れない軸も見せる）。
#
# ⚠ 値は `get_effective_stats()`（⚠ 素＋研究＋装備＋割り振り）。
# ⚠ 緑の数字は `get_stat_node_bonus()`＝**この画面で上げた分だけ**
#   （⚠ 装備や研究の分まで緑にすると、⚠ ここで押しても動かない数字が緑になる）。
func _build_side_panel() -> void:
	var effective: Dictionary = GameManager.get_effective_stats(_character_id)
	var bonus: Dictionary = GameManager.get_stat_node_bonus(_character_id)
	for stat_key: String in GameManager.get_stat_keys():
		var gained: int = int(bonus.get(stat_key, 0))
		var row: ValueRow = ValueRow.create(
			tr("ui_training_stat_" + stat_key),
			_plain_text(stat_key, int(effective.get(stat_key, 0))),
			ValueRow.VARIATION_PLAIN,
			IconTextures.for_stat(stat_key)
		)
		# ⚠ 増えていない軸も欄だけ置く（⚠ 置かないと値の右端が行ごとにずれる）。
		row.set_delta(_value_text(stat_key, gained) if gained > 0 else "")
		stat_list.add_child(row)
		row.set_compact()


# 絵の枠（⚠ 軸とパッシブで共用）。⚠ 大きさは Theme が持つ（`IconWell`）。⚠ ここに px を書かない。
# ⚠ 線画は 48px で読み込まれるので、⚠ 器は必ず `EXPAND_IGNORE_SIZE`（§0-UI-B-1）。
# ⚠ 絵が無ければ枠ごと出さない（⚠ 空の四角を並べない。⚠ スキルの枠と同じ落とし方）。
func _create_icon_well(texture: Texture2D) -> PanelContainer:
	if texture == null:
		return null

	var well: PanelContainer = PanelContainer.new()
	well.name = "IconWell"
	well.theme_type_variation = &"IconWell"
	var box: int = well.get_theme_constant(&"size", &"IconWell")
	well.custom_minimum_size = Vector2(box, box)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var inner: int = well.get_theme_constant(&"icon", &"IconWell")
	rect.custom_minimum_size = Vector2(inner, inner)
	well.add_child(rect)
	return well


# 1つの軸に属するノードを段の順に並べて返す。
# 戻り値の要素: {"id": String, "tier": int, "cost": int, "value": int}
#
# tier / cost / value をここで int にしているのは、MasterDataLoader が
# JSON をそのまま返すため（3.0 のような float で来る）。
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
			"tier": int(definition.get(GameManager.STAT_NODE_TIER, 0)),
			"cost": int(definition.get(GameManager.STAT_NODE_COST, 0)),
			"value": int(definition.get(GameManager.STAT_NODE_VALUE, 0)),
		})
	result.sort_custom(_compare_tier)
	return result


# _branch_nodes() の並べ替え用。段の小さい順。
func _compare_tier(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("tier", 0)) < int(b.get("tier", 0))


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
# 振り直しは1操作で全部の行が一斉に変わるため、ここが最も影響が大きい。
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


# 符号を付けない値（⚠ 右の一覧の最終値）。⚠ ％だけ付ける。
func _plain_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)


# ⚠⚠ パッシブ（2026-09-14・人間の指示「⚠ パッシブの表記をステータスノードに移して」）。
#
# ⚠ 前はスキル設定の右の列に居た。⚠ 解放は**総ポイント**なので、⚠ ポイントを出しているこの画面に置く。
# ⚠ 解放済み＝名前が緑 ／ ⚠ 未解放＝沈める＋「N pt 貯まると解放」。⚠ 記号は使わない。
# ⚠ パッシブを持たないキャラ（⚠ 検証用）はカードごと出さない。
func _build_passives() -> void:
	var all_passives: Array = GameManager.get_all_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)
	passive_panel.visible = not all_passives.is_empty()
	if all_passives.is_empty():
		return
	var unlocked: Array = GameManager.get_skill_candidates(
		_character_id, GameManager.SLOT_KIND_PASSIVE
	)
	for entry: Variant in all_passives:
		var passive_id: String = str(entry)
		passive_list.add_child(_create_passive_row(passive_id, passive_id in unlocked))


func _create_passive_row(passive_id: String, is_unlocked: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Passive_" + passive_id
	# ⚠ 未解放は沈める（⚠ 届かない段と同じ落とし方）。⚠ 消さない＝先に何が在るかは見せる。
	row.modulate.a = 1.0 if is_unlocked else 0.45
	var well: PanelContainer = _create_icon_well(IconTextures.for_skill(passive_id))
	if well != null:
		row.add_child(well)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"GainLabel" if is_unlocked else &""
	var skill_data: Dictionary = MasterDataLoader.get_skill(passive_id)
	name_label.text = tr(str(skill_data.get("name_key", passive_id)))
	column.add_child(name_label)

	var parts: Array[String] = []
	# ⚠ 効果文が無ければ出さない（⚠ tr() は表に無いキーをそのまま返す）。
	var key: String = DESCRIPTION_PREFIX + passive_id
	if tr(key) != key:
		parts.append(tr(key))
	if not is_unlocked:
		parts.append(tr("ui_stat_node_passive_locked") % GameManager.get_passive_unlock_points(passive_id))
	if parts.is_empty():
		return row
	var caption: Label = Label.new()
	caption.name = "EffectLabel"
	caption.theme_type_variation = &"CaptionLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = "　".join(parts)
	column.add_child(caption)
	return row


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
