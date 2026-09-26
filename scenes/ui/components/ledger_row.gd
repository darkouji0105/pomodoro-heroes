class_name LedgerRow
extends PanelContainer

# 台帳の行（2026-09-26・回UI-2・手本の「台帳の行」）。
#
# ⚠ 紙の上の一覧の1行。⚠ 暗い箱で囲まない。⚠ 区切りは下の**点線の罫**。
# ⚠ 選んでいる行 … 明るい紙 ＋ 左に真鍮の墨の線（`LedgerRowSelectedPanel`）
# ⚠ 使えない行   … 薄くする（⚠ 押しても `pressed` を出さない）
# ⚠ 中身（絵・名前・値）は使う側が子として入れる（⚠ 行の形を1つに決めない）。
# ⚠ 値は Theme の `LedgerRowPanel` / `LedgerRowSelectedPanel` / `LedgerRow` 型。
# ⚠ `.new()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

signal pressed

const THEME_TYPE: StringName = &"LedgerRow"

@export var selected: bool = false:
	set(value):
		selected = value
		_apply()

@export var disabled: bool = false:
	set(value):
		disabled = value
		_apply()

# ⚠ 最後の行は罫を引かない、などに使う。
@export var show_rule: bool = true:
	set(value):
		show_rule = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	theme_type_variation = &"LedgerRowSelectedPanel" if selected else &"LedgerRowPanel"
	var alpha: float = 1.0
	if disabled and is_inside_tree():
		alpha = float(get_theme_constant(&"disabled_alpha_pct", THEME_TYPE)) / 100.0
	modulate.a = alpha
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	queue_redraw()


func _draw() -> void:
	if not show_rule:
		return
	var color: Color = get_theme_color(&"rule", THEME_TYPE)
	var dash: float = float(get_theme_constant(&"dash", THEME_TYPE))
	var y: float = size.y - 0.5
	draw_dashed_line(Vector2(0.0, y), Vector2(size.x, y), color, 1.0, dash)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_apply()
