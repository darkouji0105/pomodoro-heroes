class_name InventoryWindow
extends Window

# 倉庫の窓（2026-09-15）。⚠ ゲーム全体で1枚。
#
# ⚠⚠ 中身は倉庫画面そのもの（`warehouse_screen.tscn`・4タブ・詳細と操作つき）
#   （人間の決定「1B」）。⚠ 倉庫画面はギルドからも今までどおり開ける（⚠ 同じシーンを使い回す）。
# ⚠⚠ いつも OS の別窓（force_native）で出す（人間の決定「別窓で」）。
#   ⚠ ヘッドレスは OS の窓を作れないので、⚠ そこでだけ埋め込みになる（⚠ 検査はその形で回る）。
# ⚠⚠ force_native は「隠している間」にしか立てられない（⚠ 表示中に立てると赤・前回の実測）。
# ⚠ 起動時に `SceneManager` が root に1つだけ作る（⚠ `ResourceHud` と同じ置き方）。
#   ⚠ Autoload は増やさない。⚠ 画面を移っても閉じない（⚠ 中身もページもそのまま）。
# ⚠ 開け閉めは右上の「倉庫」ボタン（`ResourceHud`・人間の決定「ボタン」）。
# ⚠⚠ タイトル・戦闘・ポモドーロでは出さない（人間の決定）。⚠ その画面に移ったら閉じ、ボタンも隠す。
# ⚠ インベントリ専用のフォルダ scenes/inventory/（人間の決定 2026-09-15）。⚠ `.tscn` を持たない。

# ⚠ 持ち物のマス目の組の名前。⚠ 装備マスがこの組から受ける。
const DRAG_GROUP: String = "inventory"
const WAREHOUSE_SCENE: String = "res://scenes/guild/warehouse_screen.tscn"
# ⚠ 出さない画面（人間の決定「タイトル以外から」「戦闘中とポモドーロも出さない」）。
const BLOCKED_SCENES: Array[String] = [
	"res://scenes/title/title_screen.tscn",
	"res://scenes/adventure/battle.tscn",
	"res://scenes/pomodoro/pomodoro.tscn",
]
# ⚠ まだ1度も画面を見ていない印（⚠ 空文字は「current_scene が無い」と区別できないため）。
const SCENE_UNCHECKED: String = "<unchecked>"

static var _instance: InventoryWindow = null

var warehouse: WarehouseScreen = null
# ⚠ 持ち物のマス目（⚠ 倉庫画面のもの）。⚠ 検査と別窓のドラッグが引く。
var grid: ItemGrid = null
var _scene_path: String = SCENE_UNCHECKED


static func spawn_into(root: Node) -> InventoryWindow:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: InventoryWindow = InventoryWindow.new()
	made.name = "InventoryWindow"
	made.visible = false
	made.force_native = true
	# ⚠ 相手が子を組み立てている最中だと `add_child()` は失敗する。⚠ 1フレーム待つこと。
	root.add_child.call_deferred(made)
	_instance = made
	return made


static func get_instance() -> InventoryWindow:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	return null


# 開く／閉じる。⚠ 出さない画面では開かない。
static func toggle() -> void:
	var window: InventoryWindow = get_instance()
	if window == null or not window.is_inside_tree():
		return
	if window.visible:
		window.hide()
		return
	if not is_scene_allowed(window._current_scene_path()):
		return
	window.popup_centered()


static func is_scene_allowed(scene_path: String) -> bool:
	return not BLOCKED_SCENES.has(scene_path)


func _ready() -> void:
	title = tr("ui_nav_warehouse")
	close_requested.connect(hide)
	warehouse = load(WAREHOUSE_SCENE).instantiate()
	# ⚠ add_child() より先に入れる（⚠ 倉庫の `_ready()` が見る）。
	warehouse.in_window = true
	add_child(warehouse)
	grid = warehouse.inventory_grid
	_fit_to_content.call_deferred()


# ⚠ 倉庫画面の根は素の Control で、⚠ 最小サイズを持たない。⚠ 中の Layout に合わせる。
func _fit_to_content() -> void:
	var layout: Control = warehouse.get_node("Layout") as Control
	var content: Vector2i = Vector2i(layout.get_combined_minimum_size().ceil())
	min_size = content
	size = content


func _process(_delta: float) -> void:
	var path: String = _current_scene_path()
	if path == _scene_path:
		return
	# ⚠ HUD がまだできていなければ、⚠ 次のフレームでもう一度見る。
	if ResourceHud.get_instance() == null:
		return
	apply_scene(path)


# 画面が変わった。⚠ 出さない画面なら閉じて、⚠ ボタンも隠す。
#   ⚠ 検査から直に呼べるように public（⚠ ヘッドレスでは current_scene を差し替えにくい）。
func apply_scene(scene_path: String) -> void:
	_scene_path = scene_path
	var allowed: bool = is_scene_allowed(scene_path)
	ResourceHud.set_storage_button_shown(allowed)
	if not allowed and visible:
		hide()


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path
