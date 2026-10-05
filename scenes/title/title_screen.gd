extends Control

# タイトル画面（⚠ 2026-09-27 に手本 Title へ組み替えた・回UI-4）。
#
# ⚠ 吊り看板（盾の紋章・冒険者ギルド・明朝の題・飾り罫）＋ 縦のボタン。
# ⚠ ボタン：セーブが在れば「つづきから（真鍮）｜はじめから（革）｜終わる」、⚠ 無ければ「はじめから（真鍮）｜終わる」。
# ⚠ 「はじめから」は**セーブを消して新しく始める**（⚠ 手本 Confirm「はじめからやり直す」・長押し＝決定 `MD-11`）。
# ⚠ 手本の「設定」は出さない（⚠ 設定画面がまだ無い＝`BS-13`・回UI-仕組み）。⚠ 押しても何も起きないボタンを置かない。
# ⚠ 看板の吊り紐と紋章は線で描く。⚠ 値は Theme の `TitleSign` 型（⚠ ここに数字を書かない）。

const THEME_TYPE: StringName = &"TitleSign"

@onready var start_button: UiButton = $Center/Stack/ButtonContainer/StartButton
@onready var restart_button: UiButton = $Center/Stack/ButtonContainer/RestartButton
@onready var quit_button: UiButton = $Center/Stack/ButtonContainer/QuitButton
@onready var sign_panel: PanelContainer = $Center/Stack/Sign
@onready var sign_stack: VBoxContainer = $Center/Stack/Sign/Inner/SignStack
@onready var crest: Control = $Center/Stack/Sign/Inner/SignStack/Crest
@onready var title_label: Label = $Center/Stack/Sign/Inner/SignStack/TitleLabel
@onready var error_label: Label = $ErrorLabel

func _ready() -> void:
	# ⚠ タイトルに通貨は出さない（⚠ 手本 Title。⚠ セーブを読む前の数字は意味が無い）。
	ResourceHud.set_shown(false)
	# ⚠ タイトルにいる間は自動セーブしない（2026-10-05・回P-1）。⚠ 始めたら `begin_session()`。
	SaveManager.end_session()
	_build_sign()
	var width: float = float(get_theme_constant(&"button_width", THEME_TYPE))
	var height: float = float(get_theme_constant(&"button_height", THEME_TYPE))
	for button: UiButton in [start_button, restart_button, quit_button]:
		button.custom_minimum_size = Vector2(width, height)
	_refresh_ui()
	start_button.pressed.connect(_on_start_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


# ⚠ 看板の飾り（⚠ 紋章の大きさ・題の下の飾り罫・吊り紐）。
func _build_sign() -> void:
	crest.custom_minimum_size = Vector2(
		float(get_theme_constant(&"crest_width", THEME_TYPE)),
		float(get_theme_constant(&"crest_height", THEME_TYPE))
	)
	crest.draw.connect(_draw_crest)
	var ornament: SheetHeading = SheetHeading.new()
	ornament.name = "Ornament"
	ornament.ornament = true
	ornament.ornament_below = true
	ornament.custom_minimum_size.x = float(get_theme_constant(&"ornament_width", THEME_TYPE))
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sign_stack.add_child(ornament)
	sign_panel.draw.connect(_draw_strings)


# ⚠ 看板の上に吊り紐2本（⚠ 看板の外へはみ出して描く）。
func _draw_strings() -> void:
	var color: Color = get_theme_color(&"string", THEME_TYPE)
	var length: float = float(get_theme_constant(&"string_length", THEME_TYPE))
	var width: float = float(get_theme_constant(&"string_width", THEME_TYPE))
	var at: float = float(get_theme_constant(&"string_at_pct", THEME_TYPE)) / 100.0
	for x: float in [sign_panel.size.x * at, sign_panel.size.x * (1.0 - at)]:
		sign_panel.draw_line(Vector2(x, -length), Vector2(x, 0.0), color, width)


# ⚠ 盾の紋章（⚠ 手本の SVG を 34 × 38 の升目のまま写した）。⚠ 盾・交差した2本・真ん中の穴。
func _draw_crest() -> void:
	var color: Color = get_theme_color(&"crest", THEME_TYPE)
	var hole: Color = get_theme_color(&"crest_hole", THEME_TYPE)
	var line: float = float(get_theme_constant(&"crest_line", THEME_TYPE))
	var k: Vector2 = crest.size / Vector2(34.0, 38.0)
	var shield: PackedVector2Array = PackedVector2Array([Vector2(17, 2), Vector2(31, 7), Vector2(31, 18)])
	shield.append_array(_bezier(Vector2(31, 18), Vector2(31, 27), Vector2(24, 33), Vector2(17, 36)))
	shield.append_array(_bezier(Vector2(17, 36), Vector2(10, 33), Vector2(3, 27), Vector2(3, 18)))
	shield.append_array(PackedVector2Array([Vector2(3, 7), Vector2(17, 2)]))
	for i: int in shield.size():
		shield[i] *= k
	crest.draw_polyline(shield, color, line, true)
	crest.draw_line(Vector2(11, 12) * k, Vector2(23, 26) * k, color, line, true)
	crest.draw_line(Vector2(23, 12) * k, Vector2(11, 26) * k, color, line, true)
	var center: Vector2 = Vector2(17, 19) * k
	var radius: float = 3.2 * k.x
	crest.draw_circle(center, radius, hole)
	crest.draw_arc(center, radius, 0.0, TAU, 32, color, line, true)


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(1, 13):
		var t: float = float(step) / 12.0
		var u: float = 1.0 - t
		points.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return points


# セーブの有無に応じてボタン表示を更新する。
# 警告ラベルもここで隠すため、メッセージを出す処理より先に呼ぶこと。
func _refresh_ui() -> void:
	if SaveManager.has_save():
		start_button.label_key = "ui_title_start_continue"
		restart_button.visible = true
	else:
		start_button.label_key = "ui_title_start_new"
		restart_button.visible = false
	error_label.visible = false

func _on_start_pressed() -> void:
	# ⚠ 「新規開始か」を決めているのはここ1箇所だけ。2本目を作らないこと。
	var start_new: bool = true
	if SaveManager.has_save():
		if SaveManager.load_game():
			start_new = false
		else:
			# 読み込み失敗。閉じるまで待ってから新規開始として続行する。
			# 以前は2秒待つ実装だったが、読み切る前に消えるおそれがあった。
			# モーダルなら本人が閉じるまで残る。
			start_button.disabled = true
			restart_button.disabled = true
			var dlg: ModalDialog = Modal.notify(self, "ui_title_load_failed", [], false, {
				Modal.OPTION_TITLE: tr("ui_common_title_save"),
			})
			if dlg != null:
				await dlg.closed

	# ⚠ 状態を作り直す。これが無いと
	#     つづきから → 遊ぶ → タイトルへ戻る → セーブを削除 → 最初から
	#   でメモリ上の状態が残り、⚠ 「セーブを消しても消えない」に見える
	#   （2026-08-24に人間が実機で発見）。
	# ⚠ 起動直後に押したときも通るが、_ready() と同じ処理なので結果は変わらない。
	# ⚠ 版が違って読めなかったときも通す（あの枝は「新規開始として続行する」）。
	if start_new:
		GameManager.reset_to_new_game()

	# ⚠ ここから自動セーブ（2026-10-05・回P-1）。⚠ 読み込み・新規の両方がここを通る。
	SaveManager.begin_session()
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")

# 「はじめから」＝セーブを消して新しく始める。取り返しがつかない。必ず確認する。
# ⚠ 消したあとは `_on_start_pressed()` を通す（⚠ 「新規開始か」を決める口を2本にしない）。
func _on_restart_pressed() -> void:
	# ⚠⚠ セーブを消すと戻らないので実行を赤に（決定 `MD-5`）。
	var confirmed: bool = await Modal.confirm(self, "ui_title_restart_confirm", [], false, {
		Modal.OPTION_TITLE: tr("ui_title_restart_title"),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_title_delete_save_hold",
		Modal.OPTION_STAMP: "ui_stamp_erased",
		# ⚠ いちばん重いものは長押し（決定 `MD-11`・09-27 人間「⚠ セーブは長押し」）。
		Modal.OPTION_HOLD: "ui_title_delete_hold_hint",
	})
	if not confirmed:
		return

	var ok: bool = SaveManager.delete_save()
	# _refresh_ui() が error_label を隠すため、必ずメッセージ表示より先に呼ぶ
	_refresh_ui()
	if not ok:
		Modal.notify(self, "ui_title_delete_failed", [], false, {Modal.OPTION_TITLE: tr("ui_common_title_save")})
		return
	_on_start_pressed()


func _on_quit_pressed() -> void:
	get_tree().quit()
