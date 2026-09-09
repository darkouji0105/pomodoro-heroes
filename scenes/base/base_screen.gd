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
# ⚠ UI テストのページ（デバッグビルドのみ。⚠ リリース前に消す）。
const UI_TEST_PAGE_PATH: String = "res://tests/ui_test_page.tscn"

const SCREEN_SCENES: Dictionary = {
	GameStateKeys.SCREEN_ADVENTURE_SELECT: "res://scenes/adventure/adventure_select.tscn",
	GameStateKeys.SCREEN_GUILD: "res://scenes/guild/guild_screen.tscn",
	GameStateKeys.SCREEN_POMODORO: "res://scenes/pomodoro/pomodoro.tscn",
	GameStateKeys.SCREEN_SETTINGS: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_SCENARIO: PLACEHOLDER_PATH,
}

# ノード参照
# ⚠⚠ 金・スタミナは**右上の `ResourceBar` へ移した**（2026-09-09・人間の決定
#   「資源は、右上に表示する」「右上へ移して下段からは消す」）。
#   ⚠ 下段に残るのはポーション（⚠ 「使う」ボタンと対になっているため）と素材の行。
@onready var top_area: Control = $Layout/TopArea
@onready var potion_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/Value
@onready var potion_use_button: UiButton = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/UseButton
@onready var chest_badge: Button = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge
@onready var chest_count_label: Label = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge/ChestCountLabel

@onready var save_button: UiButton = $Layout/BottomArea/BottomLayout/ResourceRow/SaveButton
@onready var back_to_title_button: UiButton = $Layout/BottomArea/BottomLayout/ResourceRow/BackToTitleButton

@onready var adventure_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/AdventureButton
@onready var guild_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/GuildButton
@onready var pomodoro_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/PomodoroButton
@onready var settings_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/SettingsButton
@onready var scenario_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/ScenarioButton

# 内部状態
var _navigation_buttons: Dictionary = {} # screen_id -> UiButton

func _ready() -> void:
	# GameManager の状態を取得
	var state: Dictionary = GameManager.get_state()

	_init_resource_displays(state)
	_init_navigation_buttons()
	_init_chest_badge()
	_connect_signals()
	_show_arrival_rewards()

func _init_resource_displays(_state: Dictionary) -> void:
	# ⚠ 右上の資源。⚠ 中身と更新は `ResourceBar` が自分で持つ。
	#   ⚠ 拠点は `ScreenHeader` を使っていないので、⚠ ここで直に置く。
	# ⚠⚠ 拠点だけ**素材16件も出す**（人間の指示「拠点のすべての素材を右上に」）。
	#   ⚠ 通貨3＋素材16で19個並ぶので、⚠ 1行では 1280 に入らない。
	#   ⚠ `TopArea` いっぱいに広げて折り返させる（⚠ `HFlowContainer` ＋ 右揃え）。
	#   ⚠ `TopArea` は空の器なので、⚠ 全面に広げてもぶつかるものが無い。
	var bar: ResourceBar = ResourceBar.new()
	bar.name = "ResourceBar"
	bar.show_materials = true
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ⚠ 面が押せてしまうと、⚠ 後ろに何か置いたときに押せなくなる。
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_area.add_child(bar)

	# ⚠ 絵を付ける（2026-09-09）。⚠ IDを渡すだけ（⚠ 画像の割り当てはここでしない）。
	potion_value.resource_id = GameStateKeys.ITEM_STAMINA_POTION
	potion_value.set_value(GameManager.get_stamina_potion_count())
	potion_use_button.disabled = GameManager.get_stamina_potion_count() <= 0

func _init_navigation_buttons() -> void:
	_navigation_buttons = {
		GameStateKeys.SCREEN_ADVENTURE_SELECT: adventure_button,
		GameStateKeys.SCREEN_GUILD: guild_button,
		GameStateKeys.SCREEN_POMODORO: pomodoro_button,
		GameStateKeys.SCREEN_SETTINGS: settings_button,
		GameStateKeys.SCREEN_SCENARIO: scenario_button,
	}

	for screen_id: String in _navigation_buttons:
		var btn: UiButton = _navigation_buttons[screen_id]
		# 解放状態の反映
		btn.visible = GameManager.is_screen_unlocked(screen_id)
		# 遷移イベント接続
		btn.pressed.connect(_go_to_screen.bind(screen_id))

	_add_party_preset_button()
	_add_ui_test_button()

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
	var button: UiButton = UiButton.new()
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

# ⚠⚠ UI テストのページへの入口（2026-09-06・人間の決定「拠点にデバッグ入口」）。
#
# ⚠ `OS.is_debug_build()` のガード付き＝⚠ 製品には出ない
#   （⚠ ポモドーロの「残り1秒にする」ボタンと同じ扱い）。
# ⚠⚠ リリース前に消す。⚠ 消すのは3箇所：⚠ この関数と呼び出し ／
#   ⚠ `tests/ui_test_page.gd` ／ `tests/ui_test_page.tscn`。
# ⚠ `_navigation_buttons` / `SCREEN_SCENES` に足さないこと（⚠ 解放判定の道ではない）。
func _add_ui_test_button() -> void:
	if not OS.is_debug_build():
		return
	var button: UiButton = UiButton.new()
	button.name = "UiTestButton"
	button.text = "ui_uitest_open"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.pressed.connect(_on_ui_test_pressed)
	adventure_button.get_parent().add_child(button)

func _on_ui_test_pressed() -> void:
	SceneManager.change_scene(UI_TEST_PAGE_PATH)

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
	# ⚠ `resource_changed` はもう繋がない（2026-09-09）。⚠ 金・スタミナは右上へ移り、
	#   ⚠ 更新は `ResourceBar` が自分で受ける。⚠ ここに残すと二重に更新することになる。
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
	# ⚠ 0 のほうを読み上げない（2026-09-06・宿題「宝箱を0個」が不格好）。
	#   ⚠ 文の組み立てをコード側でつなげない（AGENTS.md）。⚠ 文ごとキーを分ける。
	if chests <= 0:
		Modal.notify(self, "ui_base_potion_received", [potions])
	elif potions <= 0:
		Modal.notify(self, "ui_base_chest_received", [chests])
	else:
		Modal.notify(self, "ui_base_pomodoro_rewards", [potions, chests])

# --- シグナルハンドラ ---

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
