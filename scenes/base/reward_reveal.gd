class_name RewardReveal
extends VBoxContainer

# ポモドーロから戻ったときの受け取り窓の中身（2026-10-14・人間「⚠ 窓はやめない　これは報酬だから手に入れたという実感を与えたい」
#   →「⚠ 宝箱開けるような、演出付きの窓に」）。
# ⚠ 閉じた箱が光って震え、⚠ 蓋が開き、⚠ 札が浮かび上がる（⚠ 届いた宝箱の画面 `ChestScreen` と同じ部品・同じ Theme の値）。
# ⚠ 窓の中に入れて使う（`Modal.OPTION_CONTENT`）。⚠ 状態は触らない（⚠ 受け取りはもう済んでいる＝見せるだけ）。
# ⚠ 演出の速さは設定の「演出の速さ」（`GameSettings.effect_speed()`）。⚠ 窓を閉じれば一緒に止まる（⚠ Tween は箱と札に結ぶ）。
# ⚠ 拠点でしか使わないので scenes/base/（AGENTS.md）。

const THEME_TYPE: StringName = &"ChestScreen"
# ⚠ 札の種類（⚠ 一番上の小さな字 `ui_chest_kind_<種類>` と上の色の帯 `band_<種類>`・`ChestScreen` と同じ字）。
const KIND_POTION: String = "consumable"
const KIND_CHEST: String = "chest"
const KIND_OTHER: String = "other"

var _entries: Array = []   # ⚠ [item_id, 個数, 種類]
var _box: ChestBox = null
var _cards: HBoxContainer = null
var _hint: Label = null
# ⚠ 10-14（人間「⚠ スキップもできるように」）：⚠ 演出の途中で押したら飛ばす（⚠ 宝箱の画面の「台を押すと飛ばす」と同じ）。
var _skipped: bool = false


static func create(potions: int, chest_ids: Array) -> RewardReveal:
	var reveal: RewardReveal = RewardReveal.new()
	reveal.name = "RewardReveal"
	if potions > 0:
		reveal._entries.append([GameStateKeys.ITEM_STAMINA_POTION, potions, KIND_POTION])
	# ⚠ 同じ宝箱はまとめて1枚（⚠ ×個数）。
	var counts: Dictionary = {}
	var order: Array[String] = []
	for raw: Variant in chest_ids:
		var chest_id: String = str(raw)
		if not counts.has(chest_id):
			order.append(chest_id)
		counts[chest_id] = int(counts.get(chest_id, 0)) + 1
	for chest_id: String in order:
		reveal._entries.append([chest_id, int(counts[chest_id]), KIND_CHEST])
	return reveal


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	theme_type_variation = &"TightList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = ChestBox.new()
	_box.name = "RewardBox"
	add_child(_box)
	_hint = Label.new()
	_hint.name = "SkipHint"
	_hint.theme_type_variation = &"CaptionLabel"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = tr("ui_reward_fx_skip_hint")
	add_child(_hint)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_cards)
	# ⚠ 札は最初から透明で置く（⚠ 箱が開いてから足すと、⚠ 窓が縦に伸びて位置がずれる）。
	for index: int in range(_entries.size()):
		var entry: Array = _entries[index]
		_add_card(index, str(entry[0]), int(entry[1]), str(entry[2]))
	_play.call_deferred()


# ⚠ 箱の演出 → 札。⚠ 待っているあいだに窓が閉じたら何もしない。
func _play() -> void:
	if not is_inside_tree():
		return
	var tween: Tween = _box.play_fx(get_theme_color(&"box_line", THEME_TYPE), false)
	await tween.finished
	if not is_inside_tree():
		return
	_box.stop_fx()
	_box.opened = true
	# ⚠ 案内は消さずに透明（⚠ 消すと下が詰まって窓が縮む）。
	_hint.modulate.a = 0.0
	for index: int in range(_cards.get_child_count()):
		var card: TiltedSheet = _cards.get_child(index) as TiltedSheet
		if _skipped:
			card.modulate.a = 1.0
		else:
			_rise(card, index)


# ⚠ 演出の途中で窓の中を押したら飛ばす（⚠ 箱はすぐ開き、⚠ 札は浮かぶ動きを待たずに並ぶ）。
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _box != null and _box.is_playing_fx():
		accept_event()
	skip()


func skip() -> void:
	if _skipped or _box == null or not _box.is_playing_fx():
		return
	_skipped = true
	_box.stop_fx()


# 札1枚：上の色の帯 ／ 種類 ／ 絵 ／ 名前 ／ ×個数（⚠ `ChestScreen._add_card()` と同じ並び）。
func _add_card(index: int, item_id: String, count: int, kind: String) -> void:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = "Card_%d" % index
	card.sheet.custom_minimum_size.x = float(get_theme_constant(&"card_width", THEME_TYPE))
	card.sheet.show_corners = false
	card.sheet.draw.connect(_draw_band.bind(card.sheet, kind))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.sheet.add_child(column)
	var kind_label: Label = Label.new()
	kind_label.theme_type_variation = &"CaptionLabel"
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kind_key: String = "ui_chest_kind_" + kind
	kind_label.text = "" if tr(kind_key) == kind_key else tr(kind_key)
	column.add_child(kind_label)
	var icon: ItemIcon = ItemIcon.create(item_id)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = tr(GameManager.item_name_key(item_id))
	column.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "×%d" % count
	column.add_child(count_label)
	card.modulate.a = 0.0
	_cards.add_child(card)


func _draw_band(sheet: PaperSheet, kind: String) -> void:
	var color_name: StringName = StringName("band_" + kind)
	if not has_theme_color(color_name, THEME_TYPE):
		color_name = StringName("band_" + KIND_OTHER)
	var band: float = float(get_theme_constant(&"band", THEME_TYPE))
	sheet.draw_rect(Rect2(Vector2.ZERO, Vector2(sheet.size.x, band)), get_theme_color(color_name, THEME_TYPE))


# ⚠ 下から上がりながら現れる（⚠ `ChestScreen._rise()` と同じ値）。
func _rise(card: TiltedSheet, index: int) -> void:
	var duration: float = float(get_theme_constant(&"rise_ms", THEME_TYPE)) / 1000.0
	var step: int = mini(index, get_theme_constant(&"rise_max_steps", THEME_TYPE))
	var delay: float = float(get_theme_constant(&"rise_step_ms", THEME_TYPE)) * step / 1000.0
	var rise: float = float(get_theme_constant(&"rise_px", THEME_TYPE))
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween().set_speed_scale(GameSettings.effect_speed())
	tween.tween_interval(delay)
	tween.tween_property(card, "modulate:a", 1.0, duration)
	tween.parallel().tween_property(card.sheet, "position:y", 0.0, duration).from(rise) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
