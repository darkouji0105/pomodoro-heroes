# res://scenes/adventure/adventure_select.gd
# 冒険選択画面。AGENTS.md / EXEC_ADVENTURE_SELECT.md 準拠。
# ステージ一覧を stage_order.json 順で生成し、解放判定は GameManager.is_stage_cleared() で行う。
# スタミナの消費はこの画面でのみ行う（戦闘画面では消費しない）。

extends Control

# --- 定数 ---
# EXEC §5-7: パスは const で持つ（base_screen.gd の BASE_PATH と同じ流儀）
const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"

# --- ノード参照 ---
@onready var stamina_value: ResourceDisplay = $Layout/Header/StaminaValue
@onready var message_label: Label = $Layout/MessageLabel
@onready var stage_list: VBoxContainer = $Layout/StageList
@onready var training_button: PrimaryButton = $Layout/Footer/TrainingButton
@onready var back_button: PrimaryButton = $Layout/Footer/BackButton

# --- 内部状態 ---
# ステージ行（stage_id -> {"row": HBoxContainer, "button": PrimaryButton}）。未解放時の挙動切替用
var _stage_rows: Dictionary = {}

func _ready() -> void:
	# 拠点から渡される transfer data を 1 回だけ消費して捨てる（EXEC §5-1）。
	# 呼ばないと次の遷移に前回のデータが残るため必須。
	SceneManager.consume_transfer_data()

	# 順序: スタミナ表示 → ステージ行生成 → シグナル接続 → フッター接続 → メッセージ初期化
	_update_stamina_display()
	_build_stage_list()
	_connect_signals()
	message_label.text = ""

func _update_stamina_display() -> void:
	var state: Dictionary = GameManager.get_state()
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	stamina_value.set_value_with_max(
		int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
		int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	)

func _build_stage_list() -> void:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	for i: int in range(order.size()):
		var stage_id: String = order[i]
		var stage_data: Dictionary = MasterDataLoader.get_stage(stage_id)
		if stage_data.is_empty():
			push_error("[AdventureSelect] stage data not found for order entry: " + stage_id)
			continue
		_add_stage_row(stage_id, stage_data, i, order)

func _add_stage_row(stage_id: String, stage_data: Dictionary, index: int, order: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "StageRow_" + stage_id

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"

	var spacer: Control = Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = 3

	var cost_label: Label = Label.new()
	cost_label.name = "CostLabel"
	# 数値のみなので tr() は通さない（AGENTS.md）
	cost_label.text = str(Balance.adventure.stamina_cost_per_stage)

	var challenge_button: PrimaryButton = PrimaryButton.new()
	challenge_button.name = "ChallengeButton"
	# 翻訳キーを直接 text に入れる。auto_translate_mode がデフォルトで有効なので
	# Godot が起動時に tr() を自動適用する（Label と同じ挙動）。
	# EXEC §6 に「挑戦ボタン」の翻訳キーが定義されていないため、
	# ja.csv 未登録ならフォールバックでキー名がそのまま表示される（AGENTS.md 許容挙動）。
	challenge_button.text = "ui_adventure_challenge"

	row.add_child(name_label)
	row.add_child(spacer)
	row.add_child(cost_label)
	row.add_child(challenge_button)
	stage_list.add_child(row)

	# 解放判定（EXEC §4.2）
	var unlocked: bool = (index == 0) or GameManager.is_stage_cleared(order[index - 1])
	var cleared: bool = GameManager.is_stage_cleared(stage_id)

	# 3 状態の出し分け（EXEC §4.4）
	var name_key: String = str(stage_data.get("name_key", stage_id))
	var base_name: String = tr(name_key)
	if cleared:
		name_label.text = base_name + " ✓"
	elif unlocked:
		name_label.text = base_name
	else:
		name_label.text = base_name + " 🔒"
		name_label.modulate = Color(0.5, 0.5, 0.5)

	# 未解放でも disabled にしない（EXEC §4.4 / §8-1）
	# 押したらハンドラ内で理由を出す

	# 接続（bind で stage_id と challenge_button を行に紐付け）
	challenge_button.pressed.connect(_on_challenge_pressed.bind(stage_id))

	_stage_rows[stage_id] = {"row": row, "button": challenge_button}

func _connect_signals() -> void:
	GameManager.resource_changed.connect(_on_resource_changed)
	training_button.pressed.connect(_on_training_pressed)
	back_button.pressed.connect(_on_back_pressed)

# --- シグナルハンドラ ---

func _on_resource_changed(resource_type: String, new_value: Variant) -> void:
	if resource_type == GameStateKeys.STAMINA:
		# 第2引数には current 単体しか入らない。max は get_state() から読み直す（AGENTS.md / EXEC §6.2）
		var state: Dictionary = GameManager.get_state()
		var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
		var stamina_max: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
		stamina_value.set_value_with_max(int(new_value), stamina_max)
	elif resource_type == GameStateKeys.GOLD or resource_type == GameStateKeys.GEMS:
		# この画面では表示していないので無視
		pass
	else:
		push_warning("[AdventureSelect] unknown resource_type: " + resource_type)

func _on_challenge_pressed(stage_id: String) -> void:
	# 解放状態の最終チェック（EXEC §5.1）
	if not _is_unlocked(stage_id):
		message_label.text = tr("ui_adventure_locked")
		return

	# スタミナ消費（EXEC §5.2 / §5.3）
	var cost: int = int(Balance.adventure.stamina_cost_per_stage)
	var state: Dictionary = GameManager.get_state()
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	if current < cost:
		message_label.text = tr("ui_adventure_stamina_short") + " (%d / %d)" % [cost, current]
		return

	# 遷移（EXEC §5.4）。PARTY_ID は渡さない
	SceneManager.change_scene_with_data(
		BATTLE_PATH,
		{
			TransferKeys.STAGE_ID: stage_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
		}
	)

func _on_training_pressed() -> void:
	# トレーニングは未実装なので placeholder へ（EXEC §5-7）
	SceneManager.change_scene_with_data(
		PLACEHOLDER_PATH,
		{TransferKeys.SCREEN_ID: GameStateKeys.SCREEN_ADVENTURE_SELECT}
	)

func _on_back_pressed() -> void:
	# 履歴に依存せず明示的に拠点へ（EXEC §5-7 / base_screen.gd と同じ）
	SceneManager.change_scene(BASE_PATH)

# --- ヘルパー ---

# 解放判定。stage_order の index 関係のみを使う（EXEC §4.2）。
# ステージ ID から数字を切り出さない（PRE_PLAN §4.3）。
func _is_unlocked(stage_id: String) -> bool:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	var idx: int = order.find(stage_id)
	if idx < 0:
		push_error("[AdventureSelect] stage_id not in order: " + stage_id)
		return false
	if idx == 0:
		return true
	var prev_id: String = order[idx - 1]
	return GameManager.is_stage_cleared(prev_id)
