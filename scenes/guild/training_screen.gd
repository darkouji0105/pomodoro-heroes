# res://scenes/guild/training_screen.gd
# ギルド：育成画面。一覧と詳細を同一シーン内で切り替える。シーンは分けない。
#
# ⚠⚠ 2026-09-11（人間のモック「ギルド／育成」B・C）：⚠ **一覧も詳細も作り替えた**。
#   ⚠ 一覧 … ボタンが縦に並ぶだけだったものを、⚠ **行**にした（⚠ 顔／名前と役割／
#           レベルの進み／⚠ **次に何が要るか**）。⚠ 「押してみないと分からない」を外に出す。
#   ⚠ 詳細 … 左に情報・右に操作の**2カラム**。⚠ 10軸は装備画面と同じ `ValueRow`
#           （⚠ 前はここだけ `\n` で1つの Label に詰めていた＝⚠ 値が右に揃わなかった）。
#
# ⚠ 一覧は `MasterDataLoader.get_all_characters()` から引く（⚠ 2026-09-11）。
#   ⚠ 前はここに6件を列挙し、⚠ 「⚠ MasterDataLoader にキー一覧を返す関数が無いため」と
#   ⚠ 書いてあったが、⚠ **`get_all_characters()` は在った**（⚠ コメントが間違っていた）。
# ⚠ 検証用（`char_debug_*`）は仕切りの下に分ける。⚠ 判定は `GameManager.is_debug_character()`。

class_name TrainingScreen
extends Control

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"
const UI_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/ui_button.tscn")

const EQUIPMENT_PATH: String = "res://scenes/guild/equipment_screen.tscn"
const STAT_NODE_PATH: String = "res://scenes/guild/stat_node_screen.tscn"
const SKILL_SELECT_PATH: String = "res://scenes/guild/skill_select_screen.tscn"

# ⚠ 顔の大きさ。⚠ 一覧と詳細で変える（⚠ モックの 42 / 52）。
const AVATAR_LIST: int = 42
const AVATAR_DETAIL: int = 52
# ⚠ 一覧の行で「名前と役割」に使う幅。⚠ 名前の長さで進みの帯の左端がずれないようにする。
const NAME_COLUMN_WIDTH: int = 130
# ⚠ 右カラムの幅（⚠ モックの 296）。
const SIDE_COLUMN_WIDTH: int = 296

# 詳細を表示中のキャラクターID。一覧表示中は空文字。
var _selected_id: String = ""

# ビルド（キャラプリセット）の行（EXEC_PARTY_PRESETS.md）。
#
# ⚠ 装備画面にも同じ行がある。⚠ 判定も文面も GameManager 側の1本を通るので、
#   ここに書いてあるのは器の組み立てだけ。⚠ 判定を書き足さないこと。
# ⚠ 「焼く」と「適用」は向きが逆（焼く＝現在→ビルド／適用＝ビルド→現在）。
#   ⚠ 1つのボタンにまとめないこと。
var _build_picker: OptionButton = null
var _selected_build: int = 0
# ⚠ 結果の1行。⚠ 詳細を組み直すたびに作り直すので、⚠ 文言は変数で持ち越す。
var _notice_text: String = ""

@onready var list_panel: VBoxContainer = $Margin/Layout/ListPanel
@onready var detail_panel: HBoxContainer = $Margin/Layout/DetailPanel
@onready var info_column: VBoxContainer = $Margin/Layout/DetailPanel/InfoColumn
@onready var side_column: PanelContainer = $Margin/Layout/DetailPanel/SideColumn
@onready var action_column: VBoxContainer = $Margin/Layout/DetailPanel/SideColumn/SideMargin/ActionColumn
@onready var level_up_button: UiButton = $Margin/Layout/DetailPanel/SideColumn/SideMargin/ActionColumn/LevelUpButton
# ⚠ 題と戻るは `ScreenHeader` が持つ。⚠ ボタンを直接掴まない。
@onready var header: ScreenHeader = $Margin/Layout/Header


func _ready() -> void:
	side_column.custom_minimum_size = Vector2(SIDE_COLUMN_WIDTH, 0.0)
	level_up_button.pressed.connect(_on_level_up_pressed)
	header.back_pressed.connect(_on_back_pressed)

	# レベルアップの結果は戻り値ではなくシグナルで受けて描画し直す。
	# 表示更新の経路を1本にしておくと、他画面から育成データが変わっても追従する。
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.material_changed.connect(_on_material_changed)

	# ⚠ キャラを渡されて開いたときは詳細から始める（2026-09-11）。
	#   ⚠ 下の画面（割り振り・スキル・装備）から戻ってきたときに一覧へ落とさないため。
	#   ⚠ `scenario=layout` が詳細の縦を測れるのもこの経路（⚠ 前は `.tscn` に
	#   ⚠ 中身が在ったので測れていたが、⚠ いまは中身をコードで作る）。
	# ⚠ 一覧は必ず1回組む（⚠ 詳細から始めるときも）。⚠ 隠れているだけの器にしておく。
	#   ⚠ 組まないと、⚠ 詳細から一覧へ戻るまで行が1つも無い状態になり、
	#   ⚠ `scenario=layout` からも行数を数えられない。
	_rebuild_list()
	var data: Dictionary = SceneManager.consume_transfer_data()
	var passed_id: String = str(data.get(TransferKeys.CHARACTER_ID, ""))
	if passed_id != "" and not MasterDataLoader.get_character(passed_id).is_empty():
		_show_detail(passed_id)
	else:
		_show_list()


# --- 一覧（モック B）---

func _show_list() -> void:
	_selected_id = ""
	_notice_text = ""
	detail_panel.visible = false
	list_panel.visible = true
	header.back_label_key = "ui_nav_guild"
	header.set_subtitle_text("")
	_rebuild_list()


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _rebuild_list() -> void:
	_clear(list_panel)
	list_panel.add_child(_create_material_bar())

	var roster: VBoxContainer = VBoxContainer.new()
	roster.name = "Roster"
	list_panel.add_child(roster)

	var debug_ids: Array[String] = []
	for character_id: Variant in MasterDataLoader.get_all_characters():
		var id: String = str(character_id)
		if GameManager.is_debug_character(id):
			debug_ids.append(id)
			continue
		roster.add_child(_create_roster_row(id, false))

	# ⚠ 検証用は仕切りの下。⚠ リリースビルドでは丸ごと出さない（⚠ 編成の候補と同じ扱い）。
	if debug_ids.is_empty() or not OS.is_debug_build():
		return
	roster.add_child(_create_section_label("ui_training_debug_section"))
	for id: String in debug_ids:
		roster.add_child(_create_roster_row(id, true))


# 一番上の「いま何を何個持っているか」。⚠ レベルアップに使う素材の1件だけ。
func _create_material_bar() -> PanelContainer:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "MaterialBar"
	bar.theme_type_variation = &"InsetPanel"

	var row: HBoxContainer = HBoxContainer.new()
	bar.add_child(row)

	var material_id: String = _level_up_material_id()
	if material_id == "":
		return bar

	var icon: TextureRect = _create_icon(IconTextures.for_item(material_id), AVATAR_LIST / 2)
	if icon != null:
		row.add_child(icon)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr("ui_res_" + material_id)
	row.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = str(GameManager.get_material_count(material_id))
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)

	var hint: Label = Label.new()
	hint.name = "HintLabel"
	hint.theme_type_variation = &"SectionLabel"
	hint.text = tr("ui_training_material_hint")
	row.add_child(hint)
	return bar


# 1人ぶんの行。⚠ 押すと詳細へ。⚠ 押せる範囲は行ぜんぶ（`HitButton` を重ねる）。
func _create_roster_row(character_id: String, is_debug: bool) -> PanelContainer:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	var level: int = _level_of(character_id)
	var cap: int = GameManager.get_effective_level_cap(character_id)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Row_" + character_id
	panel.theme_type_variation = &"ListRowPanel"
	# ⚠ 検証用は沈める（⚠ 本番のキャラと同じ濃さで並べない）。
	panel.modulate.a = 0.5 if is_debug else 1.0

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	panel.add_child(row)

	row.add_child(CharacterAvatar.create(character_id, AVATAR_LIST))

	# 名前と役割。⚠ 幅を固定して、⚠ 名前の長さで右の帯がずれないようにする。
	var name_column: VBoxContainer = VBoxContainer.new()
	name_column.name = "NameColumn"
	name_column.custom_minimum_size = Vector2(NAME_COLUMN_WIDTH, 0.0)
	name_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_column)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr(str(char_data.get("name_key", "")))
	name_column.add_child(name_label)

	var role_label: Label = Label.new()
	role_label.name = "RoleLabel"
	role_label.theme_type_variation = &"CaptionLabel"
	# ⚠ 役割は `characters.json` に欄が無い（⚠ 2026-09-11 に確認）。⚠ 文言だけ持つ。
	#   ⚠ 検証用はIDをそのまま出す（⚠ どのキャラか分かればよい）。
	role_label.text = character_id if is_debug else tr("ui_role_" + character_id)
	name_column.add_child(role_label)

	# レベルの進み。
	var progress: VBoxContainer = VBoxContainer.new()
	progress.name = "Progress"
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(progress)
	progress.add_child(_create_level_bar(level, cap))

	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	level_label.theme_type_variation = &"CaptionLabel"
	level_label.text = _level_text(character_id, level, cap)
	progress.add_child(level_label)

	# 次に何が要るか。⚠ この行がこの画面の主役。
	row.add_child(_create_need_label(character_id, level, cap))

	var chevron: Label = Label.new()
	chevron.name = "Chevron"
	chevron.theme_type_variation = &"CaptionLabel"
	chevron.text = tr("ui_common_chevron")
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)

	UiButton.attach_hit(panel, _show_detail.bind(character_id))
	return panel


func _create_level_bar(level: int, cap: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "LevelBar"
	bar.theme_type_variation = &"LevelBar"
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(cap))
	bar.value = float(level)
	bar.custom_minimum_size = Vector2(0.0, float(bar.get_theme_constant(&"height", &"LevelBar")))
	return bar


# 「修練の証 3 で Lv13」／「修練の証 60 が足りません」／上限なら「上限に達しています」。
#
# ⚠ 判定は育成の詳細・ギルドのカードと同じ2つ（⚠ 上限 ／ 素材）。
#   ⚠ 3箇所で別々に書かないこと。⚠ ここが表示の1本。
func _create_need_label(character_id: String, level: int, cap: int) -> Label:
	var label: Label = Label.new()
	label.name = "NeedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if GameManager.is_debug_character(character_id):
		label.theme_type_variation = &"SectionLabel"
		label.text = tr("ui_training_need_none")
		return label
	if level >= cap:
		label.theme_type_variation = &"SectionLabel"
		label.text = tr("ui_training_max_level")
		return label

	var cost: Dictionary = GameManager.get_level_up_cost(character_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	var material_name: String = tr("ui_res_" + material_id)
	if owned >= amount:
		label.theme_type_variation = &"CaptionLabel"
		label.text = tr("ui_training_need_ok") % [material_name, amount, level + 1]
	else:
		label.theme_type_variation = &"SmallErrorLabel"
		label.text = tr("ui_training_need_short") % [material_name, amount - owned]
	return label


func _create_section_label(key: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Section"
	var label: Label = Label.new()
	label.theme_type_variation = &"SectionLabel"
	label.text = tr(key)
	row.add_child(label)
	var rule: HSeparator = HSeparator.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rule)
	return row


# --- 詳細（モック C）---

func _show_detail(character_id: String) -> void:
	_selected_id = character_id
	_notice_text = ""
	list_panel.visible = false
	detail_panel.visible = true
	header.back_label_key = "ui_training_to_list"
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id == "":
		return
	var char_data: Dictionary = MasterDataLoader.get_character(_selected_id)
	header.set_subtitle_text(tr(str(char_data.get("name_key", ""))))
	_rebuild_info()
	_rebuild_actions()


func _rebuild_info() -> void:
	_clear(info_column)
	var char_data: Dictionary = MasterDataLoader.get_character(_selected_id)
	var level: int = _level_of(_selected_id)
	var cap: int = GameManager.get_effective_level_cap(_selected_id)

	# 見出し（顔・名前・レベル）。
	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	info_column.add_child(hero)
	hero.add_child(CharacterAvatar.create(_selected_id, AVATAR_DETAIL))

	var hero_text: VBoxContainer = VBoxContainer.new()
	hero_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(hero_text)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr(str(char_data.get("name_key", "")))
	hero_text.add_child(name_label)
	var level_label: Label = Label.new()
	name_label.name = "LevelLabel"
	level_label.theme_type_variation = &"CaptionLabel"
	level_label.text = _level_text(_selected_id, level, cap)
	hero_text.add_child(level_label)

	# 10軸。⚠ 装備画面と同じ `ValueRow`（⚠ 絵・左に名前・右に値・増えたぶんは緑）。
	# ⚠ 10軸は詰めた形（2026-09-11・人間の指示「半分ぐらいの大きさに」）。
	#   ⚠ 面の縦の余白も、⚠ 行どうしの間隔も、⚠ 中の字も小さい段にする。
	var stats_panel: PanelContainer = PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.theme_type_variation = &"CompactCardPanel"
	info_column.add_child(stats_panel)

	var stats_column: VBoxContainer = VBoxContainer.new()
	stats_column.name = "StatsColumn"
	stats_column.theme_type_variation = &"TightList"
	stats_panel.add_child(stats_column)

	var stats: Dictionary = GameManager.get_effective_stats(_selected_id)
	var bonus: Dictionary = GameManager.get_equipment_bonus(_selected_id)
	for stat_key: String in GameManager.get_stat_keys():
		var row: ValueRow = ValueRow.create(
			tr("ui_training_stat_" + stat_key),
			_stat_value_text(stat_key, int(stats.get(stat_key, 0))),
			ValueRow.VARIATION_PLAIN,
			IconTextures.for_stat(stat_key)
		)
		var added: int = int(bonus.get(stat_key, 0))
		# ⚠ 増えていない行にも空の欄を置く（⚠ 置かないと値の右端がずれる）。
		row.set_delta("+" + _stat_value_text(stat_key, added) if added > 0 else "")
		stats_column.add_child(row)
		# ⚠ 木に入れてから詰める（⚠ Theme から字の段を引くため）。
		row.set_compact()

	info_column.add_child(_create_cost_line(level, cap))

	# 次のレベルで何が上がるか。⚠ 上限なら出さない。
	var preview: String = _next_level_text(level, cap)
	if preview != "":
		var preview_label: Label = Label.new()
		preview_label.name = "PreviewLabel"
		preview_label.theme_type_variation = &"CaptionLabel"
		preview_label.text = preview
		info_column.add_child(preview_label)

	if _notice_text != "":
		var notice: Label = Label.new()
		notice.name = "NoticeLabel"
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.text = _notice_text
		info_column.add_child(notice)


# 「Lv13 に必要な修練の証　　3 ／ 所持 57」。
func _create_cost_line(level: int, cap: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CostLine"
	panel.theme_type_variation = &"InsetPanel"
	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	if level >= cap:
		var maxed: Label = Label.new()
		maxed.text = tr("ui_training_max_level")
		row.add_child(maxed)
		return panel

	var cost: Dictionary = GameManager.get_level_up_cost(_selected_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var icon: TextureRect = _create_icon(IconTextures.for_item(material_id), AVATAR_LIST / 2)
	if icon != null:
		row.add_child(icon)

	var label: Label = Label.new()
	label.name = "CostLabel"
	label.text = tr("ui_training_cost_for") % [level + 1, tr("ui_res_" + material_id)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value: Label = Label.new()
	value.name = "CostValue"
	value.text = tr("ui_training_cost_owned") % [amount, GameManager.get_material_count(material_id)]
	row.add_child(value)
	return panel


# 「Lv13 で HP +12、攻撃 +3、ポイント +1。」
#
# ⚠ 伸びる軸だけ並べる（⚠ 0 の軸は出さない）。⚠ 差は `get_stats_at_level()` の差分。
#   ⚠ `growth_per_level` を直接足さない（⚠ 伸び方は式が決める）。
# ⚠ ポイントは必ず +1（⚠ `get_stat_node_total_points()` が「レベル-1」）。
func _next_level_text(level: int, cap: int) -> String:
	if level >= cap:
		return ""
	var current: Dictionary = GameManager.get_stats_at_level(_selected_id, level)
	var next: Dictionary = GameManager.get_stats_at_level(_selected_id, level + 1)
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var diff: int = int(next.get(stat_key, 0)) - int(current.get(stat_key, 0))
		if diff <= 0:
			continue
		parts.append("%s +%s" % [
			tr("ui_training_stat_" + stat_key), _stat_value_text(stat_key, diff),
		])
	parts.append(tr("ui_training_next_point"))
	return tr("ui_training_next_level") % [level + 1, "、".join(parts)]


# 右カラム。⚠ `LevelUpButton` だけ `.tscn` が持つ（⚠ 消さずに文言と活性だけ変える）。
func _rebuild_actions() -> void:
	for child: Node in action_column.get_children():
		if child == level_up_button:
			continue
		action_column.remove_child(child)
		child.queue_free()

	var level: int = _level_of(_selected_id)
	var cap: int = GameManager.get_effective_level_cap(_selected_id)
	var cost: Dictionary = GameManager.get_level_up_cost(_selected_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var at_cap: bool = level >= cap
	var enough: bool = GameManager.get_material_count(material_id) >= amount

	# ⚠ コストをボタンの中に入れる（⚠ モック：「レベルアップ　修練の証 3」）。
	#   ⚠ 押せてから失敗するより、押せないほうが分かりやすい。
	level_up_button.text = tr("ui_training_level_up") if at_cap else tr("ui_training_level_up_cost") % [
		tr("ui_training_level_up"), tr("ui_res_" + material_id), amount,
	]
	level_up_button.disabled = at_cap or not enough

	action_column.add_child(HSeparator.new())
	action_column.add_child(_create_section_label("ui_training_settings"))

	action_column.add_child(_create_action_row(
		"ui_training_nodes",
		str(GameManager.get_stat_node_remaining_points(_selected_id)),
		true,
		_on_stat_node_pressed
	))
	action_column.add_child(_create_action_row(
		"ui_training_skill",
		"%d / %d" % [_selected_skill_count(), GameManager.get_skill_slot_count()],
		false,
		_on_skill_pressed
	))
	# 段階解放（GAME_DESIGN.md 9-5 の #2 装備）。⚠ 「出さない」（人間の決定）。
	# ⚠ 装備画面への入口はここ1箇所だけ（ギルドに装備のボタンは無い）。
	if GameManager.is_screen_unlocked(GameStateKeys.SCREEN_EQUIPMENT):
		action_column.add_child(_create_action_row(
			"ui_training_equipment",
			"%d / %d" % [_equipped_count(), GameManager.get_equip_slots().size()],
			false,
			_on_equip_pressed
		))
	# ⚠⚠ 転職は**まだ1行も無い機能**（⚠ コードにもデータにも `job_change` は0件）。
	#   ⚠ モックは「Lv20 で解放」と書いていたが、⚠ **その 20 はどこにも無い数字**なので
	#   ⚠ 書かない（AGENTS.md「数値をハードコードしない」「欄だけ足して実装しない」）。
	#   ⚠ 押せない行として置き場所だけ取る。⚠ 作る回が来たら文言と行き先を入れる。
	action_column.add_child(_create_action_row("ui_training_job_change", tr("ui_common_wip"), false, Callable()))

	action_column.add_child(HSeparator.new())
	action_column.add_child(_create_section_label("ui_training_build"))
	_build_preset_row()

	var spacer: Control = Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_column.add_child(spacer)

	var to_list: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_training_to_list")
	to_list.name = "ToListButton"
	to_list.pressed.connect(_show_list)
	action_column.add_child(to_list)


# 「[絵] ステータス割り振り　　5 ›」の1行。⚠ 押せる範囲は行ぜんぶ。
#
# ⚠ `handler` が空なら押せない行（⚠ 転職）。⚠ 押しても何も起きないボタンを作らない。
func _create_action_row(
	label_key: String, badge_text: String, accent: bool, handler: Callable
) -> PanelContainer:
	# ⚠ 右のメニューも詰めた形（⚠ 人間の指示「半分ぐらいの大きさに」）。
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Action_" + label_key
	panel.theme_type_variation = &"CompactRowPanel"
	panel.modulate.a = 1.0 if handler.is_valid() else 0.4

	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	var label: Label = Label.new()
	label.name = "NameLabel"
	# ⚠ 字も小さい段にする（⚠ 余白だけ詰めても行は半分にならない）。
	label.theme_type_variation = &"SmallLabel"
	label.text = tr(label_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var badge: Label = Label.new()
	badge.name = "BadgeLabel"
	# ⚠ 「まだ振っていないポイントが在る」だけ琥珀（⚠ 次にやることを1つに絞る）。
	badge.theme_type_variation = &"AccentLabel" if accent and badge_text != "0" else &"CaptionLabel"
	badge.text = badge_text
	row.add_child(badge)

	if handler.is_valid():
		UiButton.attach_hit(panel, handler)
	return panel


# 「[ビルドN ▼]」＋「焼く／適用」。⚠ 向きの説明を上に出す（⚠ モック）。
func _build_preset_row() -> void:
	_build_picker = OptionButton.new()
	_build_picker.name = "BuildPicker"
	_build_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 項目は _refresh_preset_row() が入れる。ここで入れると空きの表示が古くなる。
	# ⚠ 接続は項目を入れる前でよい（add_item / select は item_selected を出さない）。
	_build_picker.item_selected.connect(_on_build_selected)
	action_column.add_child(_build_picker)

	var directions: HBoxContainer = HBoxContainer.new()
	directions.name = "Directions"
	action_column.add_child(directions)
	for key: String in ["ui_party_preset_burn_hint", "ui_party_preset_apply_hint"]:
		var hint: Label = Label.new()
		hint.theme_type_variation = &"SectionLabel"
		hint.text = tr(key)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		directions.add_child(hint)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "PresetButtons"
	action_column.add_child(buttons)

	var burn: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_party_preset_burn")
	burn.name = "BurnButton"
	burn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	burn.pressed.connect(_on_burn_pressed)
	buttons.add_child(burn)

	var apply: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_party_preset_apply")
	apply.name = "ApplyButton"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.pressed.connect(_on_apply_pressed)
	buttons.add_child(apply)

	_refresh_preset_row()


# 選択肢の「（空き）」表示を、いまの保存状態に合わせて作り直す。
func _refresh_preset_row() -> void:
	if _build_picker == null or _selected_id == "":
		return
	var presets: Array = GameManager.get_character_presets(_selected_id)
	var count: int = GameManager.get_character_preset_count()
	if _selected_build >= count:
		_selected_build = 0

	_build_picker.clear()
	for i: int in range(count):
		var label: String = tr("ui_party_preset_build") % (i + 1)
		var entry: Variant = presets[i] if i < presets.size() else null
		var saved: bool = entry is Dictionary and bool((entry as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		if not saved:
			label += "（%s）" % tr("ui_party_preset_empty")
		_build_picker.add_item(label)
	_build_picker.select(_selected_build)


func _on_build_selected(item_index: int) -> void:
	# ⚠ ここでは状態を触らない。焼く先が変わるだけ。
	_selected_build = item_index


func _on_burn_pressed() -> void:
	if _selected_id == "":
		return
	if not GameManager.save_character_preset(_selected_id, _selected_build):
		# 失敗の理由は GameManager 側が push_error 済み。
		return
	# ⚠ 保存したことが分かる合図を出す。出さないと「押しても何も起きない」に見える。
	_notice_text = tr("ui_party_preset_burned") % (_selected_build + 1)
	_refresh_detail()


# ビルドを当て直す。⚠ 編成は触らない（このキャラの中身だけ）。
func _on_apply_pressed() -> void:
	if _selected_id == "":
		return
	var report: Dictionary = GameManager.apply_character_preset(_selected_id, _selected_build)
	# ⚠ 文面は GameManager が組む（適用の口が3つあるため）。
	_notice_text = GameManager.format_apply_report(report)
	_refresh_detail()


# --- 操作 ---

func _on_level_up_pressed() -> void:
	if _selected_id == "":
		return
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	# 失敗（上限・素材不足）はボタンが押せない状態で防いでいる。
	GameManager.level_up_character(_selected_id)


# ステータスノード画面も独立した画面。装備画面と同じ形で ID を渡す。
# 3枝×20段のツリーが詳細パネルに収まらないため、ここには置かない。
func _on_stat_node_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(STAT_NODE_PATH, {TransferKeys.CHARACTER_ID: _selected_id})

# スキル選択画面も独立した画面（EXEC_SKILL_SELECT.md §8-3）。
# 枠2つ＋候補一覧が詳細パネルに収まらないため、ステータスノードと同じ形にした。
func _on_skill_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(SKILL_SELECT_PATH, {TransferKeys.CHARACTER_ID: _selected_id})

# 装備画面は独立した画面。どのキャラの装備を編集するかを TransferKeys で渡す。
func _on_equip_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(EQUIPMENT_PATH, {TransferKeys.CHARACTER_ID: _selected_id})

# ⚠ 一覧のときはギルドへ、⚠ 詳細のときは一覧へ戻る（⚠ ヘッダーの戻るは1つ）。
func _on_back_pressed() -> void:
	if _selected_id != "":
		_show_list()
		return
	SceneManager.change_scene(GUILD_PATH)


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if _selected_id == "":
		_rebuild_list()
	elif character_id == _selected_id:
		_refresh_detail()


func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	# 素材はレベルアップ以外（戦闘報酬など）でも変わりうるため、種類を問わず引き直す。
	if _selected_id != "":
		_refresh_detail()
	else:
		_rebuild_list()


# --- 内部ヘルパー ---

func _level_of(character_id: String) -> int:
	return int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


# 「Lv 12 ／ 上限 40　　未使用ポイント 5」。⚠ 余っていなければ後半を出さない。
func _level_text(character_id: String, level: int, cap: int) -> String:
	var text: String = tr("ui_training_level_of_cap") % [level, cap]
	var remaining: int = GameManager.get_stat_node_remaining_points(character_id)
	if remaining > 0:
		text += "　　" + tr("ui_training_unused_points") % remaining
	return text


func _selected_skill_count() -> int:
	var count: int = 0
	for entry: Variant in GameManager.get_selected_skills(_selected_id, GameManager.SLOT_KIND_SKILL):
		if str(entry) != "":
			count += 1
	return count


func _equipped_count() -> int:
	var count: int = 0
	for slot: String in GameManager.get_equip_slots():
		if GameManager.get_equipped_instance_id(_selected_id, slot) != "":
			count += 1
	return count


# ⚠ レベルアップに使う素材のID。⚠ 一覧のときは誰の分でも同じ素材なので先頭で引く。
func _level_up_material_id() -> String:
	var target: String = _selected_id
	if target == "":
		for character_id: Variant in MasterDataLoader.get_all_characters():
			if not GameManager.is_debug_character(str(character_id)):
				target = str(character_id)
				break
	if target == "":
		return ""
	return str(GameManager.get_level_up_cost(target).get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))


# ⚠ 線画は 48px で読み込まれる。⚠ 器は必ず `EXPAND_IGNORE_SIZE`（§0-UI-B-1）。
func _create_icon(texture: Texture2D, size_px: int) -> TextureRect:
	if texture == null:
		return null
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


# ％系は "25%" と出す。実数はそのまま。
# 翻訳キーは "ui_training_stat_" + stat_key で機械的に引く（AGENTS.md 翻訳キーの運用）。
# 軸を足したら ja.csv に1行足すだけで、この画面は直さなくてよい。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
