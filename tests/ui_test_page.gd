extends Control

# ⚠⚠ UI テストのページ（2026-09-06・人間の決定）。
#
# ⚠ 人間の言葉：「⚠ UIは、テスト用のページを作ってそこで全部確認できるようにしたい」。
# ⚠ 人間の裁き：⚠ ①載せるのは「画面ランチャー」と「部品カタログ」の両方
#              ⚠ ②入口は拠点に作る（⚠ OS.is_debug_build() のガード付き）。
#
# ⚠⚠ リリース前に消す前提のもの（⚠ ポモドーロの「残り1秒にする」ボタンと同じ扱い）。
#   ⚠ 消すのは3箇所：⚠ このファイル ／ `ui_test_page.tscn` ／ `base_screen.gd` の入口。
#
# ⚠⚠ 「開くだけでは出せない画面」が3枚ある（宿題72・73）。
#   ⚠ どれも `_ready()` で条件を満たさないとマップへ戻す：
#     ⚠ 宝箱     … ランに入っていて、かつ 拾い待ちがあること
#     ⚠ レリック … ランに入っていて、かつ DUNGEON_NODE_ID が渡されていること
#     ⚠ ショップ … ボスを倒した先であること（⚠ 途中は品揃えが空）
#   ⚠ ＝⚠ ここで「先に状態を作ってから開く」。⚠ 画面側の条件を緩めない
#     （⚠ 緩めると本番で「ランに入っていないのに開ける」経路ができる）。
#
# ⚠ 文字は tr()。⚠ ただし画面の名前は .tscn のファイル名をそのまま出す
#   （⚠ 識別子であって表示文ではない。⚠ 翻訳キーを20行増やさないため）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const DUNGEON_CHEST_PATH: String = "res://scenes/adventure/dungeon_chest.tscn"
const DUNGEON_RELIC_PATH: String = "res://scenes/adventure/dungeon_relic_select.tscn"
const DUNGEON_SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"
const BATTLE_PATH: String = "res://scenes/adventure/battle.tscn"

# ⚠ 戦闘を開くときに渡すステージ（⚠ stages.json に在るID。⚠ 無いと赤が出る）。
const BATTLE_SAMPLE_STAGE_ID: String = "floor_1"

# 全アイテムの1行あたりのマス数（⚠ 見た目の都合だけ。⚠ バランス数値ではない）。
const ITEM_GRID_COLUMNS: int = 16

# カテゴリの並び（⚠ `items.json` の `item_type`）。⚠ ここに無い型も落とさず末尾に出す。
const ITEM_CATEGORY_ORDER: Array[String] = [
	GameStateKeys.ITEM_TYPE_EQUIPMENT,
	GameStateKeys.ITEM_TYPE_PART,
	GameStateKeys.ITEM_TYPE_MATERIAL,
	GameStateKeys.ITEM_TYPE_CONSUMABLE,
	GameStateKeys.ITEM_TYPE_DUNGEON,
	GameStateKeys.ITEM_TYPE_KEY_ITEM,
	GameStateKeys.ITEM_TYPE_GIFT,
]
# ⚠ ルーンは items.json ではなく runes.json（表が別）。⚠ 型の名前とぶつからない語を使う。
const CATEGORY_RUNE: String = "rune"
# ⚠ レリックも表が別（relics.json）。⚠ マスの中身の種類も別（SLOT_KIND_RELIC）。
#   ⚠ 2026-09-07・人間の指示「⚠ レリックもUIテストにいれる」。
const CATEGORY_RELIC: String = "relic"
const CATEGORY_KEY_PREFIX: String = "ui_uitest_cat_"

# 等級順に並べるときの作業用のキー。⚠ この関数の外へ出さない。
const SORT_GRADE: String = "grade"
const SORT_ITEM_ID: String = "item_id"

# ⚠ そのまま開ける画面。⚠ 増えたらここに1行足す（⚠ ボタンの生成は下の1本だけ）。
const PLAIN_SCENES: Array[String] = [
	"res://scenes/base/base_screen.tscn",
	"res://scenes/title/title_screen.tscn",
	"res://scenes/pomodoro/pomodoro.tscn",
	"res://scenes/guild/guild_screen.tscn",
	"res://scenes/guild/warehouse_screen.tscn",
	"res://scenes/guild/training_screen.tscn",
	"res://scenes/guild/stat_node_screen.tscn",
	"res://scenes/guild/skill_select_screen.tscn",
	"res://scenes/guild/equipment_screen.tscn",
	"res://scenes/guild/research_screen.tscn",
	"res://scenes/guild/workshop_screen.tscn",
	"res://scenes/guild/shop_screen.tscn",
	"res://scenes/adventure/adventure_select.tscn",
	"res://scenes/adventure/party_preset_screen.tscn",
	"res://scenes/adventure/floor_map.tscn",
	"res://scenes/adventure/floor_relic_select.tscn",
	"res://scenes/adventure/floor_shop.tscn",
	"res://scenes/ui/placeholder_screen.tscn",
	# ⚠ リソース獲得の演出のデモ（2026-09-07）。⚠ リリース前に消す（宿題77 の仲間）。
	"res://tests/resource_gain_demo.tscn",
]

# ⚠⚠ その場に並べて見るもの（2026-09-07・人間の指示「⚠ 今のページから全部見れるように」）。
#
# ⚠ ポモドーロの4つのビューは `pomodoro.tscn` が切り替えて出す**中身**で、
#   ⚠ **戻るボタンを持っていない**（⚠ どれも `extends Control` ＋ シグナルを出すだけ）。
#   ⚠ ＝⚠ 画面遷移で開くと行き止まりになる。⚠ だからここに**埋め込んで**見せる。
# ⚠ シグナルは繋がない（⚠ 見た目を見るための場。⚠ 押しても何も起きないのが正しい）。
const EMBEDDED_VIEWS: Array[String] = [
	"res://scenes/pomodoro/protection_select_view.tscn",
	"res://scenes/pomodoro/focus_view.tscn",
	"res://scenes/pomodoro/break_view.tscn",
	"res://scenes/pomodoro/reflection_view.tscn",
]
# 埋め込む枠の高さ（⚠ 見た目の都合だけ。⚠ 中のビューはアンカーで広がる）。
const EMBEDDED_VIEW_HEIGHT: float = 260.0

# 等級の見本に使う個体（⚠ 10色を並べるため）。⚠ items.json に在るIDだけ。
const SAMPLE_EQUIP_ITEM_ID: String = "weapon_iron_sword"
const SAMPLE_MATERIAL_ITEM_ID: String = "construction_material_4"
const SAMPLE_RELIC_ID: String = "relic_banner_of_war"

const RESOURCE_DISPLAY_SCENE: PackedScene = preload(
	"res://scenes/ui/components/resource_display.tscn"
)

@onready var layout: VBoxContainer = $Scroll/Layout

var _grid: ItemGrid = null

# ⚠⚠ 詳細は「マウスの右側に出るドロップダウン」へ移した（2026-09-07・人間の指示
#   「⚠ ホバーするだけでマウスの右側に詳細モーダルを表示」）。
#   ⚠ 以前はカテゴリごとに `ItemDetail` を置いていた（⚠ 下まで戻らないと読めなかったため）。
#   ⚠ カーソルの横に出るようになったので **1つを全カテゴリで使い回す**。
var _popup: ItemDetailPopup = null
var _popup_detail: ItemDetail = null


func _ready() -> void:
	SceneManager.consume_transfer_data()
	_popup_detail = ItemDetail.new()
	_popup_detail.name = "PopupDetail"
	_popup = ItemDetailPopup.adopt(self, _popup_detail)
	_add_heading("ui_uitest_title")
	_add_action("ui_uitest_back", _on_back_pressed)

	_add_heading("ui_uitest_screens")
	for path: String in PLAIN_SCENES:
		_add_action(path.get_file(), _on_plain_scene_pressed.bind(path), false)

	_add_heading("ui_uitest_screens_prepared")
	_add_note("ui_uitest_prepare_note")
	_add_action(DUNGEON_MAP_PATH.get_file(), _on_dungeon_map_pressed, false)
	_add_action(DUNGEON_CHEST_PATH.get_file(), _on_dungeon_chest_pressed, false)
	_add_action(DUNGEON_RELIC_PATH.get_file(), _on_dungeon_relic_pressed, false)
	_add_action(DUNGEON_SHOP_PATH.get_file(), _on_dungeon_shop_pressed, false)
	_add_action(BATTLE_PATH.get_file(), _on_battle_pressed, false)

	_add_heading("ui_uitest_embedded")
	_add_note("ui_uitest_embedded_note")
	_build_embedded_views()

	_add_heading("ui_uitest_parts")
	_build_parts_catalog()

	_add_heading("ui_uitest_buttons")
	_build_button_catalog()

	_add_heading("ui_uitest_settings")
	_build_settings_catalog()

	_add_heading("ui_uitest_items")
	_build_all_items()


# --- 画面ランチャー ---

func _on_plain_scene_pressed(path: String) -> void:
	SceneManager.change_scene(path)


# ⚠ ランに入っていなければ入れてから開く（⚠ 入っていれば触らない＝進行中のランを壊さない）。
func _ensure_dungeon_run() -> bool:
	if GameManager.is_in_dungeon():
		return true
	return GameManager.start_dungeon_run()


func _on_dungeon_map_pressed() -> void:
	if not _ensure_dungeon_run():
		_add_note("ui_uitest_prepare_failed")
		return
	SceneManager.change_scene(DUNGEON_MAP_PATH)


# ⚠⚠ 宝箱の画面は「拾い待ちがある」ことが条件（`dungeon_chest.gd:89`）。
#   ⚠ ボスを倒すと戦利品が拾い待ちへ行く（決定29・段階20-f）ので、それで満たす。
func _on_dungeon_chest_pressed() -> void:
	if not _ensure_dungeon_run():
		_add_note("ui_uitest_prepare_failed")
		return
	if not GameManager.has_dungeon_pending_loot():
		var _cleared: bool = GameManager.clear_dungeon_boss()
	if not GameManager.has_dungeon_pending_loot():
		_add_note("ui_uitest_prepare_failed")
		return
	SceneManager.change_scene(DUNGEON_CHEST_PATH)


# ⚠ レリックの画面は node_id が要る（`dungeon_relic_select.gd:32`）。
#   ⚠ いまのランの中から relic のマスを1つ探して渡す。⚠ 無ければ開かない。
func _on_dungeon_relic_pressed() -> void:
	if not _ensure_dungeon_run():
		_add_note("ui_uitest_prepare_failed")
		return
	var node_id: String = _find_dungeon_node_of_kind(GameStateKeys.FLOOR_NODE_KIND_RELIC)
	if node_id == "":
		_add_note("ui_uitest_prepare_failed")
		return
	SceneManager.change_scene_with_data(
		DUNGEON_RELIC_PATH, {TransferKeys.DUNGEON_NODE_ID: node_id}
	)


# ⚠ ショップはボスの先だけ（決定15）。⚠ 倒していなければ倒してから開く。
func _on_dungeon_shop_pressed() -> void:
	if not _ensure_dungeon_run():
		_add_note("ui_uitest_prepare_failed")
		return
	if GameManager.get_dungeon_shop_entries().is_empty():
		var _cleared: bool = GameManager.clear_dungeon_boss()
	if GameManager.get_dungeon_shop_entries().is_empty():
		_add_note("ui_uitest_prepare_failed")
		return
	SceneManager.change_scene(DUNGEON_SHOP_PATH)


# ⚠ マップの中から種で1つ探す。⚠ ノードの持ち方は GameManager の状態に聞く
#   （⚠ ここでマップを組み直さない＝口を2本にしない）。
func _find_dungeon_node_of_kind(kind: String) -> String:
	var run: Dictionary = GameManager.get_dungeon_run()
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var ids: Array = nodes.keys()
	ids.sort()
	for entry: Variant in ids:
		var node_id: String = str(entry)
		var node: Dictionary = nodes.get(node_id, {})
		if str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == kind:
			return node_id
	return ""


# ⚠ 戦闘は stage_id が要る（`battle_controller.gd:143`）。⚠ 渡さないと黄を1本出して floor_1 で始まる。
#   ⚠ ダンジョンの戦闘ではなくシナリオ側で開く（⚠ ランを消費しない）。
func _on_battle_pressed() -> void:
	SceneManager.change_scene_with_data(BATTLE_PATH, {
		TransferKeys.STAGE_ID: BATTLE_SAMPLE_STAGE_ID,
		TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
	})


# --- 埋め込んで見るビュー（⚠ 遷移では見られないもの） ---

# ⚠ 枠（`Control`）を挟んでから中に入れる。⚠ ビューは `anchors_preset=15` で
#   親いっぱいに広がる作りなので、⚠ VBox に直接入れると高さ 0 に潰れる。
# ⚠ 名前は .tscn のファイル名をそのまま出す（⚠ 識別子。⚠ 翻訳キーを増やさない）。
func _build_embedded_views() -> void:
	for path: String in EMBEDDED_VIEWS:
		var name_label: Label = Label.new()
		name_label.name = "EmbeddedName_" + path.get_file()
		name_label.text = path.get_file()
		layout.add_child(name_label)

		var scene: PackedScene = load(path)
		if scene == null:
			_add_note("ui_uitest_prepare_failed")
			continue
		var holder: Control = Control.new()
		holder.name = "Embedded_" + path.get_file()
		holder.custom_minimum_size = Vector2(0.0, EMBEDDED_VIEW_HEIGHT)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.add_child(holder)
		holder.add_child(scene.instantiate())


# --- 部品カタログ ---

# ⚠ ここは「見た目を人間が見る」ための並べ物。⚠ 判定は1つも書かない。
func _build_parts_catalog() -> void:
	# PrimaryButton の4状態のうち、⚠ normal / disabled は静止で見える。
	#   ⚠ hover / pressed は人間がマウスを乗せて見る（⚠ 静止画では出せない）。
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ButtonStates"
	var normal: PrimaryButton = PrimaryButton.new()
	normal.name = "ButtonNormal"
	normal.text = "ui_uitest_button_normal"
	row.add_child(normal)
	var disabled: PrimaryButton = PrimaryButton.new()
	disabled.name = "ButtonDisabled"
	disabled.text = "ui_uitest_button_disabled"
	disabled.disabled = true
	row.add_child(disabled)
	layout.add_child(row)

	# ResourceDisplay（⚠ 金・スタミナ・素材の3通り）。
	var res_row: HBoxContainer = HBoxContainer.new()
	res_row.name = "ResourceDisplays"
	res_row.add_child(_make_resource_display("GoldDisplay", 1234, 0))
	res_row.add_child(_make_resource_display("StaminaDisplay", 7, 10))
	layout.add_child(res_row)

	# ItemGrid ＋ ItemDetail（⚠ 倉庫・鞄・宝箱で使い回している組み合わせ）。
	#   ⚠ 等級10色を1行で見る。⚠ 空きマスも混ぜる（⚠ 空の見た目も確認の対象）。
	_grid = ItemGrid.new()
	_grid.name = "PartsGrid"
	_grid.columns = 12
	layout.add_child(_grid)
	if _popup != null:
		_popup.watch(_grid)
	_grid.rebuild(_build_sample_entries(), 12)

	# Modal（⚠ 2種類とも出す。⚠ confirm は await するので押した先で待つ）。
	var modal_row: HBoxContainer = HBoxContainer.new()
	modal_row.name = "ModalButtons"
	var notify_button: PrimaryButton = PrimaryButton.new()
	notify_button.name = "ModalNotifyButton"
	notify_button.text = "ui_uitest_modal_notify"
	notify_button.pressed.connect(_on_modal_notify_pressed)
	modal_row.add_child(notify_button)
	var confirm_button: PrimaryButton = PrimaryButton.new()
	confirm_button.name = "ModalConfirmButton"
	confirm_button.text = "ui_uitest_modal_confirm"
	confirm_button.pressed.connect(_on_modal_confirm_pressed)
	modal_row.add_child(confirm_button)
	layout.add_child(modal_row)


# ⚠ ボタンの見本（2026-09-06・人間の指示「⚠ ボタンも」）。
#
# ⚠ hover / pressed は静止では出ない（⚠ 人間がマウスを乗せて見る）。
# ⚠ 長い文と幅いっぱいを並べる理由：⚠ 文字がはみ出す・潰れるのがここで分かるため
#   （⚠ 拠点のボタンが7個になった回の症状）。
func _build_button_catalog() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ButtonCatalog"
	row.add_child(_make_button("ButtonShort", "ui_uitest_button_normal", false))
	row.add_child(_make_button("ButtonDisabled2", "ui_uitest_button_disabled", true))
	row.add_child(_make_button("ButtonLong", "ui_uitest_button_long", false))
	var wide: PrimaryButton = _make_button("ButtonWide", "ui_uitest_button_wide", false)
	wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide.clip_text = true
	row.add_child(wide)
	layout.add_child(row)


func _make_button(node_name: String, label_key: String, is_disabled: bool) -> PrimaryButton:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = node_name
	button.text = tr(label_key)
	button.disabled = is_disabled
	return button


# ⚠⚠ 設定項目（2026-09-06・人間の指示「⚠ 設定項目や」）。
#
# ⚠⚠ 設定画面はまだ無い（⚠ 足りない UI の1件）。⚠ ここに作らない。
#   ⚠ ここで見せるのは「⚠ いま効いている値」だけ＝⚠ 何を設定画面に載せるかを決めるための材料。
# ⚠ 値は `Balance.sound`（`SoundConfig`）から毎回引く。⚠ 画面に複製しない（CLAUDE.md 4番）。
# ⚠ 音は実際に鳴らせる（⚠ ボタン1つ）。⚠ 音量つまみは付けない
#   （⚠ 付けるとセーブ構造の決定が要る＝設定画面の回の仕事）。
func _build_settings_catalog() -> void:
	_add_note("ui_uitest_settings_note")
	var config: SoundConfig = Balance.sound
	if config == null:
		_add_note("ui_uitest_prepare_failed")
		return
	var values: Label = Label.new()
	values.name = "SoundValues"
	values.text = "master %.1f dB ／ se %.1f dB ／ bgm %.1f dB ／ SE同時 %d 本" % [
		config.master_volume_db, config.se_volume_db, config.bgm_volume_db,
		config.se_player_count,
	]
	layout.add_child(values)
	var play: PrimaryButton = _make_button("PlaySeButton", "ui_uitest_play_se", false)
	play.pressed.connect(_on_play_se_pressed)
	layout.add_child(play)


func _on_play_se_pressed() -> void:
	SoundManager.play_se(SoundIds.ALARM_FOCUS_END)


# ⚠⚠ 全アイテム（2026-09-06・人間の指示「⚠ アイテムを全部見えるように」）。
#
# ⚠ 引くのは `MasterDataLoader.get_all_items()` と `get_all_runes()` の2本。
#   ⚠ ここに一覧を書かない（⚠ 品が増えたら黙って抜ける）。
# ⚠ マスにマウスを乗せるとカーソルの右に詳細が出る（⚠ 上のカタログと同じ器・2026-09-07）。
# ⚠ 等級は付けない（⚠ 個体ではなく「品の種類」を見るところ。⚠ 等級10色は上のカタログ）。
# ⚠⚠ カテゴリごとに分ける（2026-09-06・人間の指示「⚠ アイテムをカテゴリごとに分けよう」）。
#   ⚠ 分ける軸は `items.json` の `item_type`（⚠ IDの綴りから推測しない＝`game_manager.gd:148`）。
#   ⚠ ルーンは別の表（`get_all_runes()`）なので独立した1カテゴリにする。
func _build_all_items() -> void:
	var by_type: Dictionary = {}
	for entry: Variant in MasterDataLoader.get_all_items().keys():
		var item_id: String = str(entry)
		var item_type: String = str(
			MasterDataLoader.get_item(item_id).get(
				GameManager.ITEM_MASTER_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN
			)
		)
		if not by_type.has(item_type):
			by_type[item_type] = []
		(by_type[item_type] as Array).append(item_id)

	# ⚠ 並びは固定（⚠ 起動ごとに順が変わると「増えた・減った」が読めない）。
	for item_type: String in ITEM_CATEGORY_ORDER:
		if by_type.has(item_type):
			# ⚠ 装備だけ「全種類 × 等級1〜10」で並べる（下）。
			if item_type == GameStateKeys.ITEM_TYPE_EQUIPMENT:
				_add_equipment_grade_category(by_type[item_type])
			else:
				_add_item_category(item_type, by_type[item_type])
			by_type.erase(item_type)
	# ⚠⚠ 並びに無い型が来ても落とさない（⚠ 型が増えたときに黙って消えないように）。
	var leftovers: Array = by_type.keys()
	leftovers.sort()
	for entry: Variant in leftovers:
		_add_item_category(str(entry), by_type[entry])

	_add_item_category(CATEGORY_RUNE, MasterDataLoader.get_all_runes().keys())
	# ⚠ レリックは items.json に無いので別の口で引く（⚠ マスの種類も RELIC）。
	_add_item_category(
		CATEGORY_RELIC, MasterDataLoader.get_all_relic_ids(), GameManager.SLOT_KIND_RELIC
	)


# 1カテゴリぶん（⚠ 見出し ＋ マス目）。
#
# ⚠ 詳細はここに置かない（⚠ 押した所の近くに出す器が受け持つ・2026-09-07）。
# ⚠⚠ 並びは **等級順**（2026-09-07・人間の指示「⚠ アイテムも等級ごとに並べて」）。
#   ⚠ 等級は `ItemIcon.grade_and_number()` の1本に聞く（⚠ 段階から等級への写しを
#     ここに書き直さない＝⚠ 書くと色と並びが食い違う）。⚠ 同じ等級の中は綴り順。
# ⚠ `kind` はマスの中身の種類。⚠ レリックだけ別（⚠ items.json の品ではない）。
func _add_item_category(
	category: String, item_ids: Array, kind: String = GameManager.SLOT_KIND_ITEM
) -> void:
	var entries: Array = []
	for entry: Variant in _sorted_by_grade(item_ids):
		entries.append({
			GameManager.SLOT_ENTRY_KIND: kind,
			GameManager.SLOT_ENTRY_ITEM_ID: str(entry),
			GameManager.SLOT_ENTRY_COUNT: 1,
		})

	var heading: Label = Label.new()
	heading.name = "ItemCategory_" + category
	# ⚠ ラベルのキーは "ui_uitest_cat_" + item_type で機械的に引く（AGENTS.md の ui_nav_ と同じ流儀）。
	#   ⚠ 型が増えたら ja.csv に1行足すだけ。⚠ ここに if を書かない。
	# ⚠ 型が空のものは "other" に寄せる（⚠ キーが "ui_uitest_cat_" だけになるのを防ぐ）。
	var label_key: String = CATEGORY_KEY_PREFIX + (
		category if category != GameStateKeys.ITEM_TYPE_UNKNOWN else "other"
	)
	heading.text = "%s（%d）" % [tr(label_key), entries.size()]
	layout.add_child(heading)

	var grid: ItemGrid = ItemGrid.new()
	grid.name = "ItemGrid_" + category
	grid.columns = ITEM_GRID_COLUMNS
	layout.add_child(grid)
	# ⚠ 出す口は器の1本（⚠ カテゴリごとに繋ぎ替えない）。
	if _popup != null:
		_popup.watch(grid)
	grid.rebuild(entries, entries.size())


# 武器・防具・アクセサリーの全種類 × 等級1〜10（2026-09-07・人間の指示
#   「⚠ 武器防具アクセサリーの全種類の1から10をみせるように」）。
#
# ⚠ 1行＝1品の等級1〜10（⚠ 列を最大等級に合わせる）。⚠ 横に見れば等級10色、
#   ⚠ 縦に見れば品の種類。⚠ マスに乗せると「その等級で何枠開いているか」が読める。
# ⚠⚠ 個体は1つも作らない（⚠ 110個の個体を状態に入れない）。⚠ マスに等級だけ持たせた見本で、
#   ⚠ `ItemIcon` も `ItemDetail` も等級を entry から読む＝⚠ 個体と同じ見た目になる。
# ⚠ 最大等級は `GameManager.get_max_equipment_grade()` に聞く（⚠ 10 と書かない）。
func _add_equipment_grade_category(item_ids: Array) -> void:
	var max_grade: int = GameManager.get_max_equipment_grade()
	var ids: Array = item_ids.duplicate()
	ids.sort()
	var entries: Array = []
	for entry: Variant in ids:
		for grade: int in range(1, max_grade + 1):
			entries.append({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
				GameManager.SLOT_ENTRY_ITEM_ID: str(entry),
				GameManager.SLOT_ENTRY_GRADE: grade,
				GameManager.SLOT_ENTRY_COUNT: 1,
			})

	var heading: Label = Label.new()
	heading.name = "ItemCategory_" + GameStateKeys.ITEM_TYPE_EQUIPMENT
	# ⚠ 数値だけの部分に tr() は通さない（AGENTS.md）。
	heading.text = "%s（%d × %d）" % [
		tr(CATEGORY_KEY_PREFIX + GameStateKeys.ITEM_TYPE_EQUIPMENT), ids.size(), max_grade
	]
	layout.add_child(heading)

	var grid: ItemGrid = ItemGrid.new()
	grid.name = "ItemGrid_" + GameStateKeys.ITEM_TYPE_EQUIPMENT
	# ⚠ 列は最大等級にそろえる＝1行が1品の等級1〜10になる。
	grid.columns = max_grade
	layout.add_child(grid)
	if _popup != null:
		_popup.watch(grid)
	grid.rebuild(entries, entries.size())


# 等級の小さい順。⚠ 同じ等級の中は綴り順（⚠ 起動ごとに並びが変わらないように）。
#
# ⚠ 装備はここを通らない（⚠ `_add_equipment_grade_category()` が等級1〜10で並べる）。
#   ⚠ ここで等級10色が並ぶのは装飾・素材・ルーン。
func _sorted_by_grade(item_ids: Array) -> Array:
	var rows: Array = []
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		rows.append({
			SORT_GRADE: int(
				ItemIcon.grade_and_number(item_id, 0).get(ItemIcon.RESULT_GRADE, 1)
			),
			SORT_ITEM_ID: item_id,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a[SORT_GRADE]) != int(b[SORT_GRADE]):
			return int(a[SORT_GRADE]) < int(b[SORT_GRADE])
		return str(a[SORT_ITEM_ID]) < str(b[SORT_ITEM_ID])
	)
	var sorted_ids: Array = []
	for entry: Variant in rows:
		sorted_ids.append(str((entry as Dictionary)[SORT_ITEM_ID]))
	return sorted_ids




# 等級10色ぶんの個体 ＋ 素材 ＋ レリック（⚠ ItemDetail の3つの枝を全部出す）。
func _build_sample_entries() -> Array:
	var entries: Array = []
	for grade: int in range(1, 11):
		entries.append({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
			GameManager.SLOT_ENTRY_ITEM_ID: SAMPLE_EQUIP_ITEM_ID,
			GameManager.SLOT_ENTRY_INSTANCE_ID: "uitest_%d" % grade,
			GameManager.SLOT_ENTRY_GRADE: grade,
			GameManager.SLOT_ENTRY_COUNT: 1,
		})
	entries.append({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: SAMPLE_MATERIAL_ITEM_ID,
		GameManager.SLOT_ENTRY_COUNT: 99,
	})
	entries.append({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_RELIC,
		GameManager.SLOT_ENTRY_ITEM_ID: SAMPLE_RELIC_ID,
		GameManager.SLOT_ENTRY_COUNT: 1,
	})
	return entries




func _on_modal_notify_pressed() -> void:
	var _dialog: ModalDialog = Modal.notify(self, "ui_uitest_modal_message")


func _on_modal_confirm_pressed() -> void:
	var accepted: bool = await Modal.confirm(self, "ui_uitest_modal_message")
	print("[UiTestPage] confirm -> %s" % str(accepted))


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)


# --- 並べる道具（⚠ ボタンを作る口はここ1本） ---

# ⚠⚠ ResourceDisplay は .tscn を持つ部品（⚠ 中に ValueLabel がある）。
#   ⚠ `.new()` で作ると子が無く `_refresh()` が落ちる。⚠ 必ずシーンから作る。
#   ⚠ ItemGrid / ItemDetail は .tscn を持たないので `.new()` でよい（⚠ 流儀が違う）。
func _make_resource_display(node_name: String, value: int, max_value: int) -> ResourceDisplay:
	var display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate() as ResourceDisplay
	display.name = node_name
	if max_value > 0:
		display.show_max = true
		display.max_value = max_value
	display.value = value
	return display


func _add_heading(key: String) -> void:
	var label: Label = Label.new()
	label.name = "Heading_" + key
	label.text = tr(key)
	layout.add_child(label)


func _add_note(key: String) -> void:
	var label: Label = Label.new()
	label.name = "Note_" + key
	label.text = tr(key)
	layout.add_child(label)


# ⚠ ラベルが翻訳キーなら tr()、⚠ ファイル名ならそのまま出す（識別子のため）。
func _add_action(label: String, handler: Callable, is_key: bool = true) -> void:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = "Action_" + label
	button.text = tr(label) if is_key else label
	button.pressed.connect(handler)
	layout.add_child(button)
