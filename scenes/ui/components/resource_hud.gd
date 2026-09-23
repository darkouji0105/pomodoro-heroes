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
# ⚠ 資源を横1列に並べる器（2026-09-15）。⚠ 右上に寄せるのはこちら。
# ⚠⚠ 「倉庫」ボタンは消した（2026-09-23・人間「⚠ もう倉庫の別窓はいらない」）。
#   ⚠ 倉庫はギルドのカードから入る画面になった（`DECISIONS.md` `BS-15`）。
var _row: HBoxContainer = null


static func spawn_into(root: Node) -> ResourceHud:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: ResourceHud = ResourceHud.new()
	made.name = "ResourceHud"
	# ⚠ 相手が子を組み立てている最中だと `add_child()` は失敗する。⚠ 1フレーム待つこと。
	root.add_child.call_deferred(made)
	_instance = made
	return made


# ⚠ 出すか隠すか（2026-09-09・人間の指示「ポモドーロは直して」）。
#   ⚠ ポモドーロの集中中は通貨を出さない（⚠ 集中を邪魔しない画面にする決まり）。
# ⚠⚠ 隠したままにしないこと。⚠ `SceneManager` が画面を変えるたびに true へ戻し、
#   ⚠ 隠したい画面が自分の `_ready()` で false にする。⚠ こうすると
#   ⚠ ポモドーロから抜けたとき（⚠ 中断でも完走でも）に必ず戻る。
static func set_shown(value: bool) -> void:
	var hud: ResourceHud = get_instance()
	if hud == null:
		return
	hud._field.visible = value


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

	# ⚠ 2026-09-15：⚠ 資源の左に「倉庫」ボタンを置くため、⚠ 横1列の器ごと右上に寄せる。
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_field.add_child(_row)

	bar = ResourceBar.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(bar)

	# ⚠ 画面の外周と同じ余白で右上に寄せる（⚠ 値は Theme が持つ）。
	var margin: float = float(_screen_margin())
	_row.offset_right = -margin
	_row.offset_top = margin
	# ⚠⚠ ここを無名関数にしないこと（2026-09-21）。
	#   ⚠ 無名関数は `self` を**値として捕まえる**ので、⚠ 畳まれるときに
	#   ⚠ 子（`_row`）が外れて `resized` が飛んだ瞬間、⚠ 捕まえていた `self` がもう無い
	#   （⚠ `Lambda capture at index 0 was freed` ＝ `resource_hud.gd:117`）。
	# ⚠ 名前付きの関数なら、⚠ Godot が解放のときに自動で切る。
	_row.resized.connect(_on_row_resized)


func _on_row_resized() -> void:
	width_changed.emit(_reserved_width())


# ⚠ 画面側が上に空けるべき高さ（⚠ HUD の下端 ＋ 1つぶんの余白）。
#   ⚠ 拠点は右上に素材を並べるので、⚠ この下から始めないと通貨の下に潜る。
static func reserved_height() -> float:
	var hud: ResourceHud = get_instance()
	if hud == null:
		return 0.0
	return hud._reserved_height()


func _reserved_width() -> float:
	if _row == null:
		return 0.0
	return _row.size.x + float(_screen_margin())


func _reserved_height() -> float:
	if _row == null:
		return 0.0
	return float(_screen_margin()) + _row.size.y + float(_screen_margin())


# ⚠ 画面ルートの余白（`ScreenMargin`）。⚠ ここに数値を書かない。
func _screen_margin() -> int:
	if _field == null:
		return 0
	return _field.get_theme_constant(&"margin_right", &"ScreenMargin")
