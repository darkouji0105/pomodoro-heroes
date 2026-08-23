# res://scenes/guild/guild_screen.gd
# ギルド画面：4つのサブ画面（倉庫/ショップ/育成/研究）への遷移ボタンと
# 拠点への戻るボタンを持つ。指示書 EXEC_GUILD_WAREHOUSE.md §2 準拠。
# 遷移先は GUILD_SCENES に集約し、ボタンごとに直書きしない（完了条件17）。

class_name GuildScreen
extends Control

# --- シーン ---
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const WAREHOUSE_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const RESEARCH_PATH: String = "res://scenes/guild/research_screen.tscn"
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
# ⚠ 作業場は廃止中（EXEC_WORKSHOP_RETIRE.md）。recipes.json が 0 件になり
#   到達しても空の画面が出るだけのため、GUILD_SCENES と _nav_buttons から外し、
#   .tscn 側の WorkshopButton を visible = false にしてある。
# ⚠ この定数とノード参照は消していない。GAME_DESIGN 9-3（中間素材の製作＋
#   装飾のランダム製作）で復活させるとき、1行ずつ戻すだけで済むようにするため。
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"


# sub_screen_id -> 遷移先パス
const GUILD_SCENES: Dictionary = {
	"warehouse": WAREHOUSE_PATH,
	"shop": SHOP_PATH,
	"training": TRAINING_PATH,
	"research": RESEARCH_PATH,
}

# sub_screen_id -> PrimaryButton（_ready で組み立てる）
var _nav_buttons: Dictionary = {}

# --- ノード参照 ---
@onready var warehouse_button: PrimaryButton = $CenterContainer/Layout/WarehouseButton
@onready var shop_button: PrimaryButton = $CenterContainer/Layout/ShopButton
@onready var training_button: PrimaryButton = $CenterContainer/Layout/TrainingButton
@onready var research_button: PrimaryButton = $CenterContainer/Layout/ResearchButton
@onready var workshop_button: PrimaryButton = $CenterContainer/Layout/WorkshopButton
@onready var back_button: PrimaryButton = $CenterContainer/Layout/BackButton

func _ready() -> void:
	# 4つのボタンを Dictionary 化（4回同じコードを書かない）
	# ⚠ workshop は廃止中のため入れない（上の GUILD_SCENES のコメント）。
	_nav_buttons = {
		"warehouse": warehouse_button,
		"shop": shop_button,
		"training": training_button,
		"research": research_button,
	}
	# ループでシグナル接続
	for sub_id: String in _nav_buttons:
		_nav_buttons[sub_id].pressed.connect(_go_to_sub.bind(sub_id))
	back_button.pressed.connect(_on_back_pressed)

func _go_to_sub(sub_id: String) -> void:
	var path: String = str(GUILD_SCENES.get(sub_id, ""))
	if path == "":
		push_warning("[GuildScreen] unknown sub_screen_id: " + sub_id)
		return
	# 未実装画面は placeholder_screen が screen_id を表示に使うため SCREEN_ID を渡す
	if path == PLACEHOLDER_PATH:
		SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: sub_id})
	else:
		# 倉庫画面はそのまま開く（タブ指定が必要なら呼び出し側で change_scene_with_data を使う）
		SceneManager.change_scene(path)

func _on_back_pressed() -> void:
	# 拠点へ戻る。go_back() は履歴管理がダミー扱いのため使わない
	SceneManager.change_scene(BASE_PATH)
