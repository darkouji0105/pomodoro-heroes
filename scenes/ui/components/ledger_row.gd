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

# ⚠ 上下の余白を詰めた行（2026-09-27・詰所の身上書カード。⚠ 縦 720 に下の紙まで収めるため）。
@export var compact: bool = false:
	set(value):
		compact = value
		_apply()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if compact:
		theme_type_variation = &"LedgerRowCompactSelectedPanel" if selected else &"LedgerRowCompactPanel"
	else:
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
		# ⚠⚠ 先に入力を食べてから知らせる（2026-09-27）。⚠ 受けた画面が描き直すと、⚠ この行は木から外れる。
		#   ⚠ 外れたあとに `accept_event()` を呼ぶと赤になる（⚠ 育成・持ち物は押すたびに描き直す）。
		accept_event()
		pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		_apply()
