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

# 編成の枠を包む箱。作り直すときに丸ごと外す（EXEC_PARTY_MEMBERS.md）。
var _party_box: VBoxContainer = null

# 編成の候補（character_id の配列）。⚠ OptionButton の項目番号からIDを引くための表。
#   項目番号をそのまま character_id の代わりに使わないこと。デバッグビルドかどうかで
#   候補の件数が変わるため、本番ビルドで別のキャラが選ばれる。
var _party_candidates: Array[String] = []

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

# 編成の3枠（EXEC_PARTY_MEMBERS.md §3-5）。
#
# ⚠ .tscn を触らずコードで作り、StageList の手前に差し込む。
# ⚠ モーダルを書かないこと（AGENTS.md の実例：モーダルの検証で1タスク溶かしている）。
#   OptionButton が一覧のポップアップを内蔵している。
# ⚠ 再描画に await を持たせない（AGENTS.md）。remove_child() してから queue_free() する。
#   交換が起きると押した枠以外も変わるので、3つとも作り直す。
func _build_party_row() -> void:
	var parent: Node = stage_list.get_parent()

	# 作り直し。⚠ queue_free() だけだと、同じフレームに2本作ると行が二重に並ぶ。
	if _party_box != null and is_instance_valid(_party_box):
		parent.remove_child(_party_box)
		_party_box.queue_free()
		_party_box = null

	_party_candidates = _collect_party_candidates()
	if _party_candidates.is_empty():
		push_error("[AdventureSelect] 編成の候補が0件（characters.json が読めていない）")
		return

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

	var slots: HBoxContainer = HBoxContainer.new()
	slots.name = "PartySlots"
	for slot_index: int in range(GameStateKeys.PARTY_SLOT_COUNT):
		slots.add_child(_make_party_slot(slot_index, str(members[slot_index])))
	_party_box.add_child(slots)

	parent.add_child(_party_box)
	# ステージ一覧の手前へ。⚠ add_child は末尾に付くので、必ず移動させる。
	parent.move_child(_party_box, stage_list.get_index())


# 枠1つぶんの OptionButton。
func _make_party_slot(slot_index: int, current_id: String) -> OptionButton:
	var picker: OptionButton = OptionButton.new()
	picker.name = "PartySlot_%d" % slot_index
	picker.size_flags_horizontal = 3

	for i: int in range(_party_candidates.size()):
		var character_id: String = _party_candidates[i]
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		# 名前は翻訳表から引く（AGENTS.md：日本語をコードに書かない）。
		picker.add_item(tr(str(char_data.get("name_key", character_id))))
		if character_id == current_id:
			# ⚠ select() は item_selected を出さない。ここを set_pressed 相当の
			#   「出す」書き方に変えると、行を作るたびにハンドラが走り、
			#   ハンドラが行を作り直すので無限に再入して固まる。
			picker.select(i)

	# ⚠ 接続は項目を入れ終わってから。先に繋ぐと add_item / select で発火しうる。
	picker.item_selected.connect(_on_party_slot_selected.bind(slot_index))
	return picker


# 編成の候補。並び順は characters.json の記述順のまま。
#
# ⚠ 検証用の3体はデバッグビルドでだけ出す（検証用ステージの「▼ 検証用」と同じ型）。
#   これで parties.json を書き換えて再起動する運用が要らなくなる。
# ⚠ リリース前にこの分岐を消す（宿題16）。編成の行そのものは残す。
# ⚠ 「所持しているキャラだけ」の概念はまだ無い。将来ここで絞る。
func _collect_party_candidates() -> Array[String]:
	var result: Array[String] = []
	var show_debug: bool = OS.is_debug_build()
	for character_id: Variant in MasterDataLoader.get_all_characters():
		var id: String = str(character_id)
		if not show_debug and id.begins_with("char_debug_"):
			continue
		result.append(id)
	return result


# 枠を選び直した。
#
# ⚠ item_index をそのまま character_id に使わないこと（_party_candidates の注記）。
# ⚠ 押した枠以外も変わりうる（同じキャラが別の枠に居ると交換になる）。3つとも作り直す。
# ⚠ 自分を含む箱を作り直すが、queue_free() はフレーム末まで遅延するので、
#   このハンドラが返るまでノードは生きている。await を挟まないこと。
func _on_party_slot_selected(item_index: int, slot_index: int) -> void:
	if item_index < 0 or item_index >= _party_candidates.size():
		push_error("[AdventureSelect] 編成の候補の番号が範囲外: %d" % item_index)
		return
	if not GameManager.set_party_member(slot_index, _party_candidates[item_index]):
		# 失敗の理由は GameManager 側が push_error 済み。画面は今の状態に戻す。
		_build_party_row()
		return
	_build_party_row()


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
