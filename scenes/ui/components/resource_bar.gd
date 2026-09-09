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
	if show_materials:
		var flow: HFlowContainer = HFlowContainer.new()
		flow.name = "Flow"
		flow.theme_type_variation = &"ChipFlow"
		# ⚠ 右上に置くので右端に揃える（⚠ 折り返した2行目も右に揃う）。
		flow.alignment = FlowContainer.ALIGNMENT_END
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flow)
		_slot = flow
	else:
		alignment = BoxContainer.ALIGNMENT_END

	for resource_id: String in CURRENCY_IDS:
		_make_chip(resource_id)

	GameManager.resource_changed.connect(_on_resource_changed)
	if show_materials:
		GameManager.material_changed.connect(_on_material_changed)
	_refresh_all()


# ⚠ チップ1つ。⚠ 面（枠）＋ `ResourceDisplay`（絵＋数字）。
func _make_chip(resource_id: String) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.name = "Chip_" + resource_id
	chip.theme_type_variation = &"ResourceChip"
	# ⚠ 面が押せてしまうと、⚠ 後ろのボタンが押せなくなる。
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(chip)

	var display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate()
	display.name = "Value"
	display.resource_id = resource_id
	display.theme_type_variation = &"ChipRow"
	chip.add_child(display)

	# ⚠ チップの中だけ小さくする（⚠ 大きさも文字も Theme が持つ）。
	var side: int = chip.get_theme_constant(&"icon", &"ResourceChip")
	var icon: TextureRect = display.get_node("Icon")
	icon.custom_minimum_size = Vector2(side, side)
	var value_label: Label = display.get_node("ValueLabel")
	value_label.theme_type_variation = &"ChipValueLabel"

	_displays[resource_id] = display
	return chip


func _refresh_all() -> void:
	var state: Dictionary = GameManager.get_state()
	for resource_id: String in CURRENCY_IDS:
		if resource_id == GameStateKeys.STAMINA:
			_refresh_stamina(state)
			continue
		_displays[resource_id].set_value(int(state.get(resource_id, 0)))

	if not show_materials:
		return
	# ⚠ 0 個の素材は出さない（⚠ 拠点の下段と同じ決まり。⚠ 手に入った時点で出る）。
	var materials: Dictionary = state.get(GameStateKeys.MATERIALS, {})
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
	if not _material_chips.has(material_id):
		if amount <= 0:
			return
		_material_chips[material_id] = _make_chip(material_id)
	_displays[material_id].set_value(amount)
	(_material_chips[material_id] as PanelContainer).visible = amount > 0


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
