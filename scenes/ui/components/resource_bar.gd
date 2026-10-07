class_name ResourceBar
extends HBoxContainer

# 右上に出す資源のひとまとまり（2026-09-09・人間の指示
#   「資源は、右上に表示する / モックの資源みたいにコンパクトに」
#   「拠点のすべての素材を右上に / あともっと小さくしてほしい」）。
#
# ⚠ 通貨は **金・ジェム・スタミナ の3つ**（人間の決定）。
# ⚠⚠ **素材16件を足せる**（`show_materials`）。⚠ 出すのは拠点だけ
#   （⚠ 他の画面まで16件並べると、⚠ 見出しの行が資源で埋まる）。
# ⚠⚠ 折り返す器（`HFlowContainer`）は **`show_materials` のときだけ中に作る**。
#   ⚠ 素材16件＋通貨3で19個並ぶので、⚠ 1行では 1280 に入らないため。
#   ⚠⚠ **器そのものを `HFlowContainer` にしてはいけない**（⚠ 2026-09-09 に実測して戻した）。
#   ⚠ 折り返す器は「⚠ 最小＝1列に縦積みした高さ」を返すので、⚠ `ScreenHeader`（横並び）に
#   ⚠ 入れると**チップが縦に積まれる**。⚠ 倉庫が 712 → **824（+104 はみ出し）**になった。
#
# ⚠ 1つ1つは `ResourceDisplay` を `ResourceChip` の面で包んだもの。
#   ⚠⚠ **`ResourceDisplay` を使うのが要点**。⚠ そうすると増えたときの演出
#   （`ResourceGainEffect`）が `resource_id` から着地先として引ける。
#   ⚠ ＝**素材が増えても飛ぶ先ができる**。
# ⚠ 名前の字は出さない（⚠ 絵と数字だけ）。⚠ 19個に名前を付けると入らない。
# ⚠ 中身はコードで作る（⚠ `.tscn` に子を置くとバックグラウンドの Godot に
#   ⚠ 消されたことがある。⚠ タイマーの輪で1回踏んだ）。
# ⚠ 2画面以上で使うので `scenes/ui/components/`（AGENTS.md）。

# ⚠ 通貨の並び順。⚠ ここを増やすと出るものが増える（⚠ 画面ごとに分岐を書かない）。
const CURRENCY_IDS: Array[String] = [
	GameStateKeys.GOLD,
	GameStateKeys.GEMS,
	GameStateKeys.STAMINA,
]

const RESOURCE_DISPLAY_SCENE: PackedScene = preload(
	"res://scenes/ui/components/resource_display.tscn"
)

# 素材16件も並べるか。⚠ 拠点だけ true。
@export var show_materials: bool = false

# 通貨3つを並べるか（2026-09-09）。
# ⚠⚠ 通貨は **`ResourceHud` が画面をまたいで常駐で出す**ようになった。
#   ⚠ 拠点はその上に素材だけを足すので、⚠ ここを false にして二重に出さない。
@export var show_currencies: bool = true

# ⚠⚠ 素材を絞る（2026-09-21・人間の指示「⚠ 装備の素材もリソースにしてほしい」）。
#   ⚠ 空なら**持っている素材を全部**（⚠ 拠点の今までどおり）。
#   ⚠ 入れると**その ID だけ**を、⚠ **並べた順**に出す（⚠ 装備画面＝鍛冶4段＋装飾）。
# ⚠ 絞ったときは **0 個でも出す**（⚠ 「いくつ必要か」を見る画面なので、⚠ 0 が消えると
#   ⚠ 何が足りないか分からなくなる）。⚠ 絞らないときは今までどおり 0 は出さない。
# ⚠⚠ あとから渡してもよい。⚠ 子の `_ready()` は親より先に走るので、
#   ⚠ 画面側が `_ready()` の中で渡すと間に合わない（⚠ 2026-09-21 に踏んだ）。
# ⚠ 素材を右に寄せるか（2026-09-21）。⚠ 拠点は右上なので true。
#   ⚠ 装備画面は左ぞろえの列の中なので false（⚠ まわりと揃わないと浮く）。
@export var material_align_end: bool = true

# ⚠ 素材のチップを押すと入手先の窓（2026-10-06・人間「⚠ 素材関連は全部広げる」・`NAV-19`）。⚠ 拠点だけ true。
#   ⚠ 通貨のチップは押せない（⚠ 入手先の窓は品のためのもの）。
@export var open_sources: bool = false

# ⚠ 素材を折り返すか（⚠ 見出しの中に置くときは false＝横一列。⚠ 折り返す器は幅が1チップぶんに縮むため）。
@export var wrap_materials: bool = true

@export var material_ids: PackedStringArray = PackedStringArray():
	set(value):
		material_ids = value
		if is_node_ready() and show_materials:
			_rebuild_materials()

# resource_id -> ResourceDisplay
var _displays: Dictionary = {}
# material_id -> PanelContainer（0 個になったら隠す器）
var _material_chips: Dictionary = {}

# ⚠ チップを実際にぶら下げる器。⚠ ふつうは自分自身。
#   ⚠ 素材を出すときだけ、⚠ 中に折り返す器を1つ作ってそこへ入れる。
var _slot: Container = null


func _ready() -> void:
	theme_type_variation = &"ChipRow"
	_slot = self
	if show_materials and wrap_materials:
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Flow"
		flow.theme_type_variation = &"ChipFlow"
		# ⚠ 右上に置くので右端に揃える（⚠ 折り返した2行目も右に揃う）。
		flow.alignment = (
			FlowContainer.ALIGNMENT_END if material_align_end else FlowContainer.ALIGNMENT_BEGIN
		)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flow)
		_slot = flow
	else:
		alignment = BoxContainer.ALIGNMENT_END

	if show_currencies:
		for resource_id: String in CURRENCY_IDS:
			_make_chip(resource_id)
		GameManager.resource_changed.connect(_on_resource_changed)
	if show_materials:
		GameManager.material_changed.connect(_on_material_changed)
		_rebuild_materials()
		return
	_refresh_all()


# ⚠ 素材のチップを作り直す。⚠ 絞りを渡し直したときもここを通る。
#   ⚠ `remove_child()` してから `queue_free()` する（`CLAUDE.md` 5番）。
func _rebuild_materials() -> void:
	for material_id: Variant in _material_chips.keys():
		var chip: Variant = _material_chips[material_id]
		if chip is Node and is_instance_valid(chip):
			_slot.remove_child(chip as Node)
			(chip as Node).queue_free()
		_displays.erase(str(material_id))
	_material_chips.clear()
	# ⚠ 絞っているときは、⚠ 0 個のぶんも先に器を作る（⚠ 並びを固定するため）。
	for material_id: String in material_ids:
		_material_chips[material_id] = _make_chip(material_id)
	_refresh_all()


# ⚠ チップ1つ。⚠ 面（枠）＋ `ResourceDisplay`（絵＋数字）。
#   ⚠⚠ 通貨だけ別の面（`CurrencyChip`）を使う（2026-09-09・人間の決定
#   「⚠ 参考画像のはみ出す形は通貨3つだけ」）。⚠ 左の余白がほぼ0で、⚠ 丸が大きい。
#   ⚠ 素材16件は小さいまま（⚠ 19個が同じ大きさで並ぶと右上が埋まる）。
func _make_chip(resource_id: String) -> PanelContainer:
	var is_currency: bool = resource_id in CURRENCY_IDS
	var variation: StringName = &"CurrencyChip" if is_currency else &"ResourceChip"
	var chip: PanelContainer = PanelContainer.new()
	chip.name = "Chip_" + resource_id
	chip.theme_type_variation = variation
	# ⚠ 面が押せてしまうと、⚠ 後ろのボタンが押せなくなる。
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(chip)

	var display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate()
	display.name = "Value"
	display.resource_id = resource_id
	display.theme_type_variation = &"ChipRow"
	chip.add_child(display)

	# ⚠ チップの中だけ小さくする（⚠ 大きさも文字も Theme が持つ）。
	var side: int = chip.get_theme_constant(&"icon", variation)
	var icon: TextureRect = display.get_node("Icon")
	# ⚠⚠ **これが無いと大きさの指定が丸ごと効かない**（2026-09-09 に判明）。
	#   ⚠ 線画の SVG は 48 x 48 で読み込まれる。⚠ 既定の `EXPAND_KEEP_SIZE` だと
	#   ⚠ 最小サイズが**テクスチャの 48px** になり、⚠ `custom_minimum_size` は
	#   ⚠ 「それ以上」の意味しか持たないので **48px のまま**になる。
	#   ⚠ 24 -> 20 -> 16 -> 12 と下げても1pxも変わらなかったのはこのため。
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(side, side)
	# ⚠ 絵に色を着せる（2026-09-09・人間の指示「⚠ 折り返しても分かりやすいよう色もつけといて」）。
	#   ⚠ 線画は白1色なので、⚠ 19個が同じ白だと折り返した先で見分けが付かない。
	icon.modulate = _color_of(resource_id, chip)
	var value_label: Label = display.get_node("ValueLabel")
	value_label.theme_type_variation = &"ChipValueLabel"
	if open_sources and not is_currency:
		# ⚠ 右端に「＋」（10-06・人間「⚠ 気づかない　プラスマークを付けて　ソシャゲのように」）。⚠ 記号なので tr() を通さない。
		var plus: Label = Label.new()
		plus.name = "PlusMark"
		plus.theme_type_variation = &"ChipPlusLabel"
		plus.text = "+"
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		display.add_child(plus)
		# ⚠ チップ全体を押せる当たり。⚠ 縁は出さない（10-06・人間「⚠ 素材周りにふちがつくのではなく」）＝`HitButton` を使わない
		#   （⚠ `UiButton.attach_hit()` は縁を足す作り）。⚠ 触れたら「＋」が動く。
		var hit: Button = Button.new()
		hit.name = "Hit"
		hit.theme_type_variation = &"ChipHitButton"
		hit.tooltip_text = tr("ui_source_open")
		hit.pressed.connect(_on_chip_pressed.bind(resource_id))
		hit.mouse_entered.connect(_on_plus_hover.bind(plus, true))
		hit.mouse_exited.connect(_on_plus_hover.bind(plus, false))
		chip.add_child(hit)
		chip.move_child(hit, 0)
		UiButton._ignore_mouse(chip, hit)
		_start_plus_pulse(plus, _plus_count)
		_plus_count += 1

	_displays[resource_id] = display
	return chip


# --- 「＋」の動き（2026-10-06・人間「⚠ プラスボタンが押せると気づかせるためのものをつけて」） ---
#   ⚠ 脈打ち＝ときどき少し大きくなって戻る（⚠ 並んだ「＋」が同時に動かないよう、順にずらす）。
#   ⚠ 触れたら＝灯りの色で大きく（⚠ 脈打ちは止める）・離れたら戻して脈打ちを再開。
#   ⚠ 値は Theme（`ChipPlusLabel` の定数）。⚠ Tween は「＋」に付ける（⚠ 画面と一緒に消える）。
var _plus_count: int = 0
const PLUS_TWEEN_META: StringName = &"plus_pulse"


func _plus_constant(plus: Label, name: StringName) -> float:
	return float(plus.get_theme_constant(name, &"ChipPlusLabel"))


func _start_plus_pulse(plus: Label, order: int) -> void:
	var period: float = _plus_constant(plus, &"pulse_period_ms") / 1000.0
	var seconds: float = _plus_constant(plus, &"pulse_ms") / 1000.0
	if period <= 0.0 or seconds <= 0.0:
		return
	var grow: Vector2 = Vector2.ONE * _plus_constant(plus, &"pulse_scale_pct") / 100.0
	var tween: Tween = plus.create_tween()
	tween.set_loops()
	tween.tween_interval(maxf(0.01, period - seconds + _plus_constant(plus, &"pulse_stagger_ms") / 1000.0 * float(order % 4)))
	tween.tween_callback(_center_pivot.bind(plus))
	tween.tween_property(plus, "scale", grow, seconds * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(plus, "scale", Vector2.ONE, seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	plus.set_meta(PLUS_TWEEN_META, tween)


func _center_pivot(plus: Label) -> void:
	plus.pivot_offset = plus.size * 0.5


func _on_plus_hover(plus: Label, entered: bool) -> void:
	if not is_instance_valid(plus):
		return
	var running: Variant = plus.get_meta(PLUS_TWEEN_META, null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	plus.theme_type_variation = &"ChipPlusLabelHover" if entered else &"ChipPlusLabel"
	_center_pivot(plus)
	var target: Vector2 = Vector2.ONE * (_plus_constant(plus, &"hover_scale_pct") / 100.0 if entered else 1.0)
	var tween: Tween = plus.create_tween()
	tween.tween_property(plus, "scale", target, _plus_constant(plus, &"hover_ms") / 1000.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if entered:
		plus.set_meta(PLUS_TWEEN_META, tween)
	else:
		tween.tween_callback(_start_plus_pulse.bind(plus, 0))


func _on_chip_pressed(resource_id: String) -> void:
	var _window: ModalDialog = ItemSourceWindow.open(self, resource_id)


# ⚠ その資源の色。⚠ 通貨はIDそのもの、⚠ 素材は系統（建築・修練・鍛冶・装飾）で引く。
#   ⚠ 系統の綴りをここに書き起こさない。⚠ `IconTextures.MATERIAL_SERIES` の1本で引く
#   （⚠ 絵の振り分けと色の振り分けが互いにずれないように）。
#   ⚠ 表に無いIDは白のまま（⚠ 色を決めていない資源が増えても落ちない）。
func _color_of(resource_id: String, chip: PanelContainer) -> Color:
	return icon_color_for(resource_id, chip)


# ⚠⚠ 資源の絵に着せる色（2026-10-06・人間「⚠ 上にあるアイコンの色が全部白いので見分けがつかない」）。
#   ⚠ **素材は段の色**（⚠ 持ち物の枠線と同じ＝`ItemIcon.grade_of()` → `IconConfig.color_of_grade()`。白・青・紫・金）。
#     ⚠ 前は系統の色だった＝⚠ 見出しには同じ系統の4段が並ぶので**4つとも同じ色**で見分けられなかった。
#   ⚠ 通貨は今までどおり Theme の色（`ResourceChip` の名前つきの色）。⚠ 決めていなければ `fallback`。
#   ⚠ 画像素材を置いた品は色を着せない（`IconTextures.tint_for()`）。
#   ⚠ チップ・増えたときに飛ぶ絵・戦闘の結果の3か所がここを通す（⚠ 色が食い違わない）。
static func icon_color_for(resource_id: String, theme_owner: Control, fallback: Color = Color.WHITE) -> Color:
	var color: Color = fallback
	if GameManager.get_material_tier(resource_id) > 0 and Balance.icon != null:
		color = Balance.icon.color_of_grade(int(ItemIcon.grade_of(resource_id, 0).get(ItemIcon.RESULT_GRADE, 1)))
	else:
		var key: StringName = StringName(color_key_for(resource_id))
		if theme_owner != null and theme_owner.has_theme_color(key, &"ResourceChip"):
			color = theme_owner.get_theme_color(key, &"ResourceChip")
	return IconTextures.tint_for(resource_id, color)


# ⚠ その資源の色を Theme から引くときの名前。⚠ 通貨はIDそのもの、⚠ 素材は系統。
#   ⚠⚠ **増えたときの演出（`ResourceGainEffect`）も同じ口を使う**。
#   ⚠ 2箇所で別々に判定すると、⚠ 右上のチップと飛ぶアイコンで色が食い違う。
static func color_key_for(resource_id: String) -> String:
	for prefix: Variant in IconTextures.MATERIAL_SERIES.keys():
		if resource_id.begins_with(str(prefix)):
			return str(IconTextures.MATERIAL_SERIES[prefix])
	return resource_id


func _refresh_all() -> void:
	var state: Dictionary = GameManager.get_state()
	if show_currencies:
		for resource_id: String in CURRENCY_IDS:
			if resource_id == GameStateKeys.STAMINA:
				_refresh_stamina(state)
				continue
			_displays[resource_id].set_value(int(state.get(resource_id, 0)))

	if not show_materials:
		return
	# ⚠ 0 個の素材は出さない（⚠ 拠点の下段と同じ決まり。⚠ 手に入った時点で出る）。
	var materials: Dictionary = state.get(GameStateKeys.MATERIALS, {})
	if not material_ids.is_empty():
		# ⚠ 絞っているときは並べた順に。⚠ 0 個でも出す（⚠ 上の注記）。
		for material_id: String in material_ids:
			_set_material(material_id, int(materials.get(material_id, 0)))
		return
	for material_id: Variant in materials.keys():
		_set_material(str(material_id), int(materials[material_id]))


func _refresh_stamina(state: Dictionary) -> void:
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	_displays[GameStateKeys.STAMINA].set_value_with_max(
		int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
		int(stamina.get(GameStateKeys.STAMINA_MAX, 0)),
	)


# ⚠ 素材1件。⚠ 0 になったら器ごと隠す（⚠ 消さない。⚠ また増えたときに作り直さないため）。
func _set_material(material_id: String, amount: int) -> void:
	var pinned: bool = material_ids.has(material_id)
	if not _material_chips.has(material_id):
		# ⚠ 絞っていない画面は、⚠ 0 個の素材の器を作らない（⚠ 手に入った時点で出る）。
		if amount <= 0 and not pinned:
			return
		_material_chips[material_id] = _make_chip(material_id)
	_displays[material_id].set_value(amount)
	# ⚠ 絞った画面は 0 個でも出したままにする（⚠ 何が足りないかを見る画面のため）。
	(_material_chips[material_id] as PanelContainer).visible = pinned or amount > 0


# ⚠⚠ スタミナだけ第2引数が `current` の `int` 単体で、⚠ `max` を含まない（AGENTS.md）。
#   ⚠ `set_value_with_max(current, 0)` と書くと `10/0` と出る。⚠ 状態から読み直す。
func _on_resource_changed(resource_type: String, new_value: Variant) -> void:
	if not _displays.has(resource_type):
		return
	if resource_type == GameStateKeys.STAMINA:
		_refresh_stamina(GameManager.get_state())
		return
	_displays[resource_type].set_value(int(new_value))


func _on_material_changed(material_id: String, new_amount: int) -> void:
	_set_material(material_id, new_amount)
