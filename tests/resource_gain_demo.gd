extends Control

# ⚠⚠ リソースを獲得したときの演出のデモ（2026-09-07・人間の指示）。
#
# ⚠ 人間の言葉（1回目）：「⚠ リソースの獲得のアニメーションのデモを作りたい　⚠ 専用の画面を作りたい」。
# ⚠ 人間の言葉（2回目）：「⚠ ルートが変に見える　⚠ 最短距離を迂回させて飛ばすのはどうか
#   ⚠ ルートの候補をいくつか出してほしい　⚠ 全部繋げる方向でやってみる」。
# ⚠ 人間の言葉（3回目）：「⚠ 始めと終わりは遅くする　⚠ 複数飛ばすパターンも作る
#   ⚠ 同じ場所から飛ばして見れるように、⚠ ボタンは所定の位置で、⚠ 設定をいじる形式で」。
#
# ⚠⚠ **ここは「選ぶための場」であって本番ではない。**
#   ⚠ この画面のコードを本番から呼ばないこと。⚠ 選ばれた形だけを次の回に本番へ入れる。
#
# ⚠⚠ **飛ばす場所は固定**（3回目の指示）。⚠ 前は「押したボタンの位置」から飛ばしていたので、
#   ⚠ ボタンごとに出どころが変わって **見比べられなかった**。⚠ いまは画面の決まった1点から飛ぶ。
#   ⚠ ボタンは並べたまま、⚠ 変えるのは下の設定（`OptionButton`）。
#
# ⚠⚠ **本番の状態を1つも触らない。** ⚠ `GameManager.add_gold()` 等を呼ばない
#   （⚠ デモを触るたびに所持金が増えると、⚠ 他の検証の数字が狂う）。
#
# ⚠⚠ **数値をこのファイルに置いている**（⚠ 秒数・距離）。⚠ 本番へ入れるときは
#   `AdventureConfig.pop_rise_px` / `pop_duration_sec` と同じように Config へ移すこと
#   （⚠ AGENTS.md「数値管理ルール」）。⚠ いまは「どれを採るか」が決まっていないので、
#   ⚠ 決まっていないもののために .tres と Balance の配線を人間に頼まない。
#
# ⚠⚠ **リリース前に消すもの**（⚠ `ui_test_page` と同じ扱い＝宿題77 の仲間）。
#   ⚠ 消すのは3箇所：⚠ このファイル ／ `resource_gain_demo.tscn` ／
#   ⚠ `ui_test_page.gd` の `PLAIN_SCENES` の1行。
#
# ⚠ 浮かぶ数字は `unit_view.gd` の `pop_label()` と同じ形をしているが、⚠ あちらは
#   戦闘のダメージ用で `Balance.adventure.pop_*` を読む。⚠ **本番へ入れるときは
#   共通の部品にまとめること**（⚠ いま共通化すると、⚠ 決まっていない見た目に
#   合わせて戦闘を触ることになる）。

const UI_TEST_PATH: String = "res://tests/ui_test_page.tscn"
const RESOURCE_DISPLAY_SCENE: PackedScene = preload(
	"res://scenes/ui/components/resource_display.tscn"
)

# 1回の獲得で足す量（⚠ デモの見本。⚠ バランスの数値ではない）。
const GAIN_GOLD: int = 120
const GAIN_GEMS: int = 3
const GAIN_MATERIAL: int = 5

# 見せる素材（⚠ items.json に在るID）。
const DEMO_MATERIAL_ID: String = "construction_material_1"

# --- 飛ばす場所（⚠ 3回目の指示で固定にした） ---
#
# ⚠ 画面の大きさに対する割合で置く（⚠ px で置くと窓の大きさで外れる）。
const SOURCE_RATIO: Vector2 = Vector2(0.25, 0.72)

# --- 演出のつまみ（⚠ 本番へ入れるときは Config へ移す） ---
# ポップ：どこまで大きくして、何秒で戻すか。
const POP_SCALE: float = 1.6
const POP_UP_SEC: float = 0.12
const POP_DOWN_SEC: float = 0.22
# 浮かぶ数字：何px上がって何秒で消えるか。
const FLOAT_RISE_PX: float = 44.0
const FLOAT_SEC: float = 0.7
const FLOAT_FONT_SIZE: int = 22
const FLOAT_COLOR: Color = Color(1.0, 0.9, 0.4)
# カウントアップ：何秒かけて数字を回すか。
const COUNT_SEC: float = 0.5
# ⚠ 引いてから飛ぶときに、⚠ 逆方向へどれだけ引くか（⚠ 全体の長さに対する割合）。
const FLY_PULL_RATIO: float = 0.25

# --- 飛ぶルートの候補（2回目の指示） ---
#
# ⚠⚠ 変に見えていた原因は実装のほう：⚠ x と y を **別々の Tween** で動かしていた
#   （⚠ x は等速、⚠ y は「上がって下がる」の2段）。⚠ そのせいで出だしに真上へ跳ね、
#     ⚠ 横へ流れるという、⚠ どの物体の動きでもない軌道になっていた。
#   ⚠ ＝⚠ **1本の t（0→1）で位置を計算する**形に直した。⚠ 軌道は `_route_position()` の1本。
const ROUTE_STRAIGHT: String = "straight"
const ROUTE_ARC_UP: String = "arc_up"
const ROUTE_DETOUR: String = "detour"
const ROUTE_SWOOP: String = "swoop"
const ROUTE_PULL_BACK: String = "pull_back"

const ROUTES: Array[String] = [
	ROUTE_DETOUR,
	ROUTE_ARC_UP,
	ROUTE_SWOOP,
	ROUTE_PULL_BACK,
	ROUTE_STRAIGHT,
]
# ⚠ ラベルは "ui_resdemo_route_" + ルート名 で機械的に引く（AGENTS.md の ui_nav_ と同じ流儀）。
const ROUTE_KEY_PREFIX: String = "ui_resdemo_route_"

# --- 設定の選択肢（⚠ `OptionButton` に並べる。⚠ 添字がそのまま選んだ値） ---
#
# ⚠ 数値だけの選択肢に tr() は通さない（AGENTS.md「数値のみの表示」）。
const COUNT_CHOICES: Array[int] = [1, 3, 5, 8]
const SEC_CHOICES: Array[float] = [0.35, 0.55, 0.8, 1.2]
const ARC_CHOICES: Array[float] = [0.0, 45.0, 90.0, 140.0]
# ⚠⚠ 「始めと終わりは遅くする」（3回目の指示）。⚠ どれも EASE_IN_OUT で、
#   ⚠ 変わるのは **効きの強さ**（⚠ SINE がいちばん穏やか、⚠ QUINT がいちばん強く溜める）。
const EASE_CHOICES: Array[int] = [Tween.TRANS_SINE, Tween.TRANS_CUBIC, Tween.TRANS_QUINT]
const EASE_KEYS: Array[String] = [
	"ui_resdemo_level_low", "ui_resdemo_level_mid", "ui_resdemo_level_high",
]
# 複数飛ばすときの、1個ずつの遅れ（秒）と、出どころの散らし（px）。
const STAGGER_CHOICES: Array[float] = [0.0, 0.06, 0.12]
const SPREAD_CHOICES: Array[float] = [0.0, 40.0, 90.0]
const SPREAD_KEYS: Array[String] = [
	"ui_resdemo_spread_none", "ui_resdemo_spread_small", "ui_resdemo_spread_large",
]

# ⚠ `Stage` は `Scroll` の **外**（⚠ 飛ぶものが一緒にスクロールしないように）。
#   ⚠ `.tscn` では `Scroll` の後に置いてある＝⚠ 前面に出る。⚠ 入力は通す（mouse_filter=2）。
@onready var stage: Control = $Stage
@onready var layout: VBoxContainer = $Scroll/Layout

# ⚠ 表示だけの数（⚠ セーブにも GameManager にも触らない）。
var _gold: int = 1000
var _gems: int = 10
var _materials: int = 20

var _gold_display: ResourceDisplay = null
var _gems_display: ResourceDisplay = null
var _material_display: ResourceDisplay = null
var _source_marker: Panel = null
var _source_label: Label = null

# いま選んでいる設定（⚠ 添字。⚠ 上の選択肢の配列を引く）。
var _route_index: int = 0
var _count_index: int = 1
var _sec_index: int = 1
var _arc_index: int = 2
var _ease_index: int = 1
var _stagger_index: int = 1
var _spread_index: int = 1


func _ready() -> void:
	SceneManager.consume_transfer_data()
	_add_heading("ui_resdemo_title")
	_add_note("ui_resdemo_note")
	_add_action("ui_resdemo_back", _on_back_pressed)

	_build_displays()
	_build_source_marker()

	_add_heading("ui_resdemo_settings")
	_add_option("ui_resdemo_set_route", _route_labels(), _route_index,
		func(i: int) -> void: _route_index = i)
	_add_option("ui_resdemo_set_count", _number_labels(COUNT_CHOICES), _count_index,
		func(i: int) -> void: _count_index = i)
	_add_option("ui_resdemo_set_sec", _float_labels(SEC_CHOICES), _sec_index,
		func(i: int) -> void: _sec_index = i)
	_add_option("ui_resdemo_set_arc", _float_labels(ARC_CHOICES), _arc_index,
		func(i: int) -> void: _arc_index = i)
	_add_option("ui_resdemo_set_ease", _key_labels(EASE_KEYS), _ease_index,
		func(i: int) -> void: _ease_index = i)
	_add_option("ui_resdemo_set_stagger", _float_labels(STAGGER_CHOICES), _stagger_index,
		func(i: int) -> void: _stagger_index = i)
	_add_option("ui_resdemo_set_spread", _key_labels(SPREAD_KEYS), _spread_index,
		func(i: int) -> void: _spread_index = i)

	_add_heading("ui_resdemo_kinds")
	_add_action("ui_resdemo_play", _on_all_pressed)
	_add_action("ui_resdemo_fly", _on_fly_pressed)
	_add_action("ui_resdemo_pop", _on_pop_pressed)
	_add_action("ui_resdemo_float", _on_float_pressed)
	_add_action("ui_resdemo_count", _on_count_pressed)
	_add_action("ui_resdemo_reset", _on_reset_pressed)


# --- 選んでいる値（⚠ 添字から引く口はここ。⚠ 呼ぶ側で配列を触らない） ---

func _route() -> String:
	return ROUTES[clampi(_route_index, 0, ROUTES.size() - 1)]


func _fly_count() -> int:
	return COUNT_CHOICES[clampi(_count_index, 0, COUNT_CHOICES.size() - 1)]


func _fly_sec() -> float:
	return SEC_CHOICES[clampi(_sec_index, 0, SEC_CHOICES.size() - 1)]


func _fly_arc() -> float:
	return ARC_CHOICES[clampi(_arc_index, 0, ARC_CHOICES.size() - 1)]


func _fly_trans() -> int:
	return EASE_CHOICES[clampi(_ease_index, 0, EASE_CHOICES.size() - 1)]


func _fly_stagger() -> float:
	return STAGGER_CHOICES[clampi(_stagger_index, 0, STAGGER_CHOICES.size() - 1)]


func _fly_spread() -> float:
	return SPREAD_CHOICES[clampi(_spread_index, 0, SPREAD_CHOICES.size() - 1)]


# --- 並べ物 ---

# 上に並べる表示欄。⚠ `ResourceDisplay` は .tscn を持つ部品なので必ずシーンから作る
#   （⚠ `.new()` だと中の ValueLabel が無く `_refresh()` が落ちる。⚠ ui_test_page と同じ罠）。
func _build_displays() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Displays"
	row.add_theme_constant_override("separation", 24)
	layout.add_child(row)

	_gold_display = _make_display("GoldDisplay", _gold)
	row.add_child(_gold_display)
	_gems_display = _make_display("GemsDisplay", _gems)
	row.add_child(_gems_display)

	# 素材は「アイコン＋数」で見せる（⚠ 飛ぶアイコンの行き先にもなる）。
	var material_box: HBoxContainer = HBoxContainer.new()
	material_box.name = "MaterialBox"
	material_box.add_child(ItemIcon.create(DEMO_MATERIAL_ID))
	_material_display = _make_display("MaterialDisplay", _materials)
	material_box.add_child(_material_display)
	row.add_child(material_box)


func _make_display(node_name: String, initial: int) -> ResourceDisplay:
	var display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate() as ResourceDisplay
	display.name = node_name
	display.value = initial
	return display


# 飛ばす場所の目印。⚠ 固定の1点から飛ぶことが見えていないと、⚠ ルートを見比べられない。
#
# ⚠ 位置は画面の大きさが決まってから当てる。⚠ `resized` にも繋ぐ
#   （⚠ 1回だけ当てると、⚠ 窓を広げたときに目印と実際の発射点がずれる）。
func _build_source_marker() -> void:
	_source_marker = Panel.new()
	_source_marker.name = "SourceMarker"
	_source_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_source_marker.custom_minimum_size = Vector2(12.0, 12.0)
	_source_marker.size = Vector2(12.0, 12.0)
	stage.add_child(_source_marker)

	_source_label = Label.new()
	_source_label.name = "SourceLabel"
	_source_label.text = tr("ui_resdemo_source")
	_source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_source_label)

	stage.resized.connect(_place_source_marker)
	_place_source_marker()


func _place_source_marker() -> void:
	var origin: Vector2 = _source_local()
	if _source_marker != null:
		_source_marker.position = origin - _source_marker.size * 0.5
	if _source_label != null:
		_source_label.position = origin + Vector2(16.0, -8.0)


# --- 候補1：ポップ（⚠ 数字が一瞬大きくなって戻る） ---
#
# ⚠ 拡大の中心を真ん中にするため pivot_offset を毎回入れ直す
#   （⚠ 入れないと左上を軸に伸びて、⚠ 隣の表示欄へはみ出す）。
func _on_pop_pressed() -> void:
	_gold += GAIN_GOLD
	_gold_display.set_value(_gold)
	_pop(_gold_display)


func _pop(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.tween_property(target, "scale", Vector2.ONE * POP_SCALE, POP_UP_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, POP_DOWN_SEC)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# --- 候補2：浮かぶ数字（⚠ 「+120」が上へ流れて消える） ---
func _on_float_pressed() -> void:
	_gold += GAIN_GOLD
	_gold_display.set_value(_gold)
	_float_text("+%d" % GAIN_GOLD, _global_center_of(_gold_display))


# ⚠ 文字は `Stage`（全画面・入力を通す層）に乗せる。⚠ 表示欄の子にしない
#   （⚠ 子にすると行の幅が伸びて、⚠ 出るたびに隣の表示欄がずれる）。
func _float_text(text: String, global_position: Vector2) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE)
	label.add_theme_color_override("font_color", FLOAT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(label)
	label.position = _to_stage(global_position)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - FLOAT_RISE_PX, FLOAT_SEC)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_SEC)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


# --- 候補3：カウントアップ（⚠ 数字が回って増える） ---
#
# ⚠ `tween_method` は float を渡してくるので、⚠ 表示に入れる前に int() で包む
#   （CLAUDE.md 3番と同じ理由。⚠ 包み忘れると "1120.0" と出る）。
func _on_count_pressed() -> void:
	var from: int = _gold
	_gold += GAIN_GOLD
	_count_up(_gold_display, from, _gold)


func _count_up(display: ResourceDisplay, from: int, to: int) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(
		func(v: float) -> void: display.set_value(int(v)),
		float(from), float(to), COUNT_SEC
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- 候補4：飛ぶアイコン（⚠ 決まった場所から表示欄へ） ---
func _on_fly_pressed() -> void:
	_fly_burst(_material_display, DEMO_MATERIAL_ID, GAIN_MATERIAL, func(amount: int) -> void:
		_materials += amount
		_material_display.set_value(_materials)
		_pop(_material_display)
	)


# ⚠⚠ 複数飛ばす（3回目の指示「複数飛ばすパターンも作る」）。
#
# ⚠ 1個ずつ遅らせて出す。⚠ 出どころは散らすが、⚠ 行き先は同じ（⚠ 吸い込まれる形にする）。
# ⚠⚠ 増える量は「割って、⚠ 足すと必ず合計になる」形で配る
#   （⚠ total/count の丸めで合計がずれると、⚠ 本番へ持っていったときに所持数が合わなくなる）。
func _fly_burst(target: Control, item_id: String, total: int, on_arrive: Callable) -> void:
	var count: int = maxi(1, _fly_count())
	var stagger: float = _fly_stagger()
	var spread: float = _fly_spread()
	for i: int in range(count):
		# ⚠ 端数はここで吸収する（⚠ i 番目までの合計の差＝足すと必ず total）。
		var amount: int = total * (i + 1) / count - total * i / count
		var offset: Vector2 = Vector2.ZERO
		if spread > 0.0:
			offset = Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		_fly_one(target, item_id, offset, stagger * float(i), amount, on_arrive)


# ⚠⚠ 位置は **1本の t（0→1）** から計算する。⚠ x と y を別の Tween で動かさないこと
#   （⚠ 2026-09-07 に人間が実機で「⚠ ルートが変に見える」と見つけた。⚠ 原因はそれ）。
# ⚠⚠ 始めと終わりを遅くする（3回目の指示）＝⚠ `EASE_IN_OUT`。⚠ 強さは設定で変える。
# ⚠ 遅らせるのは `tween_interval()`。⚠ `await` を使わない（⚠ 途中で画面が消えると戻らない）。
func _fly_one(
	target: Control, item_id: String, source_offset: Vector2,
	delay: float, amount: int, on_arrive: Callable
) -> void:
	var icon: ItemIcon = ItemIcon.create(item_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠ 遅れて出るものは、⚠ その間見せない（⚠ 出どころに積まって見える）。
	icon.visible = delay <= 0.0
	stage.add_child(icon)

	var from: Vector2 = _source_local() + source_offset
	var to: Vector2 = _to_stage(_global_center_of(target))
	var route: String = _route()
	var arc: float = _fly_arc()
	icon.position = from

	var tween: Tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: icon.visible = true)
	tween.tween_method(
		func(t: float) -> void: icon.position = _route_position(route, from, to, arc, t),
		0.0, 1.0, _fly_sec()
	).set_trans(_fly_trans()).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(icon.queue_free)
	tween.tween_callback(func() -> void: on_arrive.call(amount))


# ルートごとの、t のときの位置。⚠ ここが唯一の軌道の表。
#
# ⚠ ベジェで書く理由：⚠ 「出だしの向き」と「着地の向き」を制御点で決められるから。
#   ⚠ 放物線の式だと上下にしか膨らませられず、⚠ 「最短距離を迂回する」が書けない。
# ⚠ Vector2 に bezier_interpolate() は無いので手で書く（⚠ float にしか無い）。
func _route_position(route: String, from: Vector2, to: Vector2, arc: float, t: float) -> Vector2:
	var middle: Vector2 = from.lerp(to, 0.5)
	var direction: Vector2 = to - from
	# ⚠ 最短線に対する横の向き。⚠ 長さ0のときに正規化すると NaN になるので逃げる。
	var side: Vector2 = Vector2(-direction.y, direction.x)
	side = side.normalized() if side.length() > 0.001 else Vector2.RIGHT

	match route:
		ROUTE_ARC_UP:
			# 上へ山なり。⚠ 前の実装が出したかった形（⚠ ただし今度は滑らか）。
			return _bezier2(from, middle + Vector2(0.0, -arc), to, t)
		ROUTE_DETOUR:
			# ⚠⚠ 人間の案「最短距離を迂回させて飛ばす」。⚠ 最短線の横へ膨らませる。
			return _bezier2(from, middle + side * arc, to, t)
		ROUTE_SWOOP:
			# S字。⚠ 出だしは上へ、⚠ 着地は横から回り込んで入る。
			return _bezier3(from, from + Vector2(0.0, -arc), to + side * arc, to, t)
		ROUTE_PULL_BACK:
			# ⚠ 一度引いてから飛ぶ（⚠ 出だしの制御点を進む向きの逆に置く）。
			return _bezier3(
				from, from - direction * FLY_PULL_RATIO, to + Vector2(0.0, -arc), to, t
			)
	# ROUTE_STRAIGHT。⚠ 比べるための基準（⚠ 迂回が効いているかはこれと見比べる）。
	return from.lerp(to, t)


func _bezier2(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var inverse: float = 1.0 - t
	return p0 * (inverse * inverse) + p1 * (2.0 * inverse * t) + p2 * (t * t)


func _bezier3(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var inverse: float = 1.0 - t
	return (
		p0 * (inverse * inverse * inverse)
		+ p1 * (3.0 * inverse * inverse * t)
		+ p2 * (3.0 * inverse * t * t)
		+ p3 * (t * t * t)
	)


# --- 全部つなげる（⚠ 本命。⚠ 飛ぶ → 着いたらカウントアップ＋ポップ → 浮かぶ数字） ---
func _on_all_pressed() -> void:
	_fly_burst(_material_display, DEMO_MATERIAL_ID, GAIN_MATERIAL, func(amount: int) -> void:
		var from: int = _materials
		_materials += amount
		_count_up(_material_display, from, _materials)
		_pop(_material_display)
		_float_text("+%d" % amount, _global_center_of(_material_display))
	)
	var gems_from: int = _gems
	_gems += GAIN_GEMS
	_count_up(_gems_display, gems_from, _gems)
	_pop(_gems_display)


func _on_reset_pressed() -> void:
	_gold = 1000
	_gems = 10
	_materials = 20
	_gold_display.set_value(_gold)
	_gems_display.set_value(_gems)
	_material_display.set_value(_materials)


# --- 座標の道具 ---

# ⚠ `Stage` の中の座標に直す。⚠ グローバルのまま position に入れない
#   （⚠ `Stage` が画面の左上に無いときにずれる。⚠ 20-c で踏んだのと同じ形）。
func _to_stage(global_position: Vector2) -> Vector2:
	return stage.get_global_transform().affine_inverse() * global_position


func _global_center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# 飛ばす場所（⚠ `Stage` の中の座標）。⚠ 割合で置くので窓の大きさが変わっても付いてくる。
func _source_local() -> Vector2:
	var size: Vector2 = stage.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = get_viewport().get_visible_rect().size
	return size * SOURCE_RATIO


func _on_back_pressed() -> void:
	SceneManager.change_scene(UI_TEST_PATH)


# --- 並べる道具（⚠ ボタンと設定を作る口はここ。⚠ ui_test_page と同じ流儀） ---

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


func _add_action(key: String, handler: Callable) -> void:
	var button: UiButton = UiButton.new()
	button.name = "Action_" + key
	button.text = tr(key)
	button.pressed.connect(handler)
	layout.add_child(button)


# 設定1行（⚠ 見出し ＋ `OptionButton`）。⚠ 選ぶと `on_selected` に添字が渡る。
#
# ⚠ `OptionButton` は装備画面（ルーンの移動）で使っている前例に合わせている。
func _add_option(
	label_key: String, choices: Array[String], initial: int, on_selected: Callable
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Setting_" + label_key
	var label: Label = Label.new()
	label.name = "Label"
	label.text = tr(label_key)
	label.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(label)

	var option: OptionButton = OptionButton.new()
	option.name = "Option"
	for i: int in range(choices.size()):
		option.add_item(choices[i], i)
	option.select(clampi(initial, 0, maxi(0, choices.size() - 1)))
	option.item_selected.connect(func(index: int) -> void: on_selected.call(index))
	row.add_child(option)
	layout.add_child(row)


# --- 選択肢のラベル（⚠ 数値はそのまま、⚠ 語は tr()） ---

func _route_labels() -> Array[String]:
	var result: Array[String] = []
	for route: String in ROUTES:
		result.append(tr(ROUTE_KEY_PREFIX + route))
	return result


func _number_labels(values: Array[int]) -> Array[String]:
	var result: Array[String] = []
	for value: int in values:
		result.append(str(value))
	return result


func _float_labels(values: Array[float]) -> Array[String]:
	var result: Array[String] = []
	for value: float in values:
		result.append("%.2f" % value)
	return result


func _key_labels(keys: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for key: String in keys:
		result.append(tr(key))
	return result
