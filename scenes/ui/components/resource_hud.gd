class_name ResourceHud
extends CanvasLayer

# ページをまたいで居座る資源の表示（2026-09-09・人間の指示
#   「これページをまたぐコンポーネントにするところからだと思う」）。
#
# ⚠ 中身は **通貨3つだけ**（人間の決定）。⚠ 素材16件は拠点の画面が自分で持つ
#   （⚠ 全画面に19個並べると、⚠ 倉庫や装備の上の帯が埋まる）。
# ⚠ 起動時に `SceneManager` が1つだけ作る（⚠ `ResourceGainEffect` と同じ置き方）。
#   ⚠ Autoload は増やさない（AGENTS.md の6つを守る）。⚠ `root` に付くので画面遷移で消えない。
# ⚠⚠ **画面ごとに置かない**。⚠ 遷移のたびに作り直すと、⚠ そのたびに数字が組み直される。
#
# ⚠ 「戻る」と重なる件は、⚠ 画面側が `reserved_width()` ぶん右に余白を空けて避ける
#   （人間の指示「⚠ 戻るボタンは適時調整する。⚠ 重なるなら少しずらして」）。
#   ⚠ HUD は画面の中身を知らない。⚠ 知っているのは自分の幅だけ。

# ⚠ 画面より上、⚠ 増えた演出（50）より下。⚠ 飛んできたアイコンが HUD の上を通る。
const LAYER_INDEX: int = 40

static var _instance: ResourceHud = null

# ⚠ 幅が変わったら画面側が余白を取り直す（⚠ 桁が増えると広がるため）。
signal width_changed(width: float)

var bar: ResourceBar = null
var _field: Control = null


static func spawn_into(root: Node) -> ResourceHud:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: ResourceHud = ResourceHud.new()
	made.name = "ResourceHud"
	# ⚠ 相手が子を組み立てている最中だと `add_child()` は失敗する。⚠ 1フレーム待つこと。
	root.add_child.call_deferred(made)
	_instance = made
	return made


static func get_instance() -> ResourceHud:
	if _instance != null and is_instance_valid(_instance) and _instance.bar != null:
		return _instance
	return null


# ⚠ 画面側が右に空けるべき幅（⚠ HUD の幅 ＋ 画面の外周の余白）。
#   ⚠ まだできていなければ 0（⚠ 1フレーム後に `width_changed` で取り直せる）。
static func reserved_width() -> float:
	var hud: ResourceHud = get_instance()
	if hud == null:
		return 0.0
	return hud._reserved_width()


func _ready() -> void:
	layer = LAYER_INDEX

	_field = Control.new()
	_field.name = "Field"
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)

	bar = ResourceBar.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_field.add_child(bar)

	# ⚠ 画面の外周と同じ余白で右上に寄せる（⚠ 値は Theme が持つ）。
	var margin: float = float(_screen_margin())
	bar.offset_right = -margin
	bar.offset_top = margin
	bar.resized.connect(func() -> void: width_changed.emit(_reserved_width()))


# ⚠ 画面側が上に空けるべき高さ（⚠ HUD の下端 ＋ 1つぶんの余白）。
#   ⚠ 拠点は右上に素材を並べるので、⚠ この下から始めないと通貨の下に潜る。
static func reserved_height() -> float:
	var hud: ResourceHud = get_instance()
	if hud == null:
		return 0.0
	return hud._reserved_height()


func _reserved_width() -> float:
	if bar == null:
		return 0.0
	return bar.size.x + float(_screen_margin())


func _reserved_height() -> float:
	if bar == null:
		return 0.0
	return float(_screen_margin()) + bar.size.y + float(_screen_margin())


# ⚠ 画面ルートの余白（`ScreenMargin`）。⚠ ここに数値を書かない。
func _screen_margin() -> int:
	if _field == null:
		return 0
	return _field.get_theme_constant(&"margin_right", &"ScreenMargin")
