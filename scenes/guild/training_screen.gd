# res://scenes/guild/training_screen.gd
# ギルド：育成画面（第1弾＝レベルアップのみ）。
# 一覧と詳細を同一シーン内で切り替える。シーンは分けない。
# スキル・装備はボタンのみ置き、placeholder_screen へ飛ばす。

class_name TrainingScreen
extends Control

const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

# MasterDataLoader にキー一覧を返す関数が無いため、ここに列挙する。
# このタスクで決め打ちを許した唯一の箇所（EXEC_GUILD_TRAINING §4-4）。
# キャラクターを追加したらここにも足すこと。
const CHARACTER_IDS: Array[String] = [
	"char_swordsman",
	"char_archer",
	"char_priest",
]

# placeholder_screen に渡す screen_id。翻訳キーは "ui_nav_" + screen_id で引かれる。
const SCREEN_ID_SKILL: String = "training_skill"
const EQUIPMENT_PATH: String = "res://scenes/guild/equipment_screen.tscn"
const STAT_NODE_PATH: String = "res://scenes/guild/stat_node_screen.tscn"

# 詳細を表示中のキャラクターID。一覧表示中は空文字。
var _selected_id: String = ""

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

	level_up_button.pressed.connect(_on_level_up_pressed)
	stat_node_button.pressed.connect(_on_stat_node_pressed)
	skill_button.pressed.connect(_go_to_placeholder.bind(SCREEN_ID_SKILL))
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


func _go_to_placeholder(screen_id: String) -> void:
	SceneManager.change_scene_with_data(PLACEHOLDER_PATH, {TransferKeys.SCREEN_ID: screen_id})

# ステータスノード画面も独立した画面。装備画面と同じ形で ID を渡す。
# 3枝×20段のツリーが詳細パネルに収まらないため、ここには置かない。
func _on_stat_node_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(STAT_NODE_PATH, {TransferKeys.CHARACTER_ID: _selected_id})

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
