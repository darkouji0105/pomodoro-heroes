# res://scenes/guild/training_screen.gd
# ギルド：育成画面（第1弾＝レベルアップのみ）。
# 一覧と詳細を同一シーン内で切り替える。シーンは分けない。
# スキル・装備はボタンのみ置き、placeholder_screen へ飛ばす。

class_name TrainingScreen
extends Control

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# MasterDataLoader にキー一覧を返す関数が無いため、ここに列挙する。
# このタスクで決め打ちを許した唯一の箇所（EXEC_GUILD_TRAINING §4-4）。
# キャラクターを追加したらここにも足すこと。
# ⚠ 下3件は検証用（EXEC_SKILL_MULTIFILE.md）。リリース前に消すこと。
#   ここに無いと育成画面に出ず、スキル選択画面へ到達できない
#   ＝検証用スキルを枠に付け替えられない。
const CHARACTER_IDS: Array[String] = [
	"char_swordsman",
	"char_archer",
	"char_priest",
	"char_debug_status",
	"char_debug_life",
	"char_debug_mix",
]

const EQUIPMENT_PATH: String = "res://scenes/guild/equipment_screen.tscn"
const STAT_NODE_PATH: String = "res://scenes/guild/stat_node_screen.tscn"
const SKILL_SELECT_PATH: String = "res://scenes/guild/skill_select_screen.tscn"

# 詳細を表示中のキャラクターID。一覧表示中は空文字。
var _selected_id: String = ""

# ビルド（キャラプリセット）を焼く行（EXEC_PARTY_PRESETS.md）。
#
# ⚠ プリセットが持つのは割り振り・スキル枠・パッシブ枠で、⚠ どれもこの画面の
#   配下（育成 → 割り振り／スキル選択）で決まる。⚠ だから焼くのもここでできる
#   ほうが自然（人間の指摘・2026-08-23「スキルのプリセットは育成でも焼けるように」）。
# ⚠ .tscn を触らずコードで作る。⚠ DetailPanel は VBoxContainer で、
#   兄弟は layout_mode = 2 だけ（size_flags を持たない）。同じ形にすること。
var _build_picker: OptionButton = null
var _selected_build: int = 0

@onready var material_label: Label = $Margin/Layout/MaterialLabel
@onready var list_panel: VBoxContainer = $Margin/Layout/ListPanel
@onready var detail_panel: VBoxContainer = $Margin/Layout/DetailPanel
@onready var name_label: Label = $Margin/Layout/DetailPanel/NameLabel
@onready var level_label: Label = $Margin/Layout/DetailPanel/LevelLabel
@onready var stats_label: Label = $Margin/Layout/DetailPanel/StatsLabel
@onready var cost_label: Label = $Margin/Layout/DetailPanel/CostLabel
@onready var notice_label: Label = $Margin/Layout/DetailPanel/NoticeLabel
@onready var level_up_button: PrimaryButton = $Margin/Layout/DetailPanel/LevelUpButton
@onready var stat_node_button: PrimaryButton = $Margin/Layout/DetailPanel/StatNodeButton
@onready var skill_button: PrimaryButton = $Margin/Layout/DetailPanel/SkillButton
@onready var equip_button: PrimaryButton = $Margin/Layout/DetailPanel/EquipButton
@onready var to_list_button: PrimaryButton = $Margin/Layout/DetailPanel/ToListButton
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton


func _ready() -> void:
	_build_character_list()
	_build_preset_row()

	level_up_button.pressed.connect(_on_level_up_pressed)
	stat_node_button.pressed.connect(_on_stat_node_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	to_list_button.pressed.connect(_show_list)
	back_button.pressed.connect(_on_back_pressed)

	# レベルアップの結果は戻り値ではなくシグナルで受けて描画し直す。
	# 表示更新の経路を1本にしておくと、他画面から育成データが変わっても追従する。
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.material_changed.connect(_on_material_changed)

	_show_list()


# --- 一覧 ---

func _build_character_list() -> void:
	for child in list_panel.get_children():
		child.queue_free()

	for character_id: String in CHARACTER_IDS:
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		if char_data.is_empty():
			# MasterDataLoader 側で push_error 済み。ここでは静かに飛ばす。
			continue

		var button: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
		list_panel.add_child(button)
		# label_key は使わず text を直接入れる（名前とレベルを1行にまとめるため）。
		button.text = "%s  %s" % [
			tr(str(char_data.get("name_key", ""))),
			tr("ui_training_level") % _level_of(character_id),
		]
		button.pressed.connect(_show_detail.bind(character_id))


func _show_list() -> void:
	_selected_id = ""
	detail_panel.visible = false
	list_panel.visible = true
	_refresh_material_label()
	# レベルアップ後に戻ってきたときのため、一覧のラベルも作り直す。
	_build_character_list()


# --- ビルドを焼く ---

# 「[ビルド1 ▼][焼く]」の1行を、詳細の「一覧へ戻る」の手前に差し込む。
#
# ⚠ 1回だけ作る。⚠ _refresh_detail() のたびに作り直すと、押すたびに行が増える。
#   中身（空きかどうか）の更新は _refresh_preset_row() が持つ。
func _build_preset_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow"

	_build_picker = OptionButton.new()
	_build_picker.name = "BuildPicker"
	_build_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 項目は _refresh_preset_row() が入れる。ここで入れると空きの表示が古くなる。
	# ⚠ 接続は項目を入れる前でよい（add_item / select は item_selected を出さない）。
	_build_picker.item_selected.connect(_on_build_selected)
	row.add_child(_build_picker)

	var burn: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
	burn.name = "BurnButton"
	burn.label_key = "ui_party_preset_burn"
	burn.pressed.connect(_on_burn_pressed)
	row.add_child(burn)

	# ⚠ 「焼く」と「適用」は向きが逆（焼く＝現在→ビルド／適用＝ビルド→現在）。
	#   ⚠ 1つのボタンにまとめないこと。
	var apply: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
	apply.name = "ApplyButton"
	apply.label_key = "ui_party_preset_apply"
	apply.pressed.connect(_on_apply_pressed)
	row.add_child(apply)

	detail_panel.add_child(row)
	# ⚠ add_child は末尾に付くので、必ず移動させる（「一覧へ戻る」より上へ）。
	detail_panel.move_child(row, to_list_button.get_index())


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
	notice_label.text = tr("ui_party_preset_burned") % (_selected_build + 1)
	_refresh_preset_row()


# ビルドを当て直す。⚠ 編成は触らない（このキャラの中身だけ）。
func _on_apply_pressed() -> void:
	if _selected_id == "":
		return
	var report: Dictionary = GameManager.apply_character_preset(_selected_id, _selected_build)
	# ⚠ 文面は GameManager が組む（適用の口が3つあるため）。
	# ⚠ _refresh_detail() が notice を上書きするので、先に描き直してから入れる。
	_refresh_detail()
	notice_label.text = GameManager.format_apply_report(report)


# --- 詳細 ---

func _show_detail(character_id: String) -> void:
	_selected_id = character_id
	list_panel.visible = false
	detail_panel.visible = true
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id == "":
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_selected_id)
	var level: int = _level_of(_selected_id)
	var stats: Dictionary = GameManager.get_effective_stats(_selected_id)

	name_label.text = tr(str(char_data.get("name_key", "")))
	level_label.text = tr("ui_training_level") % level
	var lines: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		lines.append("%s  %s" % [
			tr("ui_training_stat_" + stat_key),
			_stat_value_text(stat_key, int(stats.get(stat_key, 0))),
		])
	stats_label.text = "\n".join(lines)

	var cost: Dictionary = GameManager.get_level_up_cost(_selected_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)

	cost_label.text = "%s  %s x%d　（%s %d）" % [
		tr("ui_training_cost"),
		tr("ui_res_" + material_id),
		amount,
		tr("ui_training_owned"),
		owned,
	]

	var cap: int = GameManager.get_effective_level_cap(_selected_id)
	var at_cap: bool = level >= cap
	var enough: bool = owned >= amount

	# 上限のときだけ案内を出す。素材不足はボタンが押せないことと所持数の表示で分かる。
	notice_label.text = tr("ui_training_max_level") if at_cap else ""
	# 押せてから失敗するより、押せないほうが分かりやすい。
	level_up_button.disabled = at_cap or not enough

	# ⚠ ビルドの「（空き）」表示は、他の画面で焼かれると古くなる。ここで作り直す。
	_refresh_preset_row()

	_refresh_material_label()


func _refresh_material_label() -> void:
	var cost: Dictionary = GameManager.get_level_up_cost(
		_selected_id if _selected_id != "" else CHARACTER_IDS[0]
	)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	if material_id == "":
		material_label.text = ""
		return
	material_label.text = "%s  %d" % [
		tr("ui_res_" + material_id),
		GameManager.get_material_count(material_id),
	]


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
# 詳細を開いていないときは押せない位置にあるため _selected_id は必ず入っている。
func _on_equip_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(EQUIPMENT_PATH, {TransferKeys.CHARACTER_ID: _selected_id})

func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)


# --- シグナル ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _selected_id:
		_refresh_detail()


func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	# 素材はレベルアップ以外（戦闘報酬など）でも変わりうるため、種類を問わず引き直す。
	if _selected_id != "":
		_refresh_detail()
	else:
		_refresh_material_label()


# --- 内部ヘルパー ---

func _level_of(character_id: String) -> int:
	return int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


# ％系は "25%" と出す。実数はそのまま。
# 翻訳キーは "ui_training_stat_" + stat_key で機械的に引く（AGENTS.md 翻訳キーの運用）。
# 軸を足したら ja.csv に1行足すだけで、この画面は直さなくてよい。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
