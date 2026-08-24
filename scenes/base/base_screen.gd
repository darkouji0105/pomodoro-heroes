# res://scenes/base/base_screen.gd
# 拠点画面（下部：リソース表示と遷移ボタン）の実装
# AGENTS.md 準拠。
# オートセーブ未実装の間は SaveButton / BackToTitleButton を残している。

extends Control

# 定数
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TITLE_PATH: String = "res://scenes/title/title_screen.tscn"
const PARTY_PRESET_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"

# シーンリソース（ PackedScene ）
const RESOURCE_DISPLAY_SCENE: PackedScene = preload("res://scenes/ui/components/resource_display.tscn")

const SCREEN_SCENES: Dictionary = {
	GameStateKeys.SCREEN_ADVENTURE_SELECT: "res://scenes/adventure/adventure_select.tscn",
	GameStateKeys.SCREEN_GUILD: "res://scenes/guild/guild_screen.tscn",
	GameStateKeys.SCREEN_POMODORO: "res://scenes/pomodoro/pomodoro.tscn",
	GameStateKeys.SCREEN_SETTINGS: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_SCENARIO: PLACEHOLDER_PATH,
}

# ノード参照
@onready var gold_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/GoldEntry/Value
@onready var stamina_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/StaminaEntry/Value
@onready var potion_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/Value
@onready var potion_use_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/UseButton
# ⚠ GridContainer（8列2段）を ScrollContainer に入れて、ResourceRow の外に出してある。
#
# ⚠ 素材が3件から12件に増えた回で HBoxContainer → GridContainer 4列に変えた
#   （EXEC_MATERIAL_TIERS.md §12-3）。⚠ それでも足りなかった：16件・4桁になると
#   4列でも最小幅 564 になり、ResourceRow 全体が 1556（画面幅 1280）まで膨らんで、
#   下段が丸ごと左右にはみ出した（2026-08-23に実測）。
# ⚠ ScrollContainer に入れると最小幅が 0 になるので、⚠ 素材が増えても桁が増えても
#   二度とはみ出さない。⚠ この箱から出さないこと。
# ⚠ 数字は `-- scenario=layout` で取れる。器を足したときはあれを回すこと。
@onready var materials_display: GridContainer = $Layout/BottomArea/BottomLayout/MaterialsScroll/MaterialsDisplay
@onready var chest_badge: Button = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge
@onready var chest_count_label: Label = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge/ChestCountLabel

@onready var save_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/SaveButton
@onready var back_to_title_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/BackToTitleButton

@onready var adventure_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/AdventureButton
@onready var guild_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/GuildButton
@onready var pomodoro_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/PomodoroButton
@onready var settings_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/SettingsButton
@onready var scenario_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/ScenarioButton

# 内部状態
var _material_entries: Dictionary = {} # material_id -> HBoxContainer(MaterialEntry)
var _navigation_buttons: Dictionary = {} # screen_id -> PrimaryButton

func _ready() -> void:
	# GameManager の状態を取得
	var state: Dictionary = GameManager.get_state()

	_init_resource_displays(state)
	_init_materials(state)
	_init_navigation_buttons()
	_init_chest_badge()
	_connect_signals()
	_show_arrival_rewards()

func _init_resource_displays(state: Dictionary) -> void:
	# ゴールド
	var gold: int = int(state.get(GameStateKeys.GOLD, 0))
	gold_value.set_value(gold)

	# スタミナ
	var stamina_data: Dictionary = state.get(GameStateKeys.STAMINA, {})
	var current_stamina: int = int(stamina_data.get(GameStateKeys.STAMINA_CURRENT, 0))
	var max_stamina: int = int(stamina_data.get(GameStateKeys.STAMINA_MAX, 0))
	stamina_value.set_value_with_max(current_stamina, max_stamina)
	potion_value.set_value(GameManager.get_stamina_potion_count())
	potion_use_button.disabled = GameManager.get_stamina_potion_count() <= 0

func _init_materials(state: Dictionary) -> void:
	var materials: Dictionary = state.get(GameStateKeys.MATERIALS, {})
	for mat_id: String in materials.keys():
		# ⚠ 0 の素材は出さない。段階が4つになって12件並ぶようになり、
		#   序盤は9件が 0 のまま場所だけ取っていた（EXEC_MATERIAL_TIERS.md §12-3）。
		#   手に入った時点で _on_material_changed() が作る。
		if int(materials[mat_id]) <= 0:
			continue
		_create_material_entry(mat_id, int(materials[mat_id]))

func _init_navigation_buttons() -> void:
	_navigation_buttons = {
		GameStateKeys.SCREEN_ADVENTURE_SELECT: adventure_button,
		GameStateKeys.SCREEN_GUILD: guild_button,
		GameStateKeys.SCREEN_POMODORO: pomodoro_button,
		GameStateKeys.SCREEN_SETTINGS: settings_button,
		GameStateKeys.SCREEN_SCENARIO: scenario_button,
	}

	for screen_id: String in _navigation_buttons:
		var btn: PrimaryButton = _navigation_buttons[screen_id]
		# 解放状態の反映
		btn.visible = GameManager.is_screen_unlocked(screen_id)
		# 遷移イベント接続
		btn.pressed.connect(_go_to_screen.bind(screen_id))

	_add_party_preset_button()

# パーティ選択画面への入口（EXEC_PARTY_PRESETS.md §7-2）。
#
# ⚠ 人間の決定：切り替えは戦闘前でも拠点でもできる。画面は1つで、入口が2つ
#   （冒険選択にもある）。⚠ 同じ実装を2つ作らないこと。
# ⚠ .tscn を触らずコードで足す（_build_party_row() と同じ形。.tscn を編集すると
#   人間の作業が増える）。
# ⚠ _navigation_buttons / SCREEN_SCENES に足さないこと。あれは
#   unlocked_screens の解放判定を通る道で、この画面は解放の対象ではない
#   （skill_select_screen と同じ「下位画面」。段階9で見直す）。
func _add_party_preset_button() -> void:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = "PartyPresetButton"
	button.text = "ui_nav_party_preset"
	# ⚠ 既存5個と同じ size_flags を付けること（.tscn の AdventureButton 等は全部 3）。
	#   ⚠ これが無いと6個目だけ「内容ぶんの幅」を取り、残り5個が押し潰されて
	#     文字がはみ出す（2026-08-23に実際にそうなった）。
	#   ⚠ NEXT_STEPS §4「件数を増やす回では、既存の器の型を先に見る」。
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 6等分になるので、翻訳が効くまでの間（ja.csv 再インポート前）に
	#   キー名がそのまま出ても行を壊さないよう、はみ出しは切る。
	button.clip_text = true
	button.pressed.connect(_on_party_preset_pressed)
	adventure_button.get_parent().add_child(button)

func _on_party_preset_pressed() -> void:
	# ⚠ 戻る先を渡す（入口が2つあるため。TransferKeys.RETURN_PATH）。
	SceneManager.change_scene_with_data(
		PARTY_PRESET_PATH,
		{TransferKeys.RETURN_PATH: BASE_PATH}
	)

func _init_chest_badge() -> void:
	var count: int = GameManager.get_pending_chest_count()
	_update_chest_badge(count)

func _connect_signals() -> void:
	# GameManager からの通知
	GameManager.resource_changed.connect(_on_resource_changed)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.screen_unlocked.connect(_on_screen_unlocked)
	GameManager.pending_chests_changed.connect(_on_pending_chests_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	potion_use_button.pressed.connect(_on_use_potion_pressed)

	# その他ボタン
	chest_badge.pressed.connect(_on_chest_badge_pressed)
	save_button.pressed.connect(_on_save_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)

# ポモドーロから戻ってきたときの受け取り報告。
#
# 報酬の受け取り自体はポモドーロ画面が済ませているが、
# あちらでモーダルを出しても直後の画面遷移で消えてしまうため、
# 数だけを転送データで受け取り、拠点に着いてから出す。
#
# 拠点へは他の画面からも戻ってくるので、キーが無ければ何もしない。
func _show_arrival_rewards() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	if data.is_empty():
		return
	var potions: int = int(data.get(TransferKeys.POMODORO_POTIONS, 0))
	var chests: int = int(data.get(TransferKeys.POMODORO_CHESTS, 0))
	if potions <= 0 and chests <= 0:
		return
	Modal.notify(self, "ui_base_pomodoro_rewards", [potions, chests])

# --- シグナルハンドラ ---

func _on_resource_changed(resource_type: String, new_value: Variant) -> void:
	match resource_type:
		GameStateKeys.GOLD:
			gold_value.set_value(int(new_value))
		GameStateKeys.STAMINA:
			# スタミナ更新時は max も必要なので state から再取得 (EXEC §5-3)
			var state: Dictionary = GameManager.get_state()
			var stamina_data: Dictionary = state.get(GameStateKeys.STAMINA, {})
			var stamina_max: int = int(stamina_data.get(GameStateKeys.STAMINA_MAX, 0))
			stamina_value.set_value_with_max(int(new_value), stamina_max)
		GameStateKeys.GEMS:
			# 表示していないので無視
			pass
		_:
			push_warning("[BaseScreen] unknown resource_type: " + resource_type)

func _on_material_changed(material_id: String, new_amount: int) -> void:
	if _material_entries.has(material_id):
		var entry: HBoxContainer = _material_entries[material_id]
		var val_display: ResourceDisplay = entry.get_node("Value")
		val_display.set_value(new_amount)
	else:
		_create_material_entry(material_id, new_amount)

func _on_screen_unlocked(screen_id: String) -> void:
	if _navigation_buttons.has(screen_id):
		_navigation_buttons[screen_id].visible = true
	else:
		push_warning("[BaseScreen] unlocked screen_id not in navigation: " + screen_id)

func _on_pending_chests_changed(pending_count: int) -> void:
	_update_chest_badge(pending_count)

func _on_inventory_changed(item_id: String) -> void:
	if item_id != GameStateKeys.ITEM_STAMINA_POTION:
		return
	var count: int = GameManager.get_stamina_potion_count()
	potion_value.set_value(count)
	potion_use_button.disabled = count <= 0

func _on_use_potion_pressed() -> void:
	GameManager.use_stamina_potion()

# --- ヘルパー ---

func _create_material_entry(material_id: String, initial_amount: int) -> void:
	var entry: HBoxContainer = HBoxContainer.new()
	entry.name = material_id + "Entry"

	var name_label: Label = Label.new()
	name_label.text = "ui_res_" + material_id # auto_translate

	var val_display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate()
	val_display.name = "Value"

	entry.add_child(name_label)
	entry.add_child(val_display)
	materials_display.add_child(entry)

	val_display.set_value(initial_amount)

	_material_entries[material_id] = entry

func _update_chest_badge(count: int) -> void:
	if count > 0:
		chest_badge.visible = true
		chest_count_label.text = str(count)
	else:
		chest_badge.visible = false

func _go_to_screen(screen_id: String) -> void:
	var path: String = str(SCREEN_SCENES.get(screen_id, ""))
	if path == "":
		push_warning("[BaseScreen] unknown screen_id: %s" % screen_id)
		return

	# データ付きで遷移
	SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: screen_id})

func _on_chest_badge_pressed() -> void:
	SceneManager.change_scene_with_data(
		"res://scenes/guild/warehouse_screen.tscn",
		{TransferKeys.WAREHOUSE_TAB: "WarehouseScreen.TAB_CHEST"}
	)

func _on_save_pressed() -> void:
	if SaveManager.save_game():
		Modal.notify(self, "ui_base_save_completed")
	else:
		Modal.notify(self, "ui_base_save_failed")

# タイトルへ戻る前に確認する。
# オートセーブが無いため、ここで戻ると直前のセーブ以降の進行が消える。
func _on_back_to_title_pressed() -> void:
	var ok: bool = await Modal.confirm(self, "ui_title_back_confirm")
	if not ok:
		return
	SceneManager.change_scene(TITLE_PATH)
