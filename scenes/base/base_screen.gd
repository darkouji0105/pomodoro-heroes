# res://scenes/base/base_screen.gd
# 本部（ギルド本部）の画面。AGENTS.md 準拠。
#
# ⚠⚠ 10-18（回UI-1018-6・web版の手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/` `05_base_*`・決定 `NAV-34`）：⚠ **作り直した**。
#   ⚠ 2つの見え方は**帯のタブで分ける**：⚠ 「本部」＝机（`BaseDesk`）／ ⚠ 「ギルド」＝ギルドを見渡す街（`BaseTownView`）。
#     ⚠ 前の右上の「拠点を見渡す／机に戻る」はやめた。⚠ 帯で押すと同じ画面を見え方つきで開き直す（`TransferKeys.BASE_VIEW`）。
#   ⚠ 右上は**設定のアイコンだけ**（⚠ 名前は触れると出る）。⚠ 「シナリオ」「UIテスト」は外した。
#   ⚠ 10-19（見る回29回目・人間「⚠ 右上のみっつんぼボタンは全部設定にする　セーブ保存はオートセーブにしたい」）：⚠ セーブのボタンをやめた（⚠ 自動セーブは画面を移るたび）・⚠ 「タイトルへ戻る」は設定のデータのタブへ。
#   ⚠ 下の列（宝箱・掲示板・ポモドーロ・続きから）はやめた＝⚠ 机の札が持つ。
# ⚠ 2026-10-05（回P-1）から自動セーブがある（`SaveManager.autosave()`）。⚠ ~~セーブのボタンは残す（「⚠ ｑ２　あ」）~~ → 10-19 にやめた。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const SETTINGS_PATH: String = "res://scenes/base/settings_screen.tscn"

const VIEW_DESK: String = "desk"
const VIEW_TOWN: String = "town"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: MarginContainer = $Margin/Layout/Body

var _view: String = VIEW_DESK
var _desk: BaseDesk = null
var _town_view: BaseTownView = null
var _mail_button: Button = null


func _ready() -> void:
	# ⚠ 朝4:00 の移し（2026-10-04・`TK-6`）。⚠ 紙を描く前に（⚠ 昨日終えたものを紙に残さない）。
	var _moved: int = GameManager.roll_over_done_tasks()
	# ⚠ 自動で研究（10-18・回UI-1018-7・`GR-12`）：⚠ 本部に着いたとき（⚠ ポモドーロや冒険から戻ったとき）に開く。⚠ 窓は出さず赤い栞。
	var _opened: Array[String] = GameManager.run_research_auto()
	var data: Dictionary = SceneManager.consume_transfer_data()
	_view = str(data.get(TransferKeys.BASE_VIEW, SceneManager.recall(TransferKeys.MEMORY_BASE_VIEW, VIEW_DESK)))
	if _view != VIEW_TOWN:
		_view = VIEW_DESK
	SceneManager.remember(TransferKeys.MEMORY_BASE_VIEW, _view)
	header.set_subtitle_text(tr("ui_hq_sub_town" if _view == VIEW_TOWN else "ui_hq_sub_desk"))
	_build_system_buttons()
	if _view == VIEW_TOWN:
		_town_view = BaseTownView.create()
		body.add_child(_town_view)
	else:
		_desk = BaseDesk.create()
		body.add_child(_desk)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.GUILD if _view == VIEW_TOWN else BaseFacilityBar.HQ)
	_show_arrival_rewards(data)


# ⚠ 検査用：⚠ いまの見え方。
func current_view() -> String:
	return _view


# ⚠ 右上（⚠ 通貨の左）：⚠ メールボックス・設定（⚠ アイコンだけ・名前は触れると出る）。
# ⚠ 10-19（回SEE29-B・`NAV-36`）：⚠ 封筒の右上に読んでいない知らせの数（⚠ 人間「⚠ １い」＝いまの用事は数えない）。
func _build_system_buttons() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SystemButtons"
	row.theme_type_variation = &"ButtonRow"
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for spec: Array in [
		["MailButton", IconTextures.NAME_SYS_MAIL, "ui_mail_open", _on_mail_pressed],
		["SettingsButton", IconTextures.NAME_SYS_SETTINGS, "ui_nav_settings", _on_settings_pressed],
	]:
		var button: Button = Button.new()
		button.name = str(spec[0])
		button.theme_type_variation = &"HqIconButton"
		button.icon = IconTextures.for_hq(str(spec[1]))
		button.tooltip_text = tr(str(spec[2]))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(spec[3] as Callable)
		row.add_child(button)
		if button.name == "MailButton":
			_mail_button = button
	_refresh_mail_badge()
	GameManager.mailbox_changed.connect(_refresh_mail_badge)
	# ⚠ 右上の通貨の手前（⚠ 見出しの「HUD のぶん空ける」より左）。
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	header.add_child(row)
	header.move_child(spacer, header.hud_spacer.get_index())
	header.move_child(row, header.hud_spacer.get_index())


# ポモドーロから戻ってきたときの受け取り報告。
#
# 報酬の受け取り自体はポモドーロ画面が済ませているが、
# あちらでモーダルを出しても直後の画面遷移で消えてしまうため、
# 数だけを転送データで受け取り、拠点に着いてから出す。
#
# 拠点へは他の画面からも戻ってくるので、キーが無ければ何もしない。
func _show_arrival_rewards(data: Dictionary) -> void:
	if data.is_empty():
		return
	var potions: int = int(data.get(TransferKeys.POMODORO_POTIONS, 0))
	var chests: int = int(data.get(TransferKeys.POMODORO_CHESTS, 0))
	if potions <= 0 and chests <= 0:
		return
	# ⚠ 0 のほうを読み上げない（2026-09-06・宿題「宝箱を0個」が不格好）。
	#   ⚠ 文の組み立てをコード側でつなげない（AGENTS.md）。⚠ 文ごとキーを分ける。
	# ⚠ 窓の指定は1つにまとめる（⚠ 3本とも同じ形。⚠ 決定 `MD-1` / `MD-3`）。
	# ⚠ 10-14（人間「⚠ 宝箱開けるような、演出付きの窓に」）：⚠ 窓の中で箱が開き、札が浮かび上がる（`RewardReveal`）。
	var chest_ids: Array = data.get(TransferKeys.POMODORO_CHEST_IDS, [])
	var options: Dictionary = {
		Modal.OPTION_TITLE: tr("ui_common_title_received"),
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CONTENT: RewardReveal.create(potions, chest_ids),
	}
	if chests <= 0:
		Modal.notify(self, "ui_base_potion_received", [potions], false, options)
	elif potions <= 0:
		Modal.notify(self, "ui_base_chest_received", [chests], false, options)
	else:
		Modal.notify(self, "ui_base_pomodoro_rewards", [potions, chests], false, options)


# ⚠ 封筒の数（⚠ 0 なら出さない）。⚠ 数の札は机の箱の数と同じ型（`DeskCountBadge`）。
func _refresh_mail_badge() -> void:
	if _mail_button == null or not is_instance_valid(_mail_button):
		return
	var old: Node = _mail_button.get_node_or_null("CountBadge")
	if old != null:
		_mail_button.remove_child(old)
		old.queue_free()
	var count: int = GameManager.get_unread_mail_count()
	if count <= 0:
		return
	var badge: Label = Label.new()
	badge.name = "CountBadge"
	badge.theme_type_variation = &"DeskCountBadge"
	badge.text = str(count)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = float(get_theme_constant(&"badge", &"BaseDesk"))
	badge.size = Vector2(side, side)
	badge.position = Vector2(_mail_button.get_combined_minimum_size().x - side * 0.6, -side * 0.4)
	# ⚠ 10-23（人間「⚠ 設定の右上の数字アイコンが裏にある」）：⚠ 札は封筒の右上からはみ出す＝⚠ 右隣の設定のボタンがあとから描かれて上に重なっていた。⚠ 前へ出す。
	badge.z_index = 1
	_mail_button.add_child(badge)


func _on_mail_pressed() -> void:
	var _dialog: ModalDialog = MailboxWindow.open(self)


func _on_settings_pressed() -> void:
	SceneManager.change_scene(SETTINGS_PATH)

