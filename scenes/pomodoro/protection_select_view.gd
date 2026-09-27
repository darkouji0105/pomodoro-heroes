extends Control

# 加護を選ぶビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠⚠ 2026-09-27（回UI-4・手本 Pomodoro）：⚠ ボタン3つ → **傾いた紙のカード3枚**。
#   ⚠ カード＝線で描いた砂時計 ／ 名前（明朝）／ 大きな分 ／ 点線 ／ 到達点の宝箱。
#   ⚠ **押すと選ぶだけ**（⚠ 選んだカードは明るい紙＋「今日はこれ」の判）。⚠ 決めるのは右下の真鍮「◯で始める」。
#   ⚠ 前は押した瞬間に決まっていた（⚠ 1日1回しか選べないのに、⚠ 押し間違えを戻せなかった）。
#   ⚠ 開いたときはライトを選んでおく（⚠ 手本）。
# ⚠ 分と宝箱は `Balance.pomodoro.protection_*` の**最後のしきい値**から引く
#   （＝その加護の到達点。⚠ 途中のふつうの宝箱は出さない）。
#   ⚠ ここに分数や宝箱の名前を**直書きしない**。⚠ `.tres` を変えたら表示も変わる。
# ⚠ 手本の左下「90分でノルマ札 +1」は出さない（⚠ ノルマ札は仕組みの回＝まだ無い）。

signal protection_selected(protection_id: String)

const PROTECTIONS: Array[String] = [
	GameStateKeys.PROTECTION_LIGHT, GameStateKeys.PROTECTION_MIDDLE, GameStateKeys.PROTECTION_HARD,
]
const NAME_KEYS: Array[String] = [
	"ui_pomodoro_protection_light", "ui_pomodoro_protection_middle", "ui_pomodoro_protection_hard",
]

@onready var choices: HBoxContainer = $Layout/Body/Choices
@onready var start_button: UiButton = $Layout/Body/Footer/StartButton

var _cards: Array[TiltedSheet] = []
var _stamps: Array[Stamp] = []
var _selected: int = 0


func _ready() -> void:
	var configs: Array[ProtectionTypeConfig] = [
		Balance.pomodoro.protection_light, Balance.pomodoro.protection_middle, Balance.pomodoro.protection_hard,
	]
	var width: float = float(get_theme_constant(&"card_width", &"ProtectionCard"))
	for i: int in PROTECTIONS.size():
		var card: TiltedSheet = _make_card(i, configs[i])
		# ⚠ 幅は紙の側に付ける（⚠ 器の最小は `TiltedSheet._fit()` が紙の最小で上書きする）。
		card.sheet.custom_minimum_size.x = width
		choices.add_child(card)
		_cards.append(card)
	start_button.pressed.connect(_on_start_pressed)
	_select(0)


func _make_card(index: int, config: ProtectionTypeConfig) -> TiltedSheet:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = "Card_" + PROTECTIONS[index]
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.sheet.add_child(column)

	# ⚠ 「今日はこれ」の判。⚠ 選ぶまで透明（⚠ 並びが動かない）。
	var stamp: Stamp = Stamp.new()
	stamp.label_key = "ui_stamp_today"
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	stamp.modulate.a = 0.0
	column.add_child(stamp)
	_stamps.append(stamp)

	column.add_child(Hourglass.create(index))

	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tr(NAME_KEYS[index])
	column.add_child(name_label)

	var goal: ChestScheduleEntry = _goal_of(config)
	var minutes_row: HBoxContainer = HBoxContainer.new()
	minutes_row.theme_type_variation = &"ProtectionMinutesRow"
	minutes_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var minutes: Label = Label.new()
	minutes.theme_type_variation = &"ProtectionMinutesLabel"
	minutes.text = str(goal.threshold_min) if goal != null else ""
	minutes_row.add_child(minutes)
	var unit: Label = Label.new()
	unit.theme_type_variation = &"CaptionLabel"
	unit.text = tr("ui_common_minutes_unit")
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	minutes_row.add_child(unit)
	column.add_child(minutes_row)

	column.add_child(HSeparator.new())

	var chest_row: HBoxContainer = HBoxContainer.new()
	chest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_texture: Texture2D = IconTextures.for_chest()
	if icon_texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = float(get_theme_constant(&"chest_icon", &"ProtectionCard"))
		icon.custom_minimum_size = Vector2(side, side)
		icon.modulate = get_theme_color(&"chest_icon", &"ProtectionCard")
		chest_row.add_child(icon)
	var chest: Label = Label.new()
	chest.theme_type_variation = &"CaptionLabel"
	chest.text = tr("ui_chest_" + goal.chest_type) if goal != null else ""
	chest_row.add_child(chest)
	column.add_child(chest_row)

	# ⚠ 面ぜんぶを押せる（⚠ 中身を足し終わってから敷く＝`attach_hit` の決まり）。⚠ 当たりも一緒に傾く。
	var _hit: Button = UiButton.attach_hit(card.sheet, _select.bind(index))
	return card


# ⚠ その加護の到達点。⚠ 予定が空なら null（⚠ `.tres` を空にしても落ちない）。
func _goal_of(config: ProtectionTypeConfig) -> ChestScheduleEntry:
	if config == null or config.schedule.is_empty():
		return null
	return config.schedule[config.schedule.size() - 1]


func _select(index: int) -> void:
	_selected = index
	for i: int in _cards.size():
		var chosen: bool = i == index
		_cards[i].sheet.theme_type_variation = &"PaperPanelChosen" if chosen else &"PaperPanel"
		_stamps[i].modulate.a = 1.0 if chosen else 0.0
	start_button.text = tr("ui_pomodoro_start_with").format([tr(NAME_KEYS[index])])


func _on_start_pressed() -> void:
	protection_selected.emit(PROTECTIONS[_selected])
