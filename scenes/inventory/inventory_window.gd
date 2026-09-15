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
#   ⚠ Autoload は増やさない。⚠ 画面を移っても作り直さない（⚠ 中身もページもそのまま）。
#
# ⚠⚠ 出すのは**拠点とギルド系の画面だけ**（人間の決定「拠点とギルド系だけ」）。
#   ⚠ それ以外（⚠ タイトル・冒険・フロア・ダンジョン・戦闘・ポモドーロ）では閉じて、⚠ ボタンも隠す。
# ⚠⚠ 出す／出さないは**右上の「倉庫」ボタンで切り替える状態**（人間の決定「出す出さないをトグルして、
#   出す画面に入るときその設定を」）。⚠ 既定は出す（人間「倉庫もデフォルトで開き」）。
#   ⚠ 窓の ✕ で閉じたのも「出さない」（⚠ ボタンと同じ意味にする）。⚠ ファイルには書かない（⚠ 起動し直すと出す）。
# ⚠⚠ 置き場所は**ゲームの窓の外の右隣**（人間の決定「右側に倉庫は出す」「拠点の画面に追従する」）。
#   ⚠ ゲームの窓が動いた・大きさが変わったら付いていく。⚠ 倉庫の窓を手で動かしたら、次にゲームの窓が動くまでそのまま。
# ⚠ インベントリ専用のフォルダ scenes/inventory/（人間の決定 2026-09-15）。⚠ `.tscn` を持たない。

# ⚠ 持ち物のマス目の組の名前。⚠ 装備マスがこの組から受ける。
const DRAG_GROUP: String = "inventory"
const WAREHOUSE_SCENE: String = "res://scenes/guild/warehouse_screen.tscn"
# ⚠ 出す画面（人間の決定「拠点とギルド系だけ」）。⚠ 画面を足したらここに1行足す。
const ALLOWED_SCENES: Array[String] = [
	"res://scenes/base/base_screen.tscn",
	"res://scenes/guild/guild_screen.tscn",
	"res://scenes/guild/training_screen.tscn",
	"res://scenes/guild/equipment_screen.tscn",
	"res://scenes/guild/skill_select_screen.tscn",
	"res://scenes/guild/stat_node_screen.tscn",
	"res://scenes/guild/warehouse_screen.tscn",
	"res://scenes/guild/research_screen.tscn",
	"res://scenes/guild/shop_screen.tscn",
	"res://scenes/guild/workshop_screen.tscn",
	"res://scenes/adventure/party_preset_screen.tscn",
]
# ⚠ まだ1度も画面を見ていない印（⚠ 空文字は「current_scene が無い」と区別できないため）。
const SCENE_UNCHECKED: String = "<unchecked>"

static var _instance: InventoryWindow = null

var warehouse: WarehouseScreen = null
# ⚠ 持ち物のマス目（⚠ 倉庫画面のもの）。⚠ 検査と別窓のドラッグが引く。
var grid: ItemGrid = null
# ⚠ 出したいか（⚠ ボタンで切り替える状態）。⚠ 既定は出す。
var wanted: bool = true
# ⚠ いま当てはめている画面。
var _scene_path: String = SCENE_UNCHECKED
# ⚠ 最後に見た本物の画面（⚠ 検査が apply_scene() で当てた画面を、⚠ 本物の画面で上書きしないため分ける）。
var _seen_scene_path: String = SCENE_UNCHECKED
# ⚠ 最後に見たゲームの窓の位置と大きさ（⚠ 変わったら右隣へ付いていく）。
var _seen_root_rect: Rect2i = Rect2i()


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


# 出す／出さないを切り替える（⚠ 右上の「倉庫」ボタン）。
static func toggle() -> void:
	var window: InventoryWindow = get_instance()
	if window == null or not window.is_inside_tree():
		return
	window.wanted = not window.wanted
	window._apply_visibility()


static func is_scene_allowed(scene_path: String) -> bool:
	return ALLOWED_SCENES.has(scene_path)


func _ready() -> void:
	title = tr("ui_nav_warehouse")
	# ⚠ ✕ で閉じたのも「出さない」（⚠ ボタンと同じ）。
	close_requested.connect(func() -> void:
		wanted = false
		_apply_visibility()
	)
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
	# ⚠ ゲームの窓が動いた・大きさが変わった → 右隣へ付いていく。
	var root: Window = get_tree().root
	var root_rect: Rect2i = Rect2i(root.position, root.size)
	if root_rect != _seen_root_rect:
		_seen_root_rect = root_rect
		if visible:
			dock_to_main_window()

	see_scene(_current_scene_path())


# 本物の画面を見た。⚠ 変わっていれば当てはめる。
#   ⚠⚠ 画面が無い一瞬（空文字）は何もしない（2026-09-15・人間「画面を移動したら開きなおしてる」）。
#   ⚠ 画面の切り替えは「古い画面を外す → 次のフレームで新しい画面を入れる」なので、
#   ⚠ その間を「出さない画面」と取り違えて閉じ、⚠ 次の画面で開き直していた（⚠ 右隣へ戻る動きも出る）。
#   ⚠ 検査から直に呼べるように public。
func see_scene(path: String) -> void:
	if path == "" or path == _seen_scene_path:
		return
	# ⚠ HUD がまだできていなければ、⚠ 次のフレームでもう一度見る。
	if ResourceHud.get_instance() == null:
		return
	_seen_scene_path = path
	apply_scene(path)


# 画面が変わった。⚠ 出す画面ならボタンを出して、⚠ 出したい状態なら開く。⚠ それ以外は閉じてボタンも隠す。
#   ⚠ 検査から直に呼べるように public（⚠ ヘッドレスでは current_scene を差し替えにくい）。
func apply_scene(scene_path: String) -> void:
	_scene_path = scene_path
	ResourceHud.set_storage_button_shown(is_scene_allowed(scene_path))
	_apply_visibility()


func _apply_visibility() -> void:
	var show_now: bool = wanted and is_scene_allowed(_scene_path)
	if show_now == visible:
		return
	if show_now:
		show()
		dock_to_main_window()
	else:
		hide()


# ゲームの窓の外の右隣へ置く。⚠ 上端をそろえる（⚠ 位置は窓の中身の左上＝OS の枠の内側）。
func dock_to_main_window() -> void:
	var root: Window = get_tree().root
	position = Vector2i(root.position.x + root.size.x, root.position.y)


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path
