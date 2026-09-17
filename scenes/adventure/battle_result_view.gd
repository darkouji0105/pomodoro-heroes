class_name BattleResultView
extends Control

# 戦闘の結果窓（2026-09-17・人間のモック §12・NEXT_STEPS §0-UI-G）。
#
# ⚠⚠ 置き場は battle.tscn の HUD/ResultView（⚠ 戦闘でしか使わないので scenes/adventure/）。
# ⚠⚠ Modal は使わない（人間の決定）。⚠ 行き先を持つボタンが2つ並ぶため。
# ⚠ この部品は**状態を1つも動かさない**。⚠ ボタンはシグナルを出すだけで、
#   ⚠ 行き先を決めて遷移するのは BattleController（⚠ 報酬を配る口・降りる口を増やさない）。
# ⚠ 見た目の値は Theme の `BattleResult` 型と variation（⚠ ここに数字も色も書かない）。
# ⚠ 中身はコードで作る（⚠ ChargeBar と同じ流儀）。⚠ 作り直しは remove_child してから queue_free（AGENTS.md）。

signal next_pressed
signal base_pressed
signal retry_pressed

const BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/ui_button.tscn")

# show_result() に渡す Dictionary のキー。⚠ 綴りを呼ぶ側に書かせない。
const DATA_VICTORY: String = "victory"
const DATA_HEADING: String = "heading"
const DATA_ELAPSED_SEC: String = "elapsed_sec"
const DATA_DAMAGE_TAKEN: String = "damage_taken"
# ⚠ マスとピルに出す報酬（{gold, gems, stamina, materials, inventory}）。⚠ 出さないときは空。
const DATA_REWARDS: String = "rewards"
# ⚠ 報酬の代わりに出す1行の翻訳キー。⚠ 無ければ ""。
const DATA_NOTE_KEY: String = "note_key"
# ⚠ 注記が「失ったこと」を言うか（⚠ 赤い小さい字にする）。
const DATA_NOTE_IS_LOSS: String = "note_is_loss"
# ⚠ 負けたときに「もう一度」を出すか。⚠ 勝ったときは見ない。
const DATA_CAN_RETRY: String = "can_retry"

var _dim: ColorRect = null
var _stack: VBoxContainer = null
var _title_label: Label = null
var _heading_label: Label = null
var _summary_label: Label = null
var _grid: ItemGrid = null
var _note_label: Label = null
var _pill_row: HBoxContainer = null
var _button_row: HBoxContainer = null
var _window: PanelContainer = null


func _ready() -> void:
	_build()


# 窓の骨組み。⚠ 1回だけ作る（⚠ 中身の差し替えは show_result()）。
func _build() -> void:
	if _dim != null:
		return
	var t: StringName = &"BattleResult"
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = get_theme_color(&"dim", t)
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_window = PanelContainer.new()
	_window.name = "Window"
	_window.theme_type_variation = &"ResultWindowPanel"
	_window.custom_minimum_size.x = get_theme_constant(&"width", t)
	center.add_child(_window)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.name = "Outer"
	outer.theme_type_variation = &"BattleBands"
	_window.add_child(outer)

	outer.add_child(_build_title_bar(t))

	var body: MarginContainer = MarginContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"ResultBodyMargin"
	outer.add_child(body)

	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.theme_type_variation = &"ResultStack"
	body.add_child(_stack)

	var heading_stack: VBoxContainer = VBoxContainer.new()
	heading_stack.name = "HeadingStack"
	heading_stack.theme_type_variation = &"ResultHeadingStack"
	_stack.add_child(heading_stack)
	_heading_label = Label.new()
	_heading_label.name = "Heading"
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_stack.add_child(_heading_label)
	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.theme_type_variation = &"CaptionLabel"
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_stack.add_child(_summary_label)

	_grid = ItemGrid.new()
	_grid.name = "RewardGrid"
	_grid.columns = get_theme_constant(&"columns", t)
	_stack.add_child(_grid)

	_note_label = Label.new()
	_note_label.name = "Note"
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stack.add_child(_note_label)

	var rule: HSeparator = HSeparator.new()
	rule.name = "FooterRule"
	_stack.add_child(rule)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	_stack.add_child(footer)
	_pill_row = HBoxContainer.new()
	_pill_row.name = "Pills"
	_pill_row.theme_type_variation = &"ChipRow"
	_pill_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_pill_row)
	_button_row = HBoxContainer.new()
	_button_row.name = "Buttons"
	_button_row.theme_type_variation = &"ButtonRow"
	footer.add_child(_button_row)


# 題の帯。⚠ 左に ☆、⚠ 題は窓の横の真ん中。
#   ⚠ 右に ☆ と同じ幅の透明な字を置いて、⚠ 題が ☆ の幅ぶん右へずれないようにする。
func _build_title_bar(t: StringName) -> PanelContainer:
	var bar: PanelContainer = PanelContainer.new()
	bar.name = "TitleBar"
	bar.theme_type_variation = &"ResultTitlePanel"
	bar.custom_minimum_size.y = get_theme_constant(&"title_height", t)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TitleRow"
	bar.add_child(row)
	row.add_child(_make_mark_label("MarkLeft", false))
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.theme_type_variation = &"ResultTitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title_label)
	row.add_child(_make_mark_label("MarkRight", true))
	return bar


func _make_mark_label(node_name: String, hidden: bool) -> Label:
	var mark: Label = Label.new()
	mark.name = node_name
	mark.text = Glyphs.RESULT_TITLE_MARK
	mark.theme_type_variation = &"AccentLabel"
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hidden:
		mark.modulate.a = 0.0
	return mark


# 中身を差し替えて出す。⚠ キーは DATA_*。
func show_result(data: Dictionary) -> void:
	_build()
	var victory: bool = bool(data.get(DATA_VICTORY, false))
	_title_label.text = tr("ui_battle_result_victory_title" if victory else "ui_battle_result_defeat_title")
	_heading_label.text = str(data.get(DATA_HEADING, ""))
	_heading_label.theme_type_variation = &"ResultHeadingLabel" if victory else &"ResultDefeatHeadingLabel"
	_summary_label.text = tr("ui_battle_result_summary") % [
		_format_time(float(data.get(DATA_ELAPSED_SEC, 0.0))),
		int(data.get(DATA_DAMAGE_TAKEN, 0)),
	]

	var rewards: Dictionary = data.get(DATA_REWARDS, {})
	var entries: Array = RewardEntries.slot_entries(rewards)
	_grid.rebuild(entries, entries.size())
	_grid.visible = not entries.is_empty()

	var note_key: String = str(data.get(DATA_NOTE_KEY, ""))
	_note_label.text = tr(note_key) if note_key != "" else ""
	_note_label.theme_type_variation = &"SmallErrorLabel" if bool(data.get(DATA_NOTE_IS_LOSS, false)) else &"CaptionLabel"
	_note_label.visible = note_key != ""

	_rebuild_pills(RewardEntries.currency_amounts(rewards))
	_rebuild_buttons(victory, bool(data.get(DATA_CAN_RETRY, false)))
	show()


# 経過時間を「分:秒」にする（⚠ 数字だけなので tr() を通さない）。
func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


# 通貨のピル（⚠ 右上の通貨のチップと同じ面 `CurrencyChip`・同じ色）。
# ⚠⚠ `ResourceDisplay` を使わない。⚠ あれは増えたときの演出の着地先の組に入るので、
#   ⚠ 勝利の報酬で飛ぶ絵がこの窓へ着地してしまう。
func _rebuild_pills(amounts: Dictionary) -> void:
	for child in _pill_row.get_children():
		_pill_row.remove_child(child)
		child.queue_free()
	for resource_id: String in amounts:
		var chip: PanelContainer = PanelContainer.new()
		chip.name = "Pill_" + resource_id
		chip.theme_type_variation = &"CurrencyChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill_row.add_child(chip)
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"ChipRow"
		chip.add_child(row)
		var texture: Texture2D = IconTextures.for_resource(resource_id)
		if texture != null:
			var side: int = chip.get_theme_constant(&"icon", &"CurrencyChip")
			var icon: TextureRect = TextureRect.new()
			icon.name = "Icon"
			icon.texture = texture
			# ⚠ これが無いと SVG の 48px が最小サイズになる（resource_bar.gd の注記）。
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(side, side)
			var key: StringName = StringName(ResourceBar.color_key_for(resource_id))
			if chip.has_theme_color(key, &"ResourceChip"):
				icon.modulate = chip.get_theme_color(key, &"ResourceChip")
			row.add_child(icon)
		var value: Label = Label.new()
		value.name = "Value"
		value.theme_type_variation = &"ChipValueLabel"
		value.text = "+%d" % int(amounts[resource_id])
		row.add_child(value)


# ボタン（人間の決定・§0-UI-G）。⚠ 真鍮は1個だけ。
#   ⚠ 勝ち ……………… 拠点へ（既定）＋ 次へ進む（真鍮）
#   ⚠ 負け・やり直せる … 拠点へ（既定）＋ もう一度（真鍮）
#   ⚠ 負け・やり直せない（難ダンジョンの全滅）… 拠点へ（真鍮）だけ
func _rebuild_buttons(victory: bool, can_retry: bool) -> void:
	for child in _button_row.get_children():
		_button_row.remove_child(child)
		child.queue_free()
	var base_is_primary: bool = (not victory) and (not can_retry)
	_add_button("BaseButton", "ui_battle_result_to_base", base_is_primary, base_pressed.emit)
	if victory:
		_add_button("NextButton", "ui_battle_result_next", true, next_pressed.emit)
	elif can_retry:
		_add_button("RetryButton", "ui_battle_retry", true, retry_pressed.emit)


func _add_button(node_name: String, label_key: String, primary: bool, handler: Callable) -> void:
	var button: UiButton = BUTTON_SCENE.instantiate()
	button.name = node_name
	button.label_key = label_key
	button.variant = UiButton.Variant.PRIMARY if primary else UiButton.Variant.SECONDARY
	button.pressed.connect(handler)
	_button_row.add_child(button)


# 検証用（⚠ 設計役は絵を見られない）。⚠ いま窓に何が出ているかを文字で返す。
#   ⚠ ゲームのロジックから呼ばないこと（⚠ ItemIcon.get_center_debug_text と同じ扱い）。
func get_debug_summary() -> String:
	var pills: Array[String] = []
	for chip in _pill_row.get_children():
		pills.append("%s:%s" % [chip.name, (chip.find_child("Value", true, false) as Label).text])
	var buttons: Array[String] = []
	for button in _button_row.get_children():
		buttons.append("%s(%s)" % [button.name, (button as UiButton).theme_type_variation])
	var rect: Rect2 = _window.get_global_rect()
	var own: Rect2 = get_global_rect()
	var center_rect: Rect2 = (_window.get_parent() as Control).get_global_rect()
	return "器=%.0f,%.0f %.0fx%.0f ／ 中央寄せ=%.0f,%.0f %.0fx%.0f ／ 画面=%s ｜ " % [
		own.position.x, own.position.y, own.size.x, own.size.y,
		center_rect.position.x, center_rect.position.y, center_rect.size.x, center_rect.size.y,
		get_viewport_rect().size,
	] + "題=%s ｜ 見出し=%s[%s] ｜ 副題=%s ｜ マス=%d（列%d・表示=%s） ｜ 注記=%s[%s・表示=%s] ｜ ピル=%s ｜ ボタン=%s ｜ 窓=%.0f,%.0f %.0fx%.0f（中心 %.0f,%.0f）" % [
		_title_label.text, _heading_label.text, _heading_label.theme_type_variation,
		_summary_label.text, _grid.get_slot_count(), _grid.columns, _grid.visible,
		_note_label.text, _note_label.theme_type_variation, _note_label.visible,
		",".join(pills), ",".join(buttons),
		rect.position.x, rect.position.y, rect.size.x, rect.size.y,
		rect.get_center().x, rect.get_center().y,
	]
