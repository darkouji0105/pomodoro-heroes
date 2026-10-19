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

var _entries: Array = []   # ⚠ [item_id, 個数, 種類, 等級（⚠ 0＝ふつう）]
var _box: ChestBox = null
var _cards: HBoxContainer = null
# ⚠ 10-17（見る回・人間「⚠ 推すと飛ばすではなくスキップという名前にして、右上にアイコンだけ出す」）：⚠ 右上の丸い札（⚠ 字は出さず、⚠ 名前は札の説明）。
var _skip_button: Button = null
# ⚠ 10-14（人間「⚠ スキップもできるように」）：⚠ 演出の途中で押したら飛ばす（⚠ 宝箱の画面の「台を押すと飛ばす」と同じ）。
var _skipped: bool = false


static func create(potions: int, chest_ids: Array) -> RewardReveal:
	var reveal: RewardReveal = RewardReveal.new()
	reveal.name = "RewardReveal"
	if potions > 0:
		reveal._entries.append([GameStateKeys.ITEM_STAMINA_POTION, potions, KIND_POTION, 0])
	# ⚠ 同じ宝箱はまとめて1枚（⚠ ×個数）。
	var counts: Dictionary = {}
	var order: Array[String] = []
	for raw: Variant in chest_ids:
		var chest_id: String = str(raw)
		if not counts.has(chest_id):
			order.append(chest_id)
		counts[chest_id] = int(counts.get(chest_id, 0)) + 1
	for chest_id: String in order:
		reveal._entries.append([chest_id, int(counts[chest_id]), KIND_CHEST, rare_grade_of(chest_id)])
	return reveal


# レアな品の等級（2026-10-17・見る回・人間「⚠ レアなものが出たら専用の演出を入れる」）。⚠ 0＝ふつう。
# ⚠ ポモドーロの宝箱は中身がどれも同じ段の素材＝⚠ 宝箱の画面の「中身の等級」では決まらない＝⚠ 箱ごとの等級を Config に持つ（`PomodoroConfig.reveal_chest_grades`）。
static func rare_grade_of(chest_id: String) -> int:
	if Balance.pomodoro == null:
		return 0
	return int(Balance.pomodoro.reveal_chest_grades.get(chest_id, 0))


# 出た品のいちばん高い等級。⚠ 演出を出すのは `ChestScreen` と同じ `fx_grade` 以上・⚠ 強い演出は `fx_strong_grade` 以上。
func top_grade() -> int:
	var top: int = 0
	for entry: Variant in _entries:
		top = maxi(top, int((entry as Array)[3]))
	return top


func is_rare() -> bool:
	return top_grade() >= get_theme_constant(&"fx_grade", THEME_TYPE)


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	theme_type_variation = &"TightList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = ChestBox.new()
	_box.name = "RewardBox"
	add_child(_box)
	# ⚠ 右上のスキップ（⚠ 箱の上の1行に右寄せ）。
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.name = "SkipRow"
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_row)
	move_child(top_row, 0)
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.theme_type_variation = &"MiniTimerButton"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.icon = IconTextures.for_timer(IconTextures.NAME_TIMER_NEXT)
	_skip_button.tooltip_text = tr("ui_reward_fx_skip")
	_skip_button.pressed.connect(skip)
	top_row.add_child(_skip_button)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_cards)
	# ⚠ 札は最初から透明で置く（⚠ 箱が開いてから足すと、⚠ 窓が縦に伸びて位置がずれる）。
	for index: int in range(_entries.size()):
		var entry: Array = _entries[index]
		_add_card(index, str(entry[0]), int(entry[1]), str(entry[2]), int(entry[3]))
	# ⚠ 名前で広がった札があれば、⚠ 全部の札をその幅にそろえる（⚠ 並びがでこぼこしない）。
	var widest: float = 0.0
	for card: Node in _cards.get_children():
		widest = maxf(widest, (card as TiltedSheet).sheet.get_combined_minimum_size().x)
	for card: Node in _cards.get_children():
		(card as TiltedSheet).sheet.custom_minimum_size.x = widest
	_play.call_deferred()


# ⚠ 箱の演出 → 札。⚠ 待っているあいだに窓が閉じたら何もしない。
func _play() -> void:
	if not is_inside_tree():
		return
	# ⚠ レアな品があれば、⚠ 箱はその等級の色で光る（⚠ 強い等級は筋が倍・長く震える＝宝箱の画面の高い等級と同じ）。
	var color: Color = get_theme_color(&"box_line", THEME_TYPE)
	var strong: bool = false
	if is_rare() and Balance.icon != null:
		color = Balance.icon.color_of_grade(top_grade())
		strong = top_grade() >= get_theme_constant(&"fx_strong_grade", THEME_TYPE)
	var tween: Tween = _box.play_fx(color, strong)
	await tween.finished
	if not is_inside_tree():
		return
	_box.stop_fx()
	_box.opened = true
	# ⚠ スキップは消さずに透明（⚠ 消すと上が詰まって窓が縮む）。
	_skip_button.modulate.a = 0.0
	_skip_button.disabled = true
	_skip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
# ⚠ レアな札は名前がその等級の色（⚠ 浮かぶときに大きく弾む＝`_rise()`）。
func _add_card(index: int, item_id: String, count: int, kind: String, grade: int) -> void:
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
	# ⚠ 10-17（見る回・人間「⚠ 名前はできるだけ折り返さないように」）：⚠ 折り返さない＝⚠ 入らなければ字を小さく（`_fit_name()`）。
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text = tr(GameManager.item_name_key(item_id))
	if grade >= get_theme_constant(&"fx_grade", THEME_TYPE) and Balance.icon != null:
		# ⚠ 10-19（見る回29回目「⚠ ピンクの名前＝もうちょっと暗くする」）：⚠ 等級の色を紙の上で読めるよう暗くする（⚠ 箱の光はそのままの色）。
		name_label.add_theme_color_override(&"font_color", Balance.icon.color_of_grade(grade).darkened(float(get_theme_constant(&"rare_name_darken_pct", THEME_TYPE)) / 100.0))
		card.set_meta(RARE_META, grade)
	column.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "×%d" % count
	column.add_child(count_label)
	card.modulate.a = 0.0
	_cards.add_child(card)
	_fit_name(name_label, card.sheet)


const RARE_META: StringName = &"reward_rare_grade"


# 名前が札の幅に入るまで字を小さくする（⚠ 下限は Theme の `name_min_size`）。⚠ 下限でも入らなければ札が広がる（⚠ 折り返さない）。
# ⚠ 入る幅＝札の幅 − 紙の左右の余白（⚠ 紙は `paper_theme.tres`＝⚠ 余白は紙の枠から引く）。
func _fit_name(label: Label, sheet: PaperSheet) -> void:
	var font: Font = label.get_theme_font(&"font")
	var size: int = label.get_theme_font_size(&"font_size")
	var min_size: int = get_theme_constant(&"name_min_size", THEME_TYPE)
	var room: float = sheet.custom_minimum_size.x
	var frame: StyleBox = sheet.get_theme_stylebox(&"panel")
	if frame != null:
		room -= frame.get_content_margin(SIDE_LEFT) + frame.get_content_margin(SIDE_RIGHT)
	while size > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	if size != label.get_theme_font_size(&"font_size"):
		label.add_theme_font_size_override(&"font_size", size)


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
	# ⚠ レアな札は、⚠ 浮かびきったところで大きく弾む（⚠ 大きさは Theme の `rare_pop_pct`）。
	if card.has_meta(RARE_META):
		var pop: float = float(get_theme_constant(&"rare_pop_pct", THEME_TYPE)) / 100.0
		var pop_sec: float = float(get_theme_constant(&"rare_pop_ms", THEME_TYPE)) / 1000.0
		card.sheet.pivot_offset = card.sheet.size * 0.5
		tween.tween_property(card.sheet, "scale", Vector2(pop, pop), pop_sec * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(card.sheet, "scale", Vector2.ONE, pop_sec * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
