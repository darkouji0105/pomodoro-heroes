# res://scenes/guild/guild_screen.gd
# ギルド画面：5つのサブ画面（倉庫/ショップ/育成/研究/作業場）への遷移ボタンと
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
# ⚠ 作業場は段階11で復活した（EXEC_WORKSHOP_REVIVE.md）。装飾のランダム製作。
#   ⚠ 開くのは stage_3 のクリア（stages.json の unlocks）。閉じている間は
#     _refresh_unlocked() が visible = false にする（.tscn 側では閉じない）。
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"


# sub_screen_id -> 遷移先パス
# ⚠ sub_screen_id は GameStateKeys の画面IDと同じ綴り（段階9）。
#   ⚠ 文字列リテラルを書かないこと（AGENTS.md）。unlocked_screens のキーでもある。
const GUILD_SCENES: Dictionary = {
	GameStateKeys.SCREEN_WAREHOUSE: WAREHOUSE_PATH,
	GameStateKeys.SCREEN_SHOP: SHOP_PATH,
	GameStateKeys.SCREEN_TRAINING: TRAINING_PATH,
	GameStateKeys.SCREEN_RESEARCH: RESEARCH_PATH,
	GameStateKeys.SCREEN_WORKSHOP: WORKSHOP_PATH,
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
	# 5つのボタンを Dictionary 化（5回同じコードを書かない）
	_nav_buttons = {
		GameStateKeys.SCREEN_WAREHOUSE: warehouse_button,
		GameStateKeys.SCREEN_SHOP: shop_button,
		GameStateKeys.SCREEN_TRAINING: training_button,
		GameStateKeys.SCREEN_RESEARCH: research_button,
		GameStateKeys.SCREEN_WORKSHOP: workshop_button,
	}
	# ループでシグナル接続
	for sub_id: String in _nav_buttons:
		_nav_buttons[sub_id].pressed.connect(_go_to_sub.bind(sub_id))
	back_button.pressed.connect(_on_back_pressed)
	# 段階解放（GAME_DESIGN.md 9-5）。⚠ base_screen.gd と同じ1行。
	#   ⚠ 閉じ方は _refresh_unlocked() の1箇所だけ。.tscn 側で二重に閉じない。
	GameManager.screen_unlocked.connect(_on_screen_unlocked)
	_refresh_unlocked()

# ⚠ 「出さない」（人間の決定・2026-08-24）。灰色で見せない。
func _refresh_unlocked() -> void:
	for sub_id: String in _nav_buttons:
		_nav_buttons[sub_id].visible = GameManager.is_screen_unlocked(sub_id)

func _on_screen_unlocked(_screen_id: String) -> void:
	_refresh_unlocked()

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
