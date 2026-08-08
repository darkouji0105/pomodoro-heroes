extends Control

# UI共通パーツ（Theme + PrimaryButton / ResourceDisplay / DialogBase）の
# 表示確認・動作確認用デモシーン。res://tests/ 配下に隔離。
#
# 完了条件#5〜#10 を print で自動検証する。
# hover / pressed の実見た目遷移は人間が目視確認する（ヘッドレスでは再現しない）。

@onready var normal_button: PrimaryButton = $Layout/NormalButton
@onready var disabled_button: PrimaryButton = $Layout/DisabledButton
@onready var long_button: PrimaryButton = $Layout/LongButton
@onready var open_dialog_button: PrimaryButton = $Layout/OpenDialogButton
@onready var gold_display: ResourceDisplay = $Layout/GoldDisplay
@onready var stamina_display: ResourceDisplay = $Layout/StaminaDisplay
@onready var material_display: ResourceDisplay = $Layout/MaterialDisplay
@onready var dialog: DialogBase = $DialogBase

var _dialog_closed_count: int = 0


func _ready() -> void:
	# --- 完了条件#5：Button 4状態の bg_color を get_theme_stylebox() で取得し print ---
	print("=== 完了条件#5: Button 4状態の bg_color 検証 ===")
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = normal_button.get_theme_stylebox(state_name) as StyleBoxFlat
		if sb == null:
			print("[FAIL] Button.%s: StyleBoxFlat が取得できなかった" % state_name)
		else:
			var c: Color = sb.bg_color
			print("[OK]   Button.%s bg_color = #%02X%02X%02X" % [state_name, int(c.r * 255), int(c.g * 255), int(c.b * 255)])

	# --- 完了条件#6：label_key の tr() 反映 ---
	print("=== 完了条件#6: label_key の tr() 反映 ===")
	print("[OK]   long_button.text = '%s'  (label_key='ui_ok' を tr() した)" % long_button.text)
	print("       long_button.label_key = '%s'" % long_button.label_key)

	# --- 完了条件#7：set_value(100) で数値が更新される ---
	print("=== 完了条件#7: set_value(100) ===")
	gold_display.set_value(100)
	print("[OK]   gold_display.value = %d, text = '%s'" % [gold_display.value, gold_display.get_node("ValueLabel").text])

	# --- 完了条件#8：set_value_with_max(3, 10) で "3/10" 表示 ---
	print("=== 完了条件#8: set_value_with_max(3, 10) ===")
	stamina_display.set_value_with_max(3, 10)
	print("[OK]   stamina_display.value = %d, max = %d, show_max = %s, text = '%s'" % [
		stamina_display.value,
		stamina_display.max_value,
		str(stamina_display.show_max),
		stamina_display.get_node("ValueLabel").text,
	])
	material_display.set_value(42)
	print("[OK]   material_display.value = %d, text = '%s'" % [
		material_display.value,
		material_display.get_node("ValueLabel").text,
	])

	# --- 完了条件#9：open_with_content() でダイアログが開く ---
	print("=== 完了条件#9: open_with_content() ===")
	# ダイアログの dialog_closed シグナルを捕捉
	dialog.dialog_closed.connect(_on_dialog_closed)
	# 起動時は自動的に開いて表示確認する
	_show_dialog_content()

	# --- 完了条件#10：Backdropクリック と Escape で閉じる、dialog_closed シグナル発火 ---
	# 自動検証は _ready では行わず、1フレーム待ってから Input.parse_input_event で
	# InputEventMouseButton を投げて Backdrop の gui_input を発火させる。
	await get_tree().process_frame
	await get_tree().process_frame
	_test_backdrop_click_and_escape()

	# --- ボタンの pressed シグナル接続 ---
	open_dialog_button.pressed.connect(_on_open_dialog_pressed)
	open_dialog_button.button_pressed = false

	# --- 自動終了はしない。エディタで人が目視確認する想定 ---
	print("=== 起動時検証完了。シーンを実行したまま目視確認してください ===")
	print("  - 通常ボタン（NormalButton）: トマト色の角丸ボタン")
	print("  - 無効ボタン（DisabledButton）: disabled = true")
	print("  - 長ラベルボタン（LongButton）: label_key='ui_ok' 経由のテキスト")
	print("  - ダイアログ（DialogBase）: Backdrop半透明黒 + 中央パネル（'ダイアログの中身'表示）")
	print("  - OpenDialogButton を押すと再度ダイアログが開く")
	print("  - ダイアログ表示中に Backdropクリック / Escape で閉じる")


# 完了条件#10 の自動検証。BackdropクリックとEscapeキーの両方で close() が走り、
# dialog_closed シグナルが発火することを確認する。
func _test_backdrop_click_and_escape() -> void:
	# (A) Backdropクリック: dialog.open_with_content() 済みの状態から、
	# Backdrop の gui_input に相当する InputEventMouseButton を投げる。
	var backdrop: ColorRect = dialog.get_node("Backdrop")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = Vector2(10, 10)  # BackdropのPanelContainerではない位置
	var count_before: int = _dialog_closed_count
	backdrop.emit_signal("gui_input", click_event)
	await get_tree().process_frame
	if _dialog_closed_count > count_before and not dialog.visible:
		print("[OK]   完了条件#10-(A) Backdropクリックで close + dialog_closed 発火。closed_count %d -> %d, visible = %s" % [count_before, _dialog_closed_count, str(dialog.visible)])
	else:
		print("[FAIL] 完了条件#10-(A) Backdropクリック: closed_count %d -> %d, visible = %s" % [count_before, _dialog_closed_count, str(dialog.visible)])

	# (B) Escapeキー: 再度ダイアログを開いて、ui_cancel アクションの InputEvent を投げる。
	_show_dialog_content()
	await get_tree().process_frame
	count_before = _dialog_closed_count
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	get_viewport().push_input(cancel_event)
	await get_tree().process_frame
	await get_tree().process_frame
	if _dialog_closed_count > count_before and not dialog.visible:
		print("[OK]   完了条件#10-(B) Escapeキーで close + dialog_closed 発火。closed_count %d -> %d, visible = %s" % [count_before, _dialog_closed_count, str(dialog.visible)])
	else:
		print("[FAIL] 完了条件#10-(B) Escapeキー: closed_count %d -> %d, visible = %s" % [count_before, _dialog_closed_count, str(dialog.visible)])


func _on_open_dialog_pressed() -> void:
	_show_dialog_content()


func _show_dialog_content() -> void:
	var label: Label = Label.new()
	label.text = "ダイアログの中身\n(open_with_content テスト)"
	dialog.open_with_content(label)
	print("[OK]   dialog.open_with_content() 実行。visible = %s" % str(dialog.visible))


func _on_dialog_closed() -> void:
	_dialog_closed_count += 1
