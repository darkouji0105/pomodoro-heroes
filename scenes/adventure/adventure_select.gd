# res://scenes/adventure/adventure_select.gd
# 依頼掲示板（⚠ ファイル名は冒険選択のまま）。AGENTS.md / EXEC_ADVENTURE_SELECT.md 準拠。
#
# ⚠⚠ 2026-09-27（回UI-組 掲示板・手本 QuestBoard・決定 `NAV-12`）：⚠ タブ：通常の依頼 ／ 高難度の依頼 ／ 検証用（⚠ デバッグビルドだけ・人間「⚠ 2あ」）。
#   ⚠ 通常＝物語の話（第◯話）＋練習場（⚠ 人間「⚠ 1あ」＝押すと今までどおり仮の画面）。
#   ⚠ クリアした話は「済」の判 ＋「周回」＋「受ける」（⚠ 人間「⚠ 4い」＝自分でもう一度戦える）。
#   ⚠ 解放前の話は薄くして「前の話を終えると」（⚠ ボタンを出さない）。
#   ⚠⚠ 新しく出るとき（受ける・周回・難ダンジョンに入る）は**出撃の準備**の画面を開く（2026-09-28・`party_preset_screen`）。
#     ⚠ 続きからは挟まない（⚠ ランの途中で編成は変えない）。
# ⚠⚠ 10-18（回UI-1018-6・web版の手本 `05_base_questboard.png`・決定 `NAV-35`）：⚠ **コルク板に留めた依頼の紙**にした。
#   ⚠ 紙を押すと**右の紙に詳しく**（⚠ 報酬・敵・出る人・スタミナ）＋「この依頼で出撃」。⚠ ボタンは紙の上から右へ移した。
#   ⚠ 紙の左上に種類の札（本編・練習・高難度・検証）。⚠ 日課などの新しい種類は作らない（⚠ 人間「ヤッパ日課はいい」）。
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

# ⚠ 紙の種類（⚠ 左上の札の色と字）。
const KIND_STORY: String = "story"
const KIND_TRAINING: String = "training"
const KIND_HARD: String = "hard"
const KIND_DEBUG: String = "debug"

const KEY_KIND: String = "kind"
const KEY_STAGE: String = "stage"
const KEY_DUNGEON: String = "dungeon"
const KEY_INDEX: String = "index"

# --- ノード参照 ---
@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body
@onready var board_stack: VBoxContainer = $Margin/Layout/Body/BoardStack
@onready var grid: GridContainer = $Margin/Layout/Body/BoardStack/Board/Scroll/Grid
@onready var message_label: Label = $Margin/Layout/MessageLabel

var _tabs: PaperTabs = null
var _tab: int = TAB_NORMAL
var _detail: PaperSheet = null
# ⚠ 紙の名前 -> 何の依頼か（⚠ 右の紙を組むため）。
var _entries: Dictionary = {}
var _selected: String = ""


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
	header.subtitle_key = "ui_quest_board_hint"
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

	_detail = PaperSheet.new()
	_detail.name = "QuestDetail"
	_detail.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	body.add_child(_detail)

	message_label.text = ""
	_rebuild()


func _on_tab_changed(index: int) -> void:
	_tab = index
	SceneManager.remember(TransferKeys.MEMORY_QUEST_TAB, _tab)
	message_label.text = ""
	_selected = ""
	_rebuild()


# 札を作り直す。⚠ await を持たせない（AGENTS.md）。remove_child() してから queue_free()。
func _rebuild() -> void:
	SlotActionPopover.close_in(self)
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_entries.clear()
	match _tab:
		TAB_HARD:
			_build_dungeon_cards()
		TAB_DEBUG:
			_build_debug_cards()
		_:
			_build_story_cards()
	if not _entries.has(_selected):
		_selected = _default_selection()
	_refresh_selection()
	_rebuild_detail()


# ⚠ 最初に選ぶ紙：⚠ 途中のランの依頼 → ⚠ 次に受ける話 → ⚠ 先頭。
func _default_selection() -> String:
	if _tab == TAB_NORMAL:
		var next: String = GameManager.get_next_story_stage()
		if _entries.has("StageCard_" + next):
			return "StageCard_" + next
	if _tab == TAB_HARD and GameManager.is_in_dungeon():
		var dungeon_id: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
		if _entries.has("DungeonCard_" + dungeon_id):
			return "DungeonCard_" + dungeon_id
	for child: Node in grid.get_children():
		return str(child.name)
	return ""


func _on_card_pressed(card_name: String) -> void:
	if card_name == _selected:
		return
	_selected = card_name
	message_label.text = ""
	_refresh_selection()
	_rebuild_detail()


func _refresh_selection() -> void:
	for child: Node in grid.get_children():
		var card: TiltedSheet = child as TiltedSheet
		if card != null:
			card.sheet.theme_type_variation = &"QuestPaperChosenPanel" if str(card.name) == _selected else &"QuestPaperPanel"


# --- 札の器（コルク板に留めた紙） -----------------------------------------

# 紙1枚：⚠ 左上に種類の札 ／ 題 ／ ひとこと ／ 点線 ／ 報酬 ／ 足（⚡・判）。⚠ 押すと右に詳しく。
func _make_card(index: int, card_name: String, entry: Dictionary, title: String, desc: String, reward: String, caption: String = "") -> Dictionary:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = card_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.sheet.show_corners = false
	card.sheet.theme_type_variation = &"QuestPaperPanel"
	card.sheet.draw.connect(_draw_pin.bind(card.sheet))
	var card_body: VBoxContainer = VBoxContainer.new()
	card_body.name = "Body"
	card_body.theme_type_variation = &"TightList"
	card.sheet.add_child(card_body)
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TagRow"
	card_body.add_child(top)
	top.add_child(_tag(str(entry.get(KEY_KIND, KIND_STORY))))
	if caption != "":
		var caption_label: Label = Label.new()
		caption_label.name = "CaptionLabel"
		caption_label.theme_type_variation = &"CaptionLabel"
		caption_label.text = caption
		top.add_child(caption_label)
	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.theme_type_variation = &"QuestCardTitleLabel"
	title_label.text = title
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_body.add_child(title_label)
	var desc_label: Label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.theme_type_variation = &"CaptionLabel"
	desc_label.text = desc
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.visible = desc != ""
	card_body.add_child(desc_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(spacer)
	card_body.add_child(HSeparator.new())
	if reward != "":
		var reward_label: Label = Label.new()
		reward_label.name = "RewardLabel"
		reward_label.theme_type_variation = &"SmallLabel"
		reward_label.text = tr("ui_quest_reward_line") % reward
		reward_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card_body.add_child(reward_label)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	card_body.add_child(foot)
	grid.add_child(card)
	_entries[card_name] = entry
	var _hit: Button = UiButton.attach_hit(card.sheet, _on_card_pressed.bind(card_name))
	return {"card": card, "foot": foot}


# ⚠ 紙の上の真ん中に赤い画鋲。
func _draw_pin(sheet: PaperSheet) -> void:
	var radius: float = float(get_theme_constant(&"pin", THEME_TYPE))
	var center: Vector2 = Vector2(sheet.size.x * 0.5, radius * 0.5)
	sheet.draw_circle(center + Vector2(1.0, 2.0), radius, get_theme_color(&"pin_shadow", THEME_TYPE))
	sheet.draw_circle(center, radius, get_theme_color(&"pin", THEME_TYPE))
	sheet.draw_circle(center - Vector2(radius, radius) * 0.3, radius * 0.35, get_theme_color(&"pin_light", THEME_TYPE))


func _tag(kind: String) -> Label:
	var tag: Label = Label.new()
	tag.name = "TagLabel"
	tag.theme_type_variation = StringName("QuestTag_" + kind)
	tag.text = tr("ui_quest_kind_" + kind)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return tag


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
	cost.theme_type_variation = &"SmallLabel"
	cost.text = str(Balance.adventure.stamina_cost_per_stage)
	cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(cost)


# ⚠ 大きい真鍮のボタン（⚠ 素の `Button`＝`UiButton` は木に入ると色を付け直すため）。
func _big_button(button_name: String, label_key: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = &"DeskBigButton"
	button.text = tr(label_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	return button


func _add_button(parent: Container, button_name: String, label_key: String, handler: Callable, variant: UiButton.Variant = UiButton.Variant.SECONDARY) -> UiButton:
	var button: UiButton = UiButton.create(variant, label_key)
	button.name = button_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	parent.add_child(button)
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
	var _parts: Dictionary = _make_card(order.size(), "TrainingCard", {KEY_KIND: KIND_TRAINING},
		tr("ui_adventure_training"), tr("ui_quest_training_desc"), "")


func _add_story_card(index: int, stage_id: String, stage_data: Dictionary) -> void:
	var unlocked: bool = _is_unlocked(stage_id)
	var desc: String = tr(_desc_key_of(stage_id)) if unlocked else ""
	var parts: Dictionary = _make_card(index, "StageCard_" + stage_id,
		{KEY_KIND: KIND_STORY, KEY_STAGE: stage_id, KEY_INDEX: index}, tr(str(stage_data.get("name_key", stage_id))), desc,
		_reward_text(stage_data) if unlocked else "", tr("ui_quest_episode") % (index + 1))
	var card: TiltedSheet = parts["card"]
	var foot: HBoxContainer = parts["foot"]
	# 解放判定（EXEC §4.2）。⚠ 解放前は薄くして「前の話を終えると」（⚠ 右の紙にもボタンを出さない）。
	if not unlocked:
		card.modulate.a = float(get_theme_constant(&"locked_alpha_pct", THEME_TYPE)) / 100.0
		var locked: Label = Label.new()
		locked.name = "LockedLabel"
		locked.theme_type_variation = &"CaptionLabel"
		locked.text = tr("ui_quest_locked")
		foot.add_child(locked)
		return
	_add_cost(foot)
	_add_gap(foot)
	if GameManager.is_stage_cleared(stage_id):
		var stamp: Stamp = Stamp.new()
		stamp.name = "ClearedStamp"
		stamp.shape = Stamp.Shape.CIRCLE
		stamp.label_key = "ui_quest_cleared"
		foot.add_child(stamp)


# ⚠ ひとこと（⚠ 無ければ空）。⚠ キーは `<name_key>_desc`。
func _desc_key_of(stage_id: String) -> String:
	return str(MasterDataLoader.get_stage(stage_id).get("name_key", stage_id)) + "_desc"


# ⚠ 報酬（⚠ クリアの報酬＝金と素材・品の先頭から `reward_items` 個まで）。
func _reward_text(stage_data: Dictionary) -> String:
	var rewards: Dictionary = stage_data.get("rewards", {})
	var parts: Array[String] = []
	var gold: int = int(rewards.get(GameStateKeys.REWARD_GOLD, 0))
	if gold > 0:
		parts.append(tr("ui_quest_reward_gold") % gold)
	var limit: int = get_theme_constant(&"reward_items", THEME_TYPE)
	for group: String in ["materials", "inventory"]:
		var items: Dictionary = rewards.get(group, {})
		for item_id: String in items:
			if parts.size() >= limit:
				return tr("ui_quest_reward_more") % tr("ui_quest_reward_sep").join(parts)
			parts.append(tr("ui_quest_reward_item") % [tr(GameManager.item_name_key(item_id)), int(items[item_id])])
	return tr("ui_quest_reward_sep").join(parts)


# ⚠ 敵（⚠ 出てくる敵の名前を1回ずつ・ボスは「（ボス）」）。
func _enemy_text(stage_data: Dictionary) -> String:
	var names: Array[String] = []
	var groups: Array = []
	for raw: Variant in stage_data.get("battle_pool", []):
		groups.append(raw)
	for raw: Variant in stage_data.get("waves", []):
		groups.append(raw)
	for raw: Variant in groups:
		for enemy: Variant in (raw as Dictionary).get("enemies", []):
			var enemy_name: String = tr(str(MasterDataLoader.get_enemy(str((enemy as Dictionary).get("enemy_type_id", ""))).get("name_key", "")))
			if not names.has(enemy_name):
				names.append(enemy_name)
	for enemy: Variant in (stage_data.get("boss", {}) as Dictionary).get("enemies", []):
		var boss: Dictionary = enemy as Dictionary
		var boss_name: String = tr(str(MasterDataLoader.get_enemy(str(boss.get("enemy_type_id", ""))).get("name_key", "")))
		if bool(boss.get("is_boss", false)):
			boss_name = tr("ui_quest_enemy_boss") % boss_name
		if not names.has(boss_name):
			names.append(boss_name)
	return tr("ui_quest_reward_sep").join(names)


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
		var name_key: String = str(dungeon.get("name_key", dungeon_id))
		var parts: Dictionary = _make_card(i, "DungeonCard_" + dungeon_id, {KEY_KIND: KIND_HARD, KEY_DUNGEON: dungeon_id},
			tr(name_key), tr(name_key + "_desc"), tr("ui_quest_reward_dungeon"))
		var foot: HBoxContainer = parts["foot"]
		foot.add_child(_ticket_label())


# ⚠ ノルマ札（2026-10-02・`EXEC_QUOTA_TICKET.md`・人間「⚠ 4あ」）：⚠ 「n / 3」・⚠ 10-07（人間「⚠ 足りないボタンは不足とは出さないで数字の色で」）＝足りなければ赤。
func _ticket_label() -> Label:
	var ticket: Label = Label.new()
	ticket.name = "QuotaTicketLabel"
	var enough: bool = GameManager.has_quota_ticket_for_entry()
	ticket.theme_type_variation = &"CaptionLabel" if enough else &"SmallErrorLabel"
	ticket.text = tr("ui_quota_ticket_count") % [GameManager.get_quota_ticket_count(), GameManager.get_quota_ticket_max()]
	ticket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ticket


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
		var _parts: Dictionary = _make_card(i, "DebugCard_" + stage_id, {KEY_KIND: KIND_DEBUG, KEY_STAGE: stage_id},
			tr(str(stage_data.get("name_key", stage_id))), stage_id, "")


# --- 右：詳しく ------------------------------------------------------------

func _rebuild_detail() -> void:
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	_detail.add_child(column)
	if not _entries.has(_selected):
		return
	var entry: Dictionary = _entries[_selected]
	var kind: String = str(entry.get(KEY_KIND, KIND_STORY))
	column.add_child(_tag(kind))
	var title: Label = Label.new()
	title.name = "DetailTitle"
	title.theme_type_variation = &"QuestDetailTitleLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var desc: Label = Label.new()
	desc.name = "DetailDesc"
	desc.theme_type_variation = &"CaptionLabel"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(desc)
	column.add_child(HSeparator.new())
	var actions: VBoxContainer = VBoxContainer.new()
	actions.name = "Actions"
	match kind:
		KIND_STORY:
			_fill_story_detail(entry, title, desc, column, actions)
		KIND_HARD:
			_fill_dungeon_detail(entry, title, desc, column, actions)
		KIND_TRAINING:
			title.text = tr("ui_adventure_training")
			desc.text = tr("ui_quest_training_desc")
			_add_button(actions, "TrainingButton", "ui_quest_go", _on_training_pressed, UiButton.Variant.PRIMARY)
		KIND_DEBUG:
			var stage_id: String = str(entry.get(KEY_STAGE, ""))
			title.text = tr(str(MasterDataLoader.get_stage(stage_id).get("name_key", stage_id)))
			desc.text = stage_id
			_add_field(column, "ui_quest_enemies", _enemy_text(MasterDataLoader.get_stage(stage_id)))
			_add_button(actions, "ChallengeButton", "ui_adventure_challenge", _on_debug_challenge_pressed.bind(stage_id), UiButton.Variant.PRIMARY)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(actions)
	var back: Button = UiButton.create_paper_choice("ui_quest_back_to_base")
	back.name = "BackToBaseButton"
	back.pressed.connect(_on_back_pressed)
	column.add_child(back)


func _add_field(column: VBoxContainer, caption_key: String, value: String) -> void:
	if value == "":
		return
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr(caption_key)
	column.add_child(caption)
	var label: Label = Label.new()
	label.theme_type_variation = &"QuestDetailValueLabel"
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)


# ⚠ 出る人（⚠ いまの編成）＋「詰所で替える」。
func _add_party(column: VBoxContainer) -> void:
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_quest_party")
	column.add_child(caption)
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "PartyLine"
	column.add_child(line)
	var face: int = get_theme_constant(&"face", THEME_TYPE)
	for raw: Variant in GameManager.get_party_members():
		if str(raw) != "":
			line.add_child(CharacterAvatar.create(str(raw), face))
	var change: Button = Button.new()
	change.name = "ChangePartyButton"
	change.theme_type_variation = &"DeskLinkButton"
	change.text = tr("ui_hq_change_party")
	change.focus_mode = Control.FOCUS_NONE
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	change.pressed.connect(_open_sortie.bind(_entry_stage(), _entry_dungeon()))
	line.add_child(change)


func _entry_stage() -> String:
	return str((_entries.get(_selected, {}) as Dictionary).get(KEY_STAGE, ""))


func _entry_dungeon() -> String:
	return str((_entries.get(_selected, {}) as Dictionary).get(KEY_DUNGEON, ""))


func _fill_story_detail(entry: Dictionary, title: Label, desc: Label, column: VBoxContainer, actions: VBoxContainer) -> void:
	var stage_id: String = str(entry.get(KEY_STAGE, ""))
	var stage_data: Dictionary = MasterDataLoader.get_stage(stage_id)
	title.text = "%s　%s" % [tr("ui_quest_episode") % (int(entry.get(KEY_INDEX, 0)) + 1), tr(str(stage_data.get("name_key", stage_id)))]
	if not _is_unlocked(stage_id):
		desc.text = tr("ui_quest_locked")
		return
	desc.text = tr(_desc_key_of(stage_id))
	_add_field(column, "ui_quest_reward", _reward_text(stage_data))
	_add_field(column, "ui_quest_enemies", _enemy_text(stage_data))
	_add_party(column)
	var stamina: Label = Label.new()
	stamina.name = "StaminaLabel"
	stamina.theme_type_variation = &"CaptionLabel"
	stamina.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina.text = tr("ui_hq_stamina_note") % [int(Balance.adventure.stamina_cost_per_stage), GameManager.get_stamina()]
	actions.add_child(stamina)
	# 進行中のフロアは「続きから」（段階14-c）。⚠ 出撃の準備は通さない（⚠ ランの途中で編成は変えない）。
	var in_progress: bool = GameManager.is_in_floor() and str(
		GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")
	) == stage_id
	if in_progress:
		_add_button(actions, "ChallengeButton", "ui_floor_resume", _on_resume_floor_pressed, UiButton.Variant.PRIMARY)
		return
	actions.add_child(_big_button("ChallengeButton", "ui_quest_take_this", _open_sortie.bind(stage_id, "")))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SubActions"
	row.theme_type_variation = &"ButtonRow"
	actions.add_child(row)
	# 周回（段階14-f）。⚠ 踏破済みのフロアだけ。⚠ 出すかどうかの判定は GameManager に聞く。
	# ⚠ 周回はその場で回す（⚠ 2026-09-28・人間「⚠ 周回の時は編成画面はいらない」＝出撃の準備を通さない）。
	if GameManager.is_floor_stage(stage_id) and GameManager.is_stage_cleared(stage_id):
		_add_button(row, "RepeatButton", "ui_floor_repeat", _on_repeat_pressed.bind(stage_id))
	# 「すぐ出撃」（2026-10-06・人間「⚠ ３はどっちも行う」）：⚠ 準備の画面を開いて、その「出撃する」を通す（⚠ 判定を2本にしない）。
	_add_button(row, "QuickSortieButton", "ui_quest_quick_go", _open_sortie.bind(stage_id, "", true))


func _fill_dungeon_detail(entry: Dictionary, title: Label, desc: Label, column: VBoxContainer, actions: VBoxContainer) -> void:
	var dungeon_id: String = str(entry.get(KEY_DUNGEON, ""))
	var name_key: String = str(MasterDataLoader.get_dungeon(dungeon_id).get("name_key", dungeon_id))
	title.text = tr(name_key)
	desc.text = tr(name_key + "_desc")
	_add_field(column, "ui_quest_reward", tr("ui_quest_reward_dungeon"))
	_add_party(column)
	# ⚠ いま入っているランと同じダンジョンなら「続きから」（⚠ 出撃届は挟まない）。
	var in_progress: bool = GameManager.is_in_dungeon() and str(
		GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")
	) == dungeon_id
	if in_progress:
		_add_button(actions, "DungeonButton", "ui_dungeon_resume", _on_resume_dungeon_pressed, UiButton.Variant.PRIMARY)
		return
	var ticket: Label = _ticket_label()
	ticket.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(ticket)
	# ⚠ 2026-09-28（人間「⚠ 4あ」）：⚠ 難ダンジョンも出撃の準備を通す。
	# ⚠ 10-07（人間「⚠ 同じ作りで」）：⚠ 札が足りなくても押せる＝押すと札の入手先の窓（`_open_sortie()` の入口）。
	actions.add_child(_big_button("DungeonButton", "ui_quest_take_this", _open_sortie.bind("", dungeon_id)))
	_add_button(actions, "QuickSortieButton", "ui_quest_quick_go", _open_sortie.bind("", dungeon_id, true))


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
		# ⚠ 10-12（100ループのテストプレイ）：⚠ スタミナ不足は1行だけだと、ポーションを持っていても気づけない。
		#   ⚠ 出撃する（`party_preset_screen.gd` `_on_sortie_pressed()`）と同じく入手先の窓も出す（`NAV-19`）。
		if reason == "stamina":
			var _shown: bool = ItemSourceWindow.open_if_short(self, GameStateKeys.STAMINA, int(Balance.adventure.stamina_cost_per_stage))
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
