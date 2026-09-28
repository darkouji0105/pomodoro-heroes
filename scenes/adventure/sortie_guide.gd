class_name SortieGuide
extends Control

# 出撃の準備の「はじめてのガイド」（2026-09-28・モック `出撃の準備：はじめてのガイド`・人間「⚠ 2あ」）。
#
# ⚠ 人間「⚠ 気づけないね　ガイドが必要」。⚠ 初めて開いたときだけ出す（⚠ 見たかは `GameManager.is_guide_seen()`）。
# ⚠ 画面いっぱいの暗幕に**穴**を開けて、⚠ 光らせる所（⚠ 枠3つ ／ 名簿）だけ明るく残す ＋ ⚠ 紙の吹き出し（題・本文・「とばす」「つぎへ」）。
# ⚠ 開いている間は後ろを押せない（⚠ 暗幕が押下を食べる）。⚠ 最後まで進むか「とばす」で `finished` を出して消える。
# ⚠ 値は Theme の `Sortie` 型（⚠ 暗幕の色・穴の広げ幅・吹き出しの幅）。
# ⚠ 出撃の準備でしか使わないので scenes/adventure/（AGENTS.md）。

signal finished

const THEME_TYPE: StringName = &"Sortie"
const KEY_TARGETS: String = "targets"
const KEY_TITLE: String = "title_key"
const KEY_BODY: String = "body_key"

var _steps: Array[Dictionary] = []
var _index: int = 0
var _bubble: PaperSheet = null
var _hole: Rect2 = Rect2()


# steps：[{targets: Array[Control], title_key, body_key}]。⚠ host の一番上に置く。
static func open(host: Control, steps: Array[Dictionary]) -> SortieGuide:
	var guide: SortieGuide = SortieGuide.new()
	guide.name = "SortieGuide"
	guide._steps = steps
	host.add_child(guide)
	return guide


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show_step.call_deferred()


func _show_step() -> void:
	if _bubble != null:
		remove_child(_bubble)
		_bubble.queue_free()
		_bubble = null
	if _index >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_index]
	_hole = Rect2()
	for target: Variant in step.get(KEY_TARGETS, []):
		if target is Control and is_instance_valid(target):
			var rect: Rect2 = (target as Control).get_global_rect()
			_hole = rect if _hole.size == Vector2.ZERO else _hole.merge(rect)
	_hole = _hole.grow(float(get_theme_constant(&"guide_hole_pad", THEME_TYPE)))
	_hole.position -= get_global_rect().position
	queue_redraw()
	# ⚠ 穴の縁を派手に脈打たせる（⚠ 09-28 人間「⚠ 入れ替えるためのガイドを派手に　⚠ 枠を囲むとか派手な色で」）。
	for child: Node in get_children():
		if child is PulseFrame:
			remove_child(child)
			child.queue_free()
	var ring: PulseFrame = PulseFrame.attach(self, PulseFrame.Strength.STRONG)
	ring.target_rect = _hole

	_bubble = PaperSheet.new()
	_bubble.name = "Bubble"
	_bubble.custom_minimum_size.x = float(get_theme_constant(&"guide_width", THEME_TYPE))
	var body: VBoxContainer = VBoxContainer.new()
	_bubble.add_child(body)
	var count: Label = Label.new()
	count.theme_type_variation = &"CaptionLabel"
	count.text = tr("ui_sortie_guide_count") % [_index + 1, _steps.size()]
	body.add_child(count)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr(str(step.get(KEY_TITLE, "")))
	body.add_child(title)
	var text: Label = Label.new()
	text.theme_type_variation = &"SmallLabel"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = tr(str(step.get(KEY_BODY, "")))
	body.add_child(text)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(buttons)
	var skip: Button = UiButton.create_paper_choice("ui_sortie_guide_skip")
	skip.name = "GuideSkip"
	skip.pressed.connect(_finish)
	buttons.add_child(skip)
	var last: bool = _index == _steps.size() - 1
	var next: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_sortie_guide_start" if last else "ui_sortie_guide_next")
	next.name = "GuideNext"
	next.pressed.connect(_on_next_pressed)
	buttons.add_child(next)
	add_child(_bubble)
	_place_bubble.call_deferred()


# ⚠ 光らせる所の下に出す。⚠ 下に入らなければ上。⚠ 上にも入らなければ画面の下端（⚠ 手本も名簿の上に重ねて出す）。
func _place_bubble() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	var box: Vector2 = _bubble.get_combined_minimum_size()
	_bubble.size = box
	var x: float = clampf(_hole.get_center().x - box.x * 0.5, 8.0, size.x - box.x - 8.0)
	var y: float = _hole.end.y + 12.0
	if y + box.y > size.y - 8.0:
		y = _hole.position.y - box.y - 12.0
		if y < 8.0:
			y = size.y - box.y - 8.0
	_bubble.position = Vector2(x, y)


func _on_next_pressed() -> void:
	_index += 1
	_show_step()


func _finish() -> void:
	finished.emit()
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()


# 暗幕（⚠ 穴の周りの4枚）。
func _draw() -> void:
	var dim: Color = get_theme_color(&"guide_dim", THEME_TYPE)
	if _hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	draw_rect(Rect2(0.0, 0.0, size.x, _hole.position.y), dim)
	draw_rect(Rect2(0.0, _hole.end.y, size.x, size.y - _hole.end.y), dim)
	draw_rect(Rect2(0.0, _hole.position.y, _hole.position.x, _hole.size.y), dim)
	draw_rect(Rect2(_hole.end.x, _hole.position.y, size.x - _hole.end.x, _hole.size.y), dim)
	# ⚠ 穴の縁は `PulseFrame` が脈打って引く（⚠ ここでは引かない）。
