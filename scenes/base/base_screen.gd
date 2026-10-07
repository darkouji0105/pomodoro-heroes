# res://scenes/base/base_screen.gd
# 拠点画面（下部：リソース表示と遷移ボタン）の実装
# AGENTS.md 準拠。
# ⚠ 2026-10-05（回P-1）から自動セーブがある（`SaveManager.autosave()`）。⚠ SaveButton は人間の決定で残す（「⚠ ｑ２　あ」）。

extends Control

# 定数
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TITLE_PATH: String = "res://scenes/title/title_screen.tscn"
const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
# ⚠ UI テストのページ（デバッグビルドのみ。⚠ リリース前に消す）。
const UI_TEST_PAGE_PATH: String = "res://tests/ui_test_page.tscn"

const SCREEN_SCENES: Dictionary = {
	GameStateKeys.SCREEN_ADVENTURE_SELECT: "res://scenes/adventure/adventure_select.tscn",
	GameStateKeys.SCREEN_POMODORO: "res://scenes/pomodoro/pomodoro.tscn",
	# ⚠ 2026-09-28（回UI-仕組み③）：⚠ 設定の画面。
	GameStateKeys.SCREEN_SETTINGS: "res://scenes/base/settings_screen.tscn",
	GameStateKeys.SCREEN_SCENARIO: PLACEHOLDER_PATH,
}

# ノード参照
# ⚠⚠ 金・スタミナは**右上の `ResourceBar` へ移した**（2026-09-09・人間の決定
#   「資源は、右上に表示する」「右上へ移して下段からは消す」）。
#   ⚠ 下段に残るのはポーション（⚠ 「使う」ボタンと対になっているため）と素材の行。
@onready var top_area: Control = $Layout/TopArea
@onready var chest_badge: Button = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge
@onready var chest_count_label: Label = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge/ChestCountLabel

@onready var save_button: UiButton = $Layout/BottomArea/BottomLayout/ResourceRow/SaveButton
@onready var back_to_title_button: UiButton = $Layout/BottomArea/BottomLayout/ResourceRow/BackToTitleButton

@onready var adventure_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/AdventureButton
@onready var pomodoro_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/PomodoroButton
@onready var settings_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/SettingsButton
@onready var scenario_button: UiButton = $Layout/BottomArea/BottomLayout/NavigationButtons/ScenarioButton

# 内部状態
var _navigation_buttons: Dictionary = {} # screen_id -> UiButton

func _ready() -> void:
	# GameManager の状態を取得
	var state: Dictionary = GameManager.get_state()

	# ⚠ 朝4:00 の移し（2026-10-04・`TK-6`）。⚠ 紙を描く前に（⚠ 昨日終えたものを紙に残さない）。
	var _moved: int = GameManager.roll_over_done_tasks()

	_init_resource_displays(state)
	_init_task_note()
	_init_navigation_buttons()
	# ⚠ 2026-09-26（回UI-3・`NAV-6`）：⚠ 施設の帯。⚠ ギルドのボタンと編成のボタンは帯へ移した。
	BaseFacilityBar.attach(self, $Layout, BaseFacilityBar.HQ)
	_init_chest_badge()
	_connect_signals()
	_show_arrival_rewards()


func _init_resource_displays(_state: Dictionary) -> void:
	# ⚠⚠ 2026-10-06：⚠ 右上の素材16件の帯をやめた（⚠ 人間「⚠ 拠点では書かずに、関連する画面でのみ表示するように　リソースは」）。
	#   ⚠ 素材は使う画面の見出しに出る（`ScreenHeader.show_materials()`・育成／鍛冶場／作業場／研究）。⚠ 通貨は今までどおり `ResourceHud`。
	# ⚠⚠ 2026-10-07：⚠ 下段の「スタミナポーション 使う」もやめた（⚠ 人間「⚠ 片方にまとめて」）＝右上のスタミナの「＋」→「使う」。
	pass

# ⚠ 壁の紙（2026-10-04・`TK-3`）。⚠ 左上に置く。⚠ 位置と大きさは Theme の `Task/wall_*`。
func _init_task_note() -> void:
	var note: TaskWallNote = TaskWallNote.create()
	top_area.add_child(note)
	var margin: float = float(note.get_theme_constant(&"wall_left", TaskWallNote.THEME_TYPE))
	note.position = Vector2(margin, margin)
	note.size = note.custom_minimum_size


func _init_navigation_buttons() -> void:
	_navigation_buttons = {
		GameStateKeys.SCREEN_ADVENTURE_SELECT: adventure_button,
		GameStateKeys.SCREEN_POMODORO: pomodoro_button,
		GameStateKeys.SCREEN_SETTINGS: settings_button,
		GameStateKeys.SCREEN_SCENARIO: scenario_button,
	}

	for screen_id: String in _navigation_buttons:
		var btn: UiButton = _navigation_buttons[screen_id]
		# 解放状態の反映
		# ⚠ 設定はいつも出す（2026-09-28・設定の画面を作った回）。⚠ 設定を解放するステージは無い＝前は出なかった。
		btn.visible = screen_id == GameStateKeys.SCREEN_SETTINGS or GameManager.is_screen_unlocked(screen_id)
		# 遷移イベント接続
		btn.pressed.connect(_go_to_screen.bind(screen_id))

	_add_ui_test_button()
	_add_continue_button()


# ⚠⚠ 途中のランへ1回で（2026-10-07・人間「⚠ 判断がいらないものをとりあえずぜんぶ」＝回UI-便 G）。
#   ⚠ 前は 掲示板 → 札の「続きから」の2回。⚠ 入り方は掲示板の「続きから」と同じ（⚠ 地図へ移るだけ・出撃届は挟まない）。
#   ⚠ 途中のランが無ければ出さない。
func _add_continue_button() -> void:
	var path: String = ""
	if GameManager.is_in_dungeon():
		path = DUNGEON_MAP_PATH
	elif GameManager.is_in_floor():
		path = FLOOR_MAP_PATH
	if path == "":
		return
	var button: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_base_continue_run")
	button.name = "ContinueRunButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(SceneManager.change_scene.bind(path))
	adventure_button.get_parent().add_child(button)
	adventure_button.get_parent().move_child(button, 0)

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

func _init_chest_badge() -> void:
	var count: int = GameManager.get_pending_chest_count()
	_update_chest_badge(count)

func _connect_signals() -> void:
	# GameManager からの通知
	# ⚠ `resource_changed` はもう繋がない（2026-09-09）。⚠ 金・スタミナは右上へ移り、
	#   ⚠ 更新は `ResourceBar` が自分で受ける。⚠ ここに残すと二重に更新することになる。
	GameManager.screen_unlocked.connect(_on_screen_unlocked)
	GameManager.pending_chests_changed.connect(_on_pending_chests_changed)

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
	# ⚠ 窓の指定は1つにまとめる（⚠ 3本とも同じ形。⚠ 決定 `MD-1` / `MD-3`）。
	var options: Dictionary = {
		Modal.OPTION_TITLE: tr("ui_common_title_received"),
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
	}
	if chests <= 0:
		Modal.notify(self, "ui_base_potion_received", [potions], false, options)
	elif potions <= 0:
		Modal.notify(self, "ui_base_chest_received", [chests], false, options)
	else:
		Modal.notify(self, "ui_base_pomodoro_rewards", [potions, chests], false, options)

# --- シグナルハンドラ ---

func _on_screen_unlocked(screen_id: String) -> void:
	if _navigation_buttons.has(screen_id):
		_navigation_buttons[screen_id].visible = true
	else:
		push_warning("[BaseScreen] unlocked screen_id not in navigation: " + screen_id)

func _on_pending_chests_changed(pending_count: int) -> void:
	_update_chest_badge(pending_count)

# --- ヘルパー ---

func _update_chest_badge(count: int) -> void:
	if count > 0:
		chest_badge.visible = true
		# ⚠ 10-07（人間「⚠ しおり紐は気づいたんだけど　そこから言ったページで何を見ればいいのかわかんなかった」）：⚠ 本部の紐の行き先＝届いた宝箱にも紐。
		RibbonMark.attach(chest_badge)
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

# 宝箱のバッジ（2026-09-15・人間の指示「宝箱は、倉庫側ではなく拠点から直接開けるように」）。
#
# ⚠ 前は倉庫の宝箱タブへ移っていた。⚠ 倉庫は別窓だけになり、⚠ 宝箱タブは消した。
# ⚠ 2026-09-27（決定 `BS-21`・人間「⚠ 1あ」）：⚠ 拠点の上に重ねる一覧（`ChestPanel`）をやめ、⚠ 「届いた宝箱」の画面へ移る。
func _on_chest_badge_pressed() -> void:
	SceneManager.change_scene(CHEST_PATH)

func _on_save_pressed() -> void:
	var save_options: Dictionary = {Modal.OPTION_TITLE: tr("ui_common_title_save")}
	if SaveManager.save_game():
		Modal.notify(self, "ui_base_save_completed", [], false, save_options)
	else:
		Modal.notify(self, "ui_base_save_failed", [], false, save_options)

# タイトルへ戻る前に確認する。
# ⚠ 戻るときに自動セーブされる（`SceneManager.change_scene()`・回P-1）。⚠ 確かめの窓は押し間違いのため残す。
func _on_back_to_title_pressed() -> void:
	var ok: bool = await Modal.confirm(self, "ui_title_back_confirm", [], false, {
		Modal.OPTION_TITLE: tr("ui_base_back_to_title"),
	})
	if not ok:
		return
	SceneManager.change_scene(TITLE_PATH)
