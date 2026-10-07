# res://scenes/adventure/adventure_select.gd
# 依頼掲示板（⚠ ファイル名は冒険選択のまま）。AGENTS.md / EXEC_ADVENTURE_SELECT.md 準拠。
#
# ⚠⚠ 2026-09-27（回UI-組 掲示板・手本 QuestBoard・決定 `NAV-12`）：⚠ **作り替えた**。
#   ⚠ タブ：通常の依頼 ／ 高難度の依頼 ／ 検証用（⚠ デバッグビルドだけ・人間「⚠ 2あ」）。
#   ⚠ 札は傾いた紙を 3 × 2。⚠ 通常＝物語の話（第◯話）＋練習場（⚠ 人間「⚠ 1あ」＝押すと今までどおり仮の画面）。
#   ⚠ クリアした話は「済」の判 ＋「周回」＋「受ける」（⚠ 人間「⚠ 4い」＝自分でもう一度戦える）。
#   ⚠ 解放前の話は薄くして「前の話を終えると」（⚠ ボタンを出さない）。
#   ⚠ 高難度＝難ダンジョンごとに札（⚠ いまは1本。⚠ 「潜る準備」の画面は決定49 の回）。
#   ⚠⚠ 編成の行は消した（⚠ 人間「⚠ 3い」）。⚠⚠ 新しく出るとき（受ける・周回・難ダンジョンに入る）は**出撃の準備**の画面を開く
#     （2026-09-28・`party_preset_screen`・モック `docs/pomodoro-heroes-ui-docs/barracks/`）。⚠ 前の仮の吹き出しはやめた。
#     ⚠ 続きからは挟まない（⚠ ランの途中で編成は変えない）。
# ステージ一覧は stage_order.json 順、解放判定は GameManager.is_stage_cleared()。
# スタミナの判定はこの画面で行う（戦闘画面では見ない）。

extends Control

# --- 定数 ---
# EXEC §5-7: パスは const で持つ（base_screen.gd の BASE_PATH と同じ流儀）
const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const PARTY_PRESET_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
# 難ダンジョン（段階17-d）。⚠ フロアのマップとは別の画面（器も仕様も別＝台帳 §7）。
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const THEME_TYPE: StringName = &"QuestBoard"

const TAB_NORMAL: int = 0
const TAB_HARD: int = 1
const TAB_DEBUG: int = 2

# --- ノード参照 ---
@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var board_stack: VBoxContainer = $Margin/Layout/BoardStack
@onready var grid: GridContainer = $Margin/Layout/BoardStack/Board/Grid
@onready var message_label: Label = $Margin/Layout/MessageLabel

var _tabs: PaperTabs = null
var _tab: int = TAB_NORMAL


func _ready() -> void:
	# ⚠ 10-07：⚠ 入手先の窓から戻ってきたときの姿を預ける（`SceneManager.set_return_data_provider()`）。
	SceneManager.set_return_data_provider(_source_return_data)
	# 拠点から渡される transfer data を 1 回だけ消費して捨てる（EXEC §5-1）。
	# 呼ばないと次の遷移に前回のデータが残るため必須。
	# ⚠ 10-06（`NAV-18`）：⚠ 寄り道（ショップ）から戻ったときは、そのときのタブで開く。
	var data: Dictionary = SceneManager.consume_transfer_data()
	# ⚠ 10-07（H）：⚠ 渡されなければ前に開いていたタブ。
	_tab = int(data.get(TransferKeys.QUEST_TAB, SceneManager.recall(TransferKeys.MEMORY_QUEST_TAB, TAB_NORMAL)))
	header.back_pressed.connect(_on_back_pressed)
	# ⚠ 10-06（`NAV-6`）：⚠ 施設の帯に掲示板を足した＝掲示板にも帯を敷く。
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.BOARD)

	_tabs = PaperTabs.new()
	_tabs.name = "Tabs"
	var keys: Array[String] = ["ui_quest_tab_normal", "ui_quest_tab_hard"]
	# ⚠ 検証用のタブはデバッグビルドだけ（⚠ リリース前に "debug" の列ごと消す＝宿題16）。
	if OS.is_debug_build() and not MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_DEBUG).is_empty():
		keys.append("ui_quest_tab_debug")
	if _tab < 0 or _tab >= keys.size():
		_tab = TAB_NORMAL
	_tabs.set_tabs(keys, _tab)
	_tabs.tab_changed.connect(_on_tab_changed)
	board_stack.add_child(_tabs)
	board_stack.move_child(_tabs, 0)

	message_label.text = ""
	_rebuild()


func _on_tab_changed(index: int) -> void:
	_tab = index
	SceneManager.remember(TransferKeys.MEMORY_QUEST_TAB, _tab)
	message_label.text = ""
	_rebuild()


# 札を作り直す。⚠ await を持たせない（AGENTS.md）。remove_child() してから queue_free()。
func _rebuild() -> void:
	SlotActionPopover.close_in(self)
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	match _tab:
		TAB_HARD:
			_build_dungeon_cards()
		TAB_DEBUG:
			_build_debug_cards()
		_:
			_build_story_cards()


# --- 札の器 -----------------------------------------------------------

# 札1枚：上に小さな見出し（第◯話）と題 ／ 下に足（判・スタミナ・ボタン）。⚠ 足は呼ぶ側が埋める。
func _make_card(index: int, card_name: String, caption: String, title: String) -> Dictionary:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	card.sheet.add_child(body)
	var caption_label: Label = Label.new()
	caption_label.theme_type_variation = &"CaptionLabel"
	caption_label.text = caption
	body.add_child(caption_label)
	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.theme_type_variation = &"SheetHeadingLabel"
	title_label.text = title
	body.add_child(title_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(spacer)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	body.add_child(foot)
	grid.add_child(card)
	return {"card": card, "foot": foot}


func _add_gap(foot: HBoxContainer) -> void:
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)


# 「⚡ 5」。⚠ 数字だけなので tr() を通さない（AGENTS.md）。
func _add_cost(foot: HBoxContainer) -> void:
	var side: float = float(get_theme_constant(&"stamina_icon", THEME_TYPE))
	var icon: TextureRect = TextureRect.new()
	icon.texture = IconTextures.for_resource(GameStateKeys.STAMINA)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(side, side)
	icon.self_modulate = get_theme_color(&"stamina_icon", THEME_TYPE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(icon)
	var cost: Label = Label.new()
	cost.name = "CostLabel"
	cost.text = str(Balance.adventure.stamina_cost_per_stage)
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(cost)


func _add_button(foot: HBoxContainer, button_name: String, label_key: String, handler: Callable) -> UiButton:
	var button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, label_key)
	button.name = button_name
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.pressed.connect(handler)
	foot.add_child(button)
	return button


# --- 通常の依頼（物語の話 ＋ 練習場） ------------------------------------

func _build_story_cards() -> void:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	for i: int in range(order.size()):
		var stage_id: String = str(order[i])
		var stage_data: Dictionary = MasterDataLoader.get_stage(stage_id)
		if stage_data.is_empty():
			push_error("[AdventureSelect] stage data not found for order entry: " + stage_id)
			continue
		_add_story_card(i, stage_id, stage_data)

	# 練習場（⚠ 人間「⚠ 1あ」＝トレーニングは未実装なので今までどおり仮の画面へ）。
	var parts: Dictionary = _make_card(order.size(), "TrainingCard", tr("ui_quest_training_caption"), tr("ui_adventure_training"))
	var foot: HBoxContainer = parts["foot"]
	_add_gap(foot)
	_add_button(foot, "TrainingButton", "ui_quest_go", _on_training_pressed)


func _add_story_card(index: int, stage_id: String, stage_data: Dictionary) -> void:
	var parts: Dictionary = _make_card(
		index, "StageCard_" + stage_id, tr("ui_quest_episode") % (index + 1),
		tr(str(stage_data.get("name_key", stage_id)))
	)
	var card: TiltedSheet = parts["card"]
	var foot: HBoxContainer = parts["foot"]
	var cleared: bool = GameManager.is_stage_cleared(stage_id)

	# 解放判定（EXEC §4.2）。⚠ 解放前は薄くしてボタンを出さない（⚠ 理由を札に書く）。
	if not _is_unlocked(stage_id):
		card.modulate.a = float(get_theme_constant(&"locked_alpha_pct", THEME_TYPE)) / 100.0
		var locked: Label = Label.new()
		locked.name = "LockedLabel"
		locked.theme_type_variation = &"CaptionLabel"
		locked.text = tr("ui_quest_locked")
		foot.add_child(locked)
		return

	if cleared:
		var stamp: Stamp = Stamp.new()
		stamp.name = "ClearedStamp"
		stamp.shape = Stamp.Shape.CIRCLE
		stamp.label_key = "ui_quest_cleared"
		foot.add_child(stamp)
	_add_gap(foot)
	_add_cost(foot)
	# ⚠ 10-06：⚠ ボタンは下の段（⚠ 「すぐ出撃」を足したら1段に入らず、掲示板ごと画面の左へはみ出した＝撮った絵）。
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_END
	foot.get_parent().add_child(actions)
	foot = actions

	# 周回（段階14-f）。⚠ 踏破済みのフロアだけ。⚠ 出すかどうかの判定は GameManager に聞く。
	# ⚠ 周回はその場で回す（⚠ 2026-09-28・人間「⚠ 周回の時は編成画面はいらない」＝出撃の準備を通さない）。
	if GameManager.is_floor_stage(stage_id) and cleared:
		_add_button(foot, "RepeatButton", "ui_floor_repeat", _on_repeat_pressed.bind(stage_id))

	# 進行中のフロアは「続きから」（段階14-c）。⚠ 出撃の準備は通さない（⚠ ランの途中で編成は変えない）。
	var in_progress: bool = GameManager.is_in_floor() and str(
		GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")
	) == stage_id
	if in_progress:
		_add_button(foot, "ChallengeButton", "ui_floor_resume", _on_resume_floor_pressed)
	else:
		_add_button(foot, "ChallengeButton", "ui_quest_take", _open_sortie.bind(stage_id, ""))
		_add_quick_button(foot, stage_id, "")


# --- 高難度の依頼（難ダンジョンごとに札） --------------------------------

# ⚠ stage_order.json に混ぜない。⚠ ダンジョンは stages.json に1行も無く、
#   解放の連鎖（前のステージをクリアしたか）にも入らない（台帳 §7）。
# ⚠ 一覧は MasterDataLoader.get_all_dungeon_ids() の1本。⚠ IDを名指ししない。
# ⚠ 入るコストは**ノルマ札**（2026-10-02・決定11 を覆した・`EXEC_QUOTA_TICKET.md`）。⚠ 判定は GameManager の口
#   （`has_quota_ticket_for_entry()`）・⚠ 使うのは出撃の準備（`enter_dungeon_with_ticket()`）。⚠ ここで数えない。
func _build_dungeon_cards() -> void:
	var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
	for i: int in range(dungeon_ids.size()):
		var dungeon_id: String = dungeon_ids[i]
		var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
		var parts: Dictionary = _make_card(
			i, "DungeonCard_" + dungeon_id, tr("ui_dungeon_section"), tr(str(dungeon.get("name_key", dungeon_id)))
		)
		var foot: HBoxContainer = parts["foot"]
		_add_gap(foot)
		# ⚠ いま入っているランと同じダンジョンなら「続きから」（⚠ 出撃届は挟まない）。
		var in_progress: bool = GameManager.is_in_dungeon() and str(
			GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")
		) == dungeon_id
		if in_progress:
			_add_button(foot, "DungeonButton", "ui_dungeon_resume", _on_resume_dungeon_pressed)
		else:
			# ⚠ ノルマ札（2026-10-02・`EXEC_QUOTA_TICKET.md`・人間「⚠ 4あ」）：⚠ 「n / 3」・⚠ 足りなければ押せない。
			var ticket: Label = Label.new()
			ticket.name = "QuotaTicketLabel"
			var enough: bool = GameManager.has_quota_ticket_for_entry()
			ticket.theme_type_variation = &"CaptionLabel" if enough else &"SmallErrorLabel"
			# ⚠ 10-07（人間「⚠ 足りないボタンは不足とは出さないで数字の色で」）：⚠ 足りなくても「n / m」＝数字の色（赤）で見せる。
			ticket.text = tr("ui_quota_ticket_count") % [GameManager.get_quota_ticket_count(), GameManager.get_quota_ticket_max()]
			ticket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			foot.add_child(ticket)
			foot.move_child(ticket, 0)
			# ⚠ 2026-09-28（人間「⚠ 4あ」）：⚠ 難ダンジョンも出撃の準備を通す。
			_add_button(foot, "DungeonButton", "ui_quest_take", _open_sortie.bind("", dungeon_id))
			# ⚠ 10-07（人間「⚠ 同じ作りで」）：⚠ 札が足りなくても押せる＝押すと札の入手先の窓（`_open_sortie()` の入口）。
			#   ⚠ 前は押せず、横に「ショップで買う」を出していた。
			_add_quick_button(foot, "", dungeon_id)


# 「すぐ出撃」（2026-10-06・人間「⚠ ３はどっちも行う」）：⚠ 札の上で出撃まで済む（⚠ 「受ける」→ 右下の「出撃する」が約900px）。
#   ⚠ 出撃の手続きは出撃の準備の口のまま（⚠ 準備の画面を開いて、その「出撃する」を通す＝判定を2本にしない）。
func _add_quick_button(foot: HBoxContainer, stage_id: String, dungeon_id: String) -> void:
	var quick: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_quest_quick_go")
	quick.name = "QuickSortieButton"
	quick.size_flags_vertical = Control.SIZE_SHRINK_END
	quick.pressed.connect(_open_sortie.bind(stage_id, dungeon_id, true))
	foot.add_child(quick)


# 出撃の準備へ（2026-09-28・`party_preset_screen`）。⚠ 入る判定と手続きは向こうが持つ（⚠ ここに2本目を書かない）。
func _open_sortie(stage_id: String, dungeon_id: String, auto_go: bool = false) -> void:
	# ⚠ 難ダンジョンに新しく入るのに札が足りなければ、札の入手先の窓（⚠ 戻ると高難度のタブ）。
	if dungeon_id != "" and not GameManager.is_in_dungeon() and ItemSourceWindow.open_if_short(
			self, GameStateKeys.ITEM_QUOTA_TICKET, GameManager.get_quota_tickets_per_entry(), {TransferKeys.QUEST_TAB: _tab}):
		return
	SceneManager.change_scene_with_data(PARTY_PRESET_PATH, {
		TransferKeys.SORTIE_STAGE_ID: stage_id,
		TransferKeys.SORTIE_DUNGEON_ID: dungeon_id,
		TransferKeys.RETURN_PATH: ADVENTURE_SELECT_PATH,
		TransferKeys.SORTIE_AUTO_GO: auto_go,
	})


# 周回（段階14-f）。⚠ 内部で1周ぶん歩かせて結果だけ受け取る。
# ⚠ 断る理由は GameManager が返す。ここで条件を書き直さない。
# ⚠ 札を作り直す（クリア済みの印もスタミナも変わるため）。
func _on_repeat_pressed(stage_id: String) -> void:
	var reason: String = GameManager.get_floor_auto_reject_reason(stage_id)
	if reason != "":
		message_label.text = tr("ui_floor_repeat_reject_" + reason)
		return
	var result: Dictionary = GameManager.run_floor_auto(stage_id)
	var rewards: Dictionary = result.get(GameManager.AUTO_RUN_REWARDS, {})
	_rebuild()
	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	message_label.text = "%s  %s %d / %s %d / %s %d" % [
		tr("ui_floor_repeat_done"),
		tr("ui_res_gold"), int(rewards.get(GameStateKeys.REWARD_GOLD, 0)),
		tr("ui_floor_chest_count"), int(result.get(GameManager.AUTO_RUN_CHESTS, 0)),
		tr("ui_floor_repeat_gacha"), int(result.get(GameManager.AUTO_RUN_GACHA, 0)),
	]


# 続きから（⚠ 出撃の準備は通さない）。
func _on_resume_floor_pressed() -> void:
	SceneManager.change_scene(FLOOR_MAP_PATH)


func _on_resume_dungeon_pressed() -> void:
	SceneManager.change_scene(DUNGEON_MAP_PATH)


# --- 検証用（デバッグビルドだけ・人間「⚠ 2あ」） ---------------------------

# ⚠ 本番の "story" 列を書き換えないための仕組み（EXEC_ENEMY_PARITY.md §9）。
# ⚠ 解放判定の連鎖に入れない。ここで作る札は常に解放で、story 側に一切影響しない。
# ⚠ 増やすときは stage_order.json の "debug" 配列に1行足すだけ。
# ⚠ 出撃届は挟まない（⚠ 検証の手数を増やさない）。
# ⚠ リリース前に、この関数ごとと "debug" の列を消す（宿題16）。
func _build_debug_cards() -> void:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_DEBUG)
	for i: int in range(order.size()):
		var stage_id: String = str(order[i])
		var stage_data: Dictionary = MasterDataLoader.get_stage(stage_id)
		if stage_data.is_empty():
			push_error("[AdventureSelect] debug stage data not found: " + stage_id)
			continue
		# 検証用なので見出しは tr() を通さない（リリース前に消すもの。ja.csv にキーを増やさない）
		var parts: Dictionary = _make_card(i, "DebugCard_" + stage_id, stage_id, tr(str(stage_data.get("name_key", stage_id))))
		var foot: HBoxContainer = parts["foot"]
		_add_gap(foot)
		_add_button(foot, "ChallengeButton", "ui_adventure_challenge", _on_debug_challenge_pressed.bind(stage_id))


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


# ⚠ 2026-09-28：⚠ 出撃の手続き（⚠ 受ける・周回・難ダンジョンに入る）と仮の出撃届の吹き出しは、
#   ⚠ 出撃の準備（`party_preset_screen`）へ移した（⚠ モック `docs/pomodoro-heroes-ui-docs/barracks/`）。


func _on_training_pressed() -> void:
	# トレーニングは未実装なので placeholder へ（EXEC §5-7・人間「⚠ 1あ」）
	SceneManager.change_scene_with_data(
		PLACEHOLDER_PATH,
		{TransferKeys.SCREEN_ID: GameStateKeys.SCREEN_ADVENTURE_SELECT}
	)


func _on_back_pressed() -> void:
	# 履歴に依存せず明示的に拠点へ（EXEC §5-7 / base_screen.gd と同じ）
	# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓から寄り道で来たなら、窓を開いた画面へ。
	SceneManager.go_back_or(BASE_PATH)


# --- ヘルパー ---

# 解放判定。stage_order の index 関係のみを使う（EXEC §4.2）。
# ステージ ID から数字を切り出さない（PRE_PLAN §4.3）。
# ⚠ 10-06：⚠ 判定は GameManager へ移した（⚠ 入手先の窓も同じものを使う）。
func _is_unlocked(stage_id: String) -> bool:
	if not (stage_id in MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)):
		push_error("[AdventureSelect] stage_id not in order: " + stage_id)
		return false
	return GameManager.is_story_stage_unlocked(stage_id)


# 入手先の窓から戻ってきたときの姿（⚠ 同じタブ）。
func _source_return_data() -> Dictionary:
	return {TransferKeys.QUEST_TAB: _tab}
