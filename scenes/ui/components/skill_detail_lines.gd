# res://scenes/ui/components/skill_detail_lines.gd
# スキルの詳細表示の行（2026-10-20・回SKD-1・決定 `GR-16`）：⚠ 1効果1行＝アイコン＋文（`SkillDetailText`）。
#
# ⚠ 「詳細」の切り替えもここ（⚠ 押したらその遊びの間は覚える＝`SceneManager.remember()`）。
#   ⚠ 切り替えが効く所：⚠ スキルを選ぶ窓（`LoadoutEditor`）／ ⚠ スキルの吹き出し（育成・詰所・戦闘）／ ⚠ 敵の解説の窓。
# ⚠ 2画面以上で使う＝components/。⚠ 大きさは Theme の `SkillDetail`。

class_name SkillDetailLines
extends VBoxContainer

const THEME_TYPE: StringName = &"SkillDetail"


static func create(lines: Array[Dictionary]) -> SkillDetailLines:
	var box: SkillDetailLines = SkillDetailLines.new()
	box.name = "SkillDetail"
	box._lines = lines
	return box


static func for_skill(skill_id: String) -> SkillDetailLines:
	return create(SkillDetailText.lines_of_skill(skill_id))


# ⚠ 詳細を出すか（⚠ 既定は出さない＝ふだんは短い説明）。
static func is_on() -> bool:
	return bool(SceneManager.recall(TransferKeys.MEMORY_SKILL_DETAIL, false))


static func set_on(on: bool) -> void:
	SceneManager.remember(TransferKeys.MEMORY_SKILL_DETAIL, on)


# ⚠ 「詳細」の切り替えの札（⚠ 押すと覚えてから `on_changed` を呼ぶ）。
static func toggle(on_changed: Callable) -> Button:
	var button: Button = Button.new()
	button.name = "DetailToggle"
	button.theme_type_variation = &"PaperToggle"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = TranslationServer.translate("ui_skd_toggle")
	button.tooltip_text = TranslationServer.translate("ui_skd_toggle_hint")
	button.set_pressed_no_signal(is_on())
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ⚠ 押したら覚えている値を反転する（⚠ 札の押し込みではなく覚えている値が正＝どの画面の札でも同じ向き）。
	button.pressed.connect(func() -> void:
		set_on(not is_on())
		button.set_pressed_no_signal(is_on())
		if on_changed.is_valid():
			on_changed.call())
	return button


var _lines: Array[Dictionary] = []


func _ready() -> void:
	theme_type_variation = &"TightList"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = float(get_theme_constant(&"icon", THEME_TYPE))
	for i: int in range(_lines.size()):
		var line: Dictionary = _lines[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Line_%d" % i
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.texture = line.get(SkillDetailText.KEY_ICON, null) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(side, side)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var label: Label = Label.new()
		label.name = "Text"
		label.theme_type_variation = &"SkillDetailLabel"
		label.text = str(line.get(SkillDetailText.KEY_TEXT, ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		tint(icon, label)


# ⚠ アイコンを横の字と同じ色に（⚠ 紙の上＝墨 ／ 戦闘の暗い吹き出し＝明るい字）。
#   ⚠ 字の Theme が変わるたびに取り直す（⚠ 窓は中身を組んでから紙になる＝組んだ時点の色は明るい既定の字で、紙の上で見えなかった＝撮った絵）。
static func tint(icon: CanvasItem, label: Control) -> void:
	var apply: Callable = func() -> void:
		if is_instance_valid(icon) and is_instance_valid(label):
			icon.self_modulate = label.get_theme_color(&"font_color")
	label.theme_changed.connect(apply)
	apply.call()
	# ⚠ 窓が紙になるのは中身を組んだ後（⚠ 同じフレームの終わり）＝⚠ もう一度取り直す。
	apply.call_deferred()


# ⚠ 検査用：⚠ 行の文。
func texts() -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in _lines:
		out.append(str(line.get(SkillDetailText.KEY_TEXT, "")))
	return out
