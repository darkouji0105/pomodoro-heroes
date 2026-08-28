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
const PARTY_PRESET_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"

# --- ノード参照 ---
@onready var stamina_value: ResourceDisplay = $Layout/Header/StaminaValue
@onready var message_label: Label = $Layout/MessageLabel
@onready var stage_list: VBoxContainer = $Layout/StageList
@onready var training_button: PrimaryButton = $Layout/Footer/TrainingButton
@onready var back_button: PrimaryButton = $Layout/Footer/BackButton

# --- 内部状態 ---
# ステージ行（stage_id -> {"row": HBoxContainer, "button": PrimaryButton}）。未解放時の挙動切替用
var _stage_rows: Dictionary = {}

# 編成の枠を包む箱。作り直すときに丸ごと外す（EXEC_PARTY_MEMBERS.md）。
var _party_box: VBoxContainer = null

# ⚠ 候補の一覧は GameManager.get_party_candidates() に移した（2画面が要るようになったため。
#   EXEC_PARTY_PRESETS.md §7-3）。ここに2本目を書かないこと。

func _ready() -> void:
	# 拠点から渡される transfer data を 1 回だけ消費して捨てる（EXEC §5-1）。
	# 呼ばないと次の遷移に前回のデータが残るため必須。
	SceneManager.consume_transfer_data()

	# 順序: スタミナ表示 → 編成 → ステージ行生成 → シグナル接続 → フッター接続 → メッセージ初期化
	_update_stamina_display()
	_build_party_row()
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

# 編成の行（EXEC_PARTY_PRESETS.md §7-1）。
#
# ⚠ もとはここに OptionButton を3つ並べていた（EXEC_PARTY_MEMBERS.md §3-5）。
#   専用画面ができたので、いまの3人を読むだけの行にして、差し替えはあちらへ渡す
#   （同じことをする場所を2つ作らない）。
# ⚠ .tscn を触らずコードで作り、StageList の手前に差し込む。
# ⚠ 再描画に await を持たせない（AGENTS.md）。remove_child() してから queue_free() する。
func _build_party_row() -> void:
	var parent: Node = stage_list.get_parent()

	# 作り直し。⚠ queue_free() だけだと、同じフレームに2本作ると行が二重に並ぶ。
	if _party_box != null and is_instance_valid(_party_box):
		parent.remove_child(_party_box)
		_party_box.queue_free()
		_party_box = null

	var members: Array = GameManager.get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[AdventureSelect] 編成が %d 件（%d のはず）" % [
			members.size(), GameStateKeys.PARTY_SLOT_COUNT
		])
		return

	_party_box = VBoxContainer.new()
	_party_box.name = "PartyBox"

	var header: Label = Label.new()
	header.name = "PartyHeader"
	header.text = tr("ui_adventure_party")
	_party_box.add_child(header)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PartySlots"

	var names: Label = Label.new()
	names.name = "PartyNames"
	names.size_flags_horizontal = 3
	var parts: Array[String] = []
	for character_id: Variant in members:
		var char_data: Dictionary = MasterDataLoader.get_character(str(character_id))
		parts.append(tr(str(char_data.get("name_key", str(character_id)))))
	names.text = " / ".join(parts)
	row.add_child(names)

	var edit_button: PrimaryButton = PrimaryButton.new()
	edit_button.name = "PartyEditButton"
	edit_button.text = "ui_nav_party_preset"
	edit_button.pressed.connect(_on_party_edit_pressed)
	row.add_child(edit_button)

	_party_box.add_child(row)

	parent.add_child(_party_box)
	# ステージ一覧の手前へ。⚠ add_child は末尾に付くので、必ず移動させる。
	parent.move_child(_party_box, stage_list.get_index())


# パーティ選択画面へ。⚠ 戻る先を渡す（入口が2つあるため。TransferKeys.RETURN_PATH）。
func _on_party_edit_pressed() -> void:
	SceneManager.change_scene_with_data(
		PARTY_PRESET_PATH,
		{TransferKeys.RETURN_PATH: ADVENTURE_SELECT_PATH}
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
	_build_debug_stage_list()


# 検証用ステージの別枠（EXEC_ENEMY_PARITY.md §9）。
#
# ⚠ 本番の "story" 列を書き換えないための仕組み。以前は stage_order.json の
#   "stage_1" を差し替えて検証していたが、戻し忘れると本編の1面が検証用のままになる。
# ⚠ 解放判定の連鎖に入れない。ここで作る行は常に解放で、story 側の
#   「前のステージをクリアしたか」に一切影響しない。
# ⚠ テストしたいこと1つにつきステージ1本。増やすときは stage_order.json の
#   "debug" 配列に1行足すだけ。
# ⚠ リリース前に、この関数ごとと "debug" の列を消す（宿題16）。
func _build_debug_stage_list() -> void:
	if not OS.is_debug_build():
		return
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_DEBUG)
	if order.is_empty():
		return

	var header: Label = Label.new()
	header.name = "DebugHeader"
	# 検証用なので tr() を通さない（リリース前に消すもの。ja.csv にキーを増やさない）
	header.text = "▼ 検証用（デバッグビルドのみ）"
	header.modulate = Color(0.7, 0.75, 0.8)
	stage_list.add_child(header)

	for stage_id: Variant in order:
		var sid: String = str(stage_id)
		var stage_data: Dictionary = MasterDataLoader.get_stage(sid)
		if stage_data.is_empty():
			push_error("[AdventureSelect] debug stage data not found: " + sid)
			continue
		_add_debug_stage_row(sid, stage_data)


# 検証用の1行。⚠ _add_stage_row() と共通化しない。
#   あちらは解放判定・クリア印・スタミナ表示を持つ本番の行で、混ぜると
#   本番の行に検証用の分岐が入る。こちらはリリース前に丸ごと消す。
func _add_debug_stage_row(stage_id: String, stage_data: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DebugStageRow_" + stage_id

	var name_label: Label = Label.new()
	name_label.text = tr(str(stage_data.get("name_key", stage_id)))

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = 3

	var button: PrimaryButton = PrimaryButton.new()
	button.text = "ui_adventure_challenge"
	button.pressed.connect(_on_debug_challenge_pressed.bind(stage_id))

	row.add_child(name_label)
	row.add_child(spacer)
	row.add_child(button)
	stage_list.add_child(row)


# 検証用ステージへ入る。
#
# ⚠ 解放判定もスタミナの残量確認もしない（常に入れる）。
# ⚠ STAGE_TYPE_TRAINING を渡す。story 以外は戦闘画面が
#   スタミナ消費・報酬・クリア記録を全部飛ばすので、検証がセーブを汚さない。
func _on_debug_challenge_pressed(stage_id: String) -> void:
	SceneManager.change_scene_with_data(
		BATTLE_PATH,
		{
			TransferKeys.STAGE_ID: stage_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_TRAINING,
		}
	)

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

	# 周回ボタン（段階14-f）。⚠ 踏破済みのフロアだけに出す。
	#   ⚠ 出すかどうかの判定は GameManager に聞く。ここで条件を書き直さない。
	var repeat_button: PrimaryButton = PrimaryButton.new()
	repeat_button.name = "RepeatButton"
	repeat_button.text = "ui_floor_repeat"
	repeat_button.visible = GameManager.is_floor_stage(stage_id) and GameManager.is_stage_cleared(stage_id)
	repeat_button.pressed.connect(_on_repeat_pressed.bind(stage_id))

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
	row.add_child(repeat_button)
	row.add_child(challenge_button)
	stage_list.add_child(row)

	# 解放判定（EXEC §4.2）
	var unlocked: bool = (index == 0) or GameManager.is_stage_cleared(order[index - 1])
	var cleared: bool = GameManager.is_stage_cleared(stage_id)

	# 進行中のフロアは「続きから」（段階14-c）。
	var in_progress: bool = GameManager.is_in_floor() and str(
		GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")
	) == stage_id
	if in_progress:
		challenge_button.text = "ui_floor_resume"

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

	# フロア形式（段階14-c）。⚠ 戦闘画面へ直行せず、マップ画面へ入る。
	# ⚠ すでに同じフロアの途中なら続きから。別のフロアに入っていたら断る
	#   （黙って捨てると、たいまつもレリックも持ち越しHPも消える）。
	if GameManager.is_floor_stage(stage_id):
		if GameManager.is_in_floor():
			var current_floor: String = str(GameManager.get_floor_run().get(
				GameStateKeys.FLOOR_RUN_FLOOR_ID, ""
			))
			if current_floor != stage_id:
				message_label.text = tr("ui_floor_other_in_progress")
				return
			SceneManager.change_scene(FLOOR_MAP_PATH)
			return
		if not GameManager.start_floor(stage_id):
			message_label.text = tr("ui_floor_start_failed")
			return
		SceneManager.change_scene(FLOOR_MAP_PATH)
		return

	# 遷移（EXEC §5.4）。PARTY_ID は渡さない
	SceneManager.change_scene_with_data(
		BATTLE_PATH,
		{
			TransferKeys.STAGE_ID: stage_id,
			TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
		}
	)

# 周回（段階14-f）。⚠ 内部で1周ぶん歩かせて結果だけ受け取る。
#
# ⚠ 断る理由は GameManager が返す。ここで条件を書き直さない。
# ⚠ 行を作り直す（クリア済みの印もスタミナも変わるため）。
func _on_repeat_pressed(stage_id: String) -> void:
	var reason: String = GameManager.get_floor_auto_reject_reason(stage_id)
	if reason != "":
		message_label.text = tr("ui_floor_repeat_reject_" + reason)
		return
	var result: Dictionary = GameManager.run_floor_auto(stage_id)
	var rewards: Dictionary = result.get(GameManager.AUTO_RUN_REWARDS, {})
	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	message_label.text = "%s  %s %d / %s %d / %s %d" % [
		tr("ui_floor_repeat_done"),
		tr("ui_res_gold"), int(rewards.get(GameStateKeys.REWARD_GOLD, 0)),
		tr("ui_floor_chest_count"), int(result.get(GameManager.AUTO_RUN_CHESTS, 0)),
		tr("ui_floor_repeat_gacha"), int(result.get(GameManager.AUTO_RUN_GACHA, 0)),
	]
	_rebuild_stage_list()


# ステージ一覧を作り直す。⚠ await を持たせない（AGENTS.md）。
func _rebuild_stage_list() -> void:
	for child in stage_list.get_children():
		stage_list.remove_child(child)
		child.queue_free()
	_stage_rows.clear()
	_build_stage_list()


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
