class_name ResourceGainEffect
extends CanvasLayer

# リソースが増えたときの演出（2026-09-09・人間の指示
#   「拠点以外でも すべての画面で 専用のコンポーネントに分離して呼び出す形にするべき」）。
#
# ⚠⚠ **呼ぶのは「出来事を知っている側」**。⚠ `GameManager.resource_changed` に
#   直接ぶら下げないこと。⚠ そうすると (1) 減ったときにも飛ぶ (2) セーブを読んだ瞬間に
#   一斉に飛ぶ (3) 出どころが分からない、の3つが起きる。
#
# ⚠ 起動時に `SceneManager` が1つだけ作る（⚠ `_spawn_debug_overlay()` の隣）。
#   ⚠ Autoload は増やさない（AGENTS.md の6つを守る）。⚠ `root` に付くので画面遷移で消えない。
#
# ⚠ 着地先の決め方は3段。⚠ 画面ごとに `if` を書かないため。
#   1. `to_target` を渡されたらそこへ（⚠ ダンジョンの鞄のように `ResourceDisplay` が無い所）
#   2. 無ければ同じ `resource_id` の `ResourceDisplay` を今の画面から探す
#   3. それも無ければ**飛ばさず、浮かぶ数字だけ**出す
#
# ⚠⚠ 見た目の値は Theme が持つ（`tools/theme_builder.gd` の `_build_resource_gain()`）。
#   ⚠ ここに秒数も色も書かない。⚠ **いまの値は仮**で、人間のモックが決まったら
#   ⚠ `theme_builder.gd` の1箇所を差し替える。

# ⚠ `ResourceDisplay` が自分で入るグループ。⚠ 着地先はここから探す。
const GROUP_DISPLAY: StringName = &"resource_display"

# ⚠ 画面より上。⚠ モーダル（`ModalDialog`）より上にしないこと
#   （⚠ 宝箱の窓の上を数字が横切ると読めない）。
const LAYER_INDEX: int = 50

# ⚠ 飛ぶ軌道。⚠ Theme の定数 `route` がこの並びの添字を指す。
#   ⚠ 中身はデモ（`tests/resource_gain_demo.gd`）と同じ式。⚠ デモはリリース前に消える（宿題77）。
enum Route { STRAIGHT, ARC_UP, DETOUR, SWOOP, PULL_BACK }

# ⚠ 「引いてから飛ぶ」で、⚠ 出だしに戻る割合。
const PULL_RATIO: float = 0.25

static var _instance: ResourceGainEffect = null

# ⚠ 飛ぶものを載せる面。⚠ CanvasLayer は Control ではないので Theme を引けない。
#   ⚠ 値を引くのも、⚠ 子を載せるのもこの Control。
var field: Control = null


static func spawn_into(root: Node) -> ResourceGainEffect:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: ResourceGainEffect = ResourceGainEffect.new()
	made.name = "ResourceGainEffect"
	# ⚠ 相手が子を組み立てている最中だと `add_child()` は失敗する（⚠ 実測・赤が出る）。
	#   ⚠ 遅らせるので、⚠ 呼んだ直後は `field` がまだ null。⚠ 1フレーム待つこと。
	root.add_child.call_deferred(made)
	_instance = made
	return made


# ⚠ 出せる状態か。⚠ `field` は `_ready()` で作るので、⚠ 生やした直後は false。
static func is_ready() -> bool:
	return _instance != null and is_instance_valid(_instance) and _instance.field != null


# ⚠⚠ 呼び口はこの1本。
#   ⚠ `from_global` を省くと着地先の少し下から出る（⚠ 出どころが無い出来事）。
#   ⚠ `amount` が 0 以下なら何もしない（⚠ 減ったときに呼ばれても飛ばさない）。
static func play(
	resource_id: String,
	amount: int,
	from_global: Vector2 = Vector2.INF,
	to_target: Control = null,
) -> void:
	if amount <= 0:
		return
	if not is_ready():
		return
	_instance._play(resource_id, amount, from_global, to_target)


# ⚠ 報酬の Dictionary をまとめて流す（⚠ 宝箱・ポモドーロ・戦闘で形が同じ）。
#   ⚠ `gold` / `gems` / `stamina` / `materials` を見る。
#   ⚠ `inventory` は個数ではなく品物なので、⚠ ここでは扱わない。
#
# ⚠⚠ 何種類も同時に増えるのが**ふつう**（⚠ 宝箱は金＋ジェム＋素材3種が一度に入る）。
#   ⚠ モックの決定に合わせて **種類ごとに時間をずらし**、⚠ 種類が多いときは
#   ⚠ 1種あたりの個数を絞り、⚠ **浮かぶ数字は先頭の1種類だけ**にする。
#   ⚠ そうしないと画面が数字だらけになる。
static func play_rewards(rewards: Dictionary, from_global: Vector2 = Vector2.INF) -> void:
	if not is_ready():
		return

	var entries: Array[Array] = []
	for key: String in [GameStateKeys.GOLD, GameStateKeys.GEMS, GameStateKeys.STAMINA]:
		var amount: int = int(rewards.get(key, 0))
		if amount > 0:
			entries.append([key, amount])
	var materials: Variant = rewards.get(GameStateKeys.MATERIALS, {})
	if materials is Dictionary:
		for material_id: Variant in (materials as Dictionary).keys():
			var material_amount: int = int((materials as Dictionary)[material_id])
			if material_amount > 0:
				entries.append([str(material_id), material_amount])

	if entries.is_empty():
		return
	_instance._play_series(entries, from_global)


func _ready() -> void:
	layer = LAYER_INDEX
	field = Control.new()
	field.name = "Field"
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)


# ⚠ 何種類かをまとめて。⚠ 種類ごとにずらし、⚠ 浮かぶ数字は先頭だけ。
func _play_series(entries: Array[Array], from_global: Vector2) -> void:
	var type_gap: float = float(_constant(&"type_stagger_ms")) / 1000.0
	for i: int in range(entries.size()):
		var resource_id: String = str(entries[i][0])
		var amount: int = int(entries[i][1])
		var delay: float = type_gap * float(i)
		var show_number: bool = (i == 0)
		if delay <= 0.0:
			_play(resource_id, amount, from_global, null, entries.size(), show_number)
			continue
		# ⚠ 待ってから出す。⚠ Tween は面に付ける（⚠ 画面が変わっても消えない）。
		var tween: Tween = field.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			_play(resource_id, amount, from_global, null, entries.size(), show_number))


# ⚠ 飛ぶ個数は増える量で決まる。⚠ 種類が多いときは絞る（⚠ モックの決定）。
func _count_for(amount: int, types: int) -> int:
	var count: int = _constant(&"count_1")
	if amount >= _constant(&"step_4"):
		count = _constant(&"count_4")
	elif amount >= _constant(&"step_3"):
		count = _constant(&"count_3")
	elif amount >= _constant(&"step_2"):
		count = _constant(&"count_2")
	if types >= _constant(&"types_busy"):
		count = mini(count, _constant(&"count_busy"))
	return maxi(1, count)


func _play(
	resource_id: String,
	amount: int,
	from_global: Vector2,
	to_target: Control,
	types: int = 1,
	show_number: bool = true,
) -> void:
	if field == null:
		return

	var target: Control = to_target if to_target != null else _find_display(resource_id)
	var to_point: Vector2 = _center_of(target) if target != null else Vector2.INF

	var from_point: Vector2 = from_global
	if from_point == Vector2.INF:
		# ⚠ 出どころが無い出来事。⚠ 着地先の少し下から出す。
		if to_point == Vector2.INF:
			return
		from_point = to_point + Vector2(0.0, float(_constant(&"rise")))

	if show_number:
		_spawn_float(resource_id, from_point, amount)

	if to_point == Vector2.INF:
		# ⚠ 着地先が今の画面に無い。⚠ 浮かぶ数字だけで終わる（⚠ 飛ばさない）。
		return

	# ⚠ 表示欄でない着地先（⚠ ダンジョンの鞄のマス）は山を低くする。
	var arc: float = float(_constant(&"arc"))
	if not (target is ResourceDisplay):
		arc = float(_constant(&"arc_cell"))
	arc = minf(arc, float(_constant(&"arc_max")))

	var count: int = _count_for(amount, types)
	var spread: float = float(_constant(&"spread"))
	var stagger: float = float(_constant(&"stagger_ms")) / 1000.0
	# ⚠ 着地1回ごとに増える分。⚠ 端数は最後の1個に寄せず、⚠ 1以上を保つ。
	var step: int = maxi(1, int(round(float(amount) / float(count))))
	for i: int in range(count):
		var offset: Vector2 = Vector2.ZERO
		if spread > 0.0 and count > 1:
			# ⚠ 出どころを円に散らす。⚠ 0.6 はモックと同じ初期の角度。
			var angle: float = TAU * float(i) / float(count) + 0.6
			offset = Vector2(cos(angle), sin(angle)) * spread
		_spawn_flyer(resource_id, from_point + offset, to_point, arc, stagger * float(i), target, step)


# --- 探す ---

func _find_display(resource_id: String) -> Control:
	if resource_id == "":
		return null
	for node: Node in field.get_tree().get_nodes_in_group(GROUP_DISPLAY):
		if not (node is ResourceDisplay):
			continue
		var display: ResourceDisplay = node
		if display.resource_id != resource_id:
			continue
		if not display.is_visible_in_tree():
			continue
		return display
	return null


func _center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# --- 出すもの ---

# ⚠ 浮かぶ数字（`+120` が上へ流れて消える）。⚠ アイコンを左に付ける（⚠ モックの形）。
func _spawn_float(resource_id: String, at: Vector2, amount: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(row)

	var texture: Texture2D = IconTextures.for_resource(resource_id)
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = float(_constant(&"float_font"))
		icon.custom_minimum_size = Vector2(side, side)
		row.add_child(icon)

	var label: Label = Label.new()
	label.text = "+%d" % amount
	label.theme_type_variation = &"GainLabel"
	label.add_theme_font_size_override("font_size", _constant(&"float_font"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	# ⚠ 1フレーム待たないと大きさが決まらず、⚠ 真ん中に置けない。
	await field.get_tree().process_frame
	if not is_instance_valid(row):
		return
	row.modulate = _color(&"flyer")
	row.global_position = at - row.size * 0.5

	var rise: float = float(_constant(&"rise"))
	var seconds: float = float(_constant(&"float_ms")) / 1000.0
	var tween: Tween = field.create_tween().set_parallel(true)
	tween.tween_property(row, "global_position", row.global_position - Vector2(0.0, rise), seconds)
	tween.tween_property(row, "modulate:a", 0.0, seconds)
	tween.chain().tween_callback(row.queue_free)


# ⚠ 飛ぶアイコン1つ。⚠ 位置は1本の t（0→1）から出す（⚠ 軌道は `_route_position()` の1本）。
#   ⚠ 着いたら着地先を跳ねさせる（⚠ 表示欄なら数字も回して増やす）。
func _spawn_flyer(
	resource_id: String,
	from: Vector2,
	to: Vector2,
	arc: float,
	delay: float,
	target: Control,
	step: int,
) -> void:
	var icon: TextureRect = TextureRect.new()
	icon.texture = IconTextures.for_resource(resource_id)
	if icon.texture == null:
		icon.queue_free()
		return
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side: float = float(_constant(&"icon"))
	icon.custom_minimum_size = Vector2(side, side)
	icon.size = icon.custom_minimum_size
	icon.modulate = _color(&"flyer")
	field.add_child(icon)
	icon.global_position = from - icon.size * 0.5
	icon.visible = false

	var route: int = _constant(&"route")
	var seconds: float = float(_constant(&"fly_ms")) / 1000.0
	var half: Vector2 = icon.size * 0.5

	var tween: Tween = field.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void: icon.visible = true)
	tween.tween_method(
		func(t: float) -> void:
			icon.global_position = _route_position(route, from, to, arc, t) - half,
		0.0, 1.0, seconds,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(icon.queue_free)
	tween.tween_callback(func() -> void: _land(target, step))


# ⚠ 着いたときの反応。⚠ ふくらみは**増える量で変えない**（⚠ モックの決定）。
#   ⚠ 表示欄なら数字も回して増やす。⚠ 表示欄でない着地先（鞄のマス）は跳ねるだけ。
func _land(target: Control, step: int) -> void:
	if target == null or not is_instance_valid(target):
		return

	var scale_to: float = float(_constant(&"pop_percent")) / 100.0
	var seconds: float = float(_constant(&"pop_ms")) / 1000.0
	# ⚠ 真ん中を軸に膨らませる（⚠ 左上を軸にすると右下へずれて見える）。
	target.pivot_offset = target.size * 0.5
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2.ONE * scale_to, seconds * 0.4)
	tween.tween_property(target, "scale", Vector2.ONE, seconds * 0.6)

	if target is ResourceDisplay:
		(target as ResourceDisplay).play_gain(step, float(_constant(&"count_ms")) / 1000.0)


# --- 軌道 ---

func _route_position(route: int, from: Vector2, to: Vector2, arc: float, t: float) -> Vector2:
	var middle: Vector2 = from.lerp(to, 0.5)
	var direction: Vector2 = to - from
	# ⚠ 最短線に対する横の向き。⚠ 長さ0のときに正規化すると NaN になるので逃げる。
	var side: Vector2 = Vector2(-direction.y, direction.x)
	side = side.normalized() if side.length() > 0.001 else Vector2.RIGHT

	match route:
		Route.ARC_UP:
			return _bezier2(from, middle + Vector2(0.0, -arc), to, t)
		Route.DETOUR:
			return _bezier2(from, middle + side * arc, to, t)
		Route.SWOOP:
			return _bezier3(from, from + Vector2(0.0, -arc), to + side * arc, to, t)
		Route.PULL_BACK:
			return _bezier3(from, from - direction * PULL_RATIO, to + Vector2(0.0, -arc), to, t)
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


# --- Theme から引く ---

func _constant(name: StringName) -> int:
	return field.get_theme_constant(name, &"ResourceGainEffect")


func _color(name: StringName) -> Color:
	return field.get_theme_color(name, &"ResourceGainEffect")
