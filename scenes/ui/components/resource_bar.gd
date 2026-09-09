class_name ResourceBar
extends HBoxContainer

# 右上に出す資源のひとまとまり（2026-09-09・人間の指示
#   「資源は、右上に表示する / モックの資源みたいにコンパクトに」）。
#
# ⚠ 中身は **金・ジェム・スタミナ の3つ**（人間の決定）。⚠ 素材は16件あるので入らない
#   （⚠ 拠点の下段のまま）。
# ⚠ 1つ1つは `ResourceDisplay` を `ResourceChip` の面で包んだもの。
#   ⚠⚠ **`ResourceDisplay` を使うのが要点**。⚠ そうすると増えたときの演出
#   （`ResourceGainEffect`）が `resource_id` から着地先として引ける。
# ⚠ 中身はコードで作る（⚠ `.tscn` に子を置くとバックグラウンドの Godot に
#   ⚠ 消されたことがある。⚠ タイマーの輪で1回踏んだ）。
# ⚠ 2画面以上で使うので `scenes/ui/components/`（AGENTS.md）。
#
# ⚠ `ScreenHeader` が自分で1つ作って抱える。⚠ ヘッダーを使う画面はシーンを触らずに入る。
#   ⚠ ヘッダーを使わない画面（拠点・倉庫）は自前で置く。

# ⚠ 並び順。⚠ ここを増やすと出るものが増える（⚠ 画面ごとに分岐を書かない）。
const RESOURCE_IDS: Array[String] = [
	GameStateKeys.GOLD,
	GameStateKeys.GEMS,
	GameStateKeys.STAMINA,
]

const RESOURCE_DISPLAY_SCENE: PackedScene = preload(
	"res://scenes/ui/components/resource_display.tscn"
)

# resource_id -> ResourceDisplay
var _displays: Dictionary = {}


func _ready() -> void:
	_build()
	GameManager.resource_changed.connect(_on_resource_changed)
	_refresh_all()


func _build() -> void:
	for resource_id: String in RESOURCE_IDS:
		var chip: PanelContainer = PanelContainer.new()
		chip.name = "Chip_" + resource_id
		chip.theme_type_variation = &"ResourceChip"
		# ⚠ 面が押せてしまうと、⚠ 後ろのボタンが押せなくなる。
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)

		var display: ResourceDisplay = RESOURCE_DISPLAY_SCENE.instantiate()
		display.name = "Value"
		display.resource_id = resource_id
		chip.add_child(display)
		# ⚠ チップの中だけアイコンを小さくする（⚠ 大きさは Theme が持つ。⚠ モックは 20px）。
		#   ⚠⚠ **縦は縮まない**（実測：24px でも 20px でも倉庫は 712）。⚠ 見た目を合わせるためだけ。
		var side: int = chip.get_theme_constant(&"icon", &"ResourceChip")
		var icon: TextureRect = display.get_node("Icon")
		icon.custom_minimum_size = Vector2(side, side)
		_displays[resource_id] = display


func _refresh_all() -> void:
	var state: Dictionary = GameManager.get_state()
	for resource_id: String in RESOURCE_IDS:
		if resource_id == GameStateKeys.STAMINA:
			var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
			_stamina_display().set_value_with_max(
				int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
				int(stamina.get(GameStateKeys.STAMINA_MAX, 0)),
			)
			continue
		_displays[resource_id].set_value(int(state.get(resource_id, 0)))


func _stamina_display() -> ResourceDisplay:
	return _displays[GameStateKeys.STAMINA]


# ⚠⚠ スタミナだけ第2引数が `current` の `int` 単体で、⚠ `max` を含まない（AGENTS.md）。
#   ⚠ `set_value_with_max(current, 0)` と書くと `10/0` と出る。⚠ 状態から読み直す。
func _on_resource_changed(resource_type: String, new_value: Variant) -> void:
	if not _displays.has(resource_type):
		return
	if resource_type == GameStateKeys.STAMINA:
		var state: Dictionary = GameManager.get_state()
		var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
		_stamina_display().set_value_with_max(
			int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
			int(stamina.get(GameStateKeys.STAMINA_MAX, 0)),
		)
		return
	_displays[resource_type].set_value(int(new_value))
