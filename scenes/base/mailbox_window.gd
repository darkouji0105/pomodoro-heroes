class_name MailboxWindow
extends RefCounted

# メールボックスの窓（2026-10-19・回SEE29-B・決定 `NAV-36`）。
#
# ⚠ 人間「⚠ 知らせは、メールボックスにして、開いたら全部見えるように」→「⚠ １あ」（本部の右上に封筒と数・押すと窓で全部）
#   →「⚠ １い」（数は読んでいない知らせだけ）「⚠ ２アだが１００件」「⚠ ３ア」（今日の紙の「知らせ」の欄は消す）。
# ⚠ 窓の中：⚠ 上＝いまの用事（⚠ 用事のある施設＝`BaseTodaySheet.current_errands()`・押すとその画面へ）
#   ／ ⚠ 下＝届いた知らせ（⚠ 新しい順・まだ読んでいないものに「新」）。⚠ 開いたら全部読んだことにする。
# ⚠ 文は kind と args から毎回組み立てる（⚠ セーブに文を持たない＝CLAUDE.md 4番）。
# ⚠ 10-23（回MAIL-2）：⚠ 届く知らせ＝研究の自動 ／ 作業場の完成 ／ ショップの入れ替え ／ 初回の記録 ／ 鍛冶の腕 ／ 目標の達成。
# ⚠ 本部でしか使わない＝scenes/base/（AGENTS.md）。⚠ 大きさは Theme の `BaseDesk`。

const THEME_TYPE: StringName = &"BaseDesk"


static func open(host: Node) -> ModalDialog:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "MailboxScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var theme: Theme = ThemeDB.get_project_theme()
	scroll.custom_minimum_size.y = float(theme.get_constant(&"mail_height", THEME_TYPE))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "MailboxBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_add_errands(body)
	_add_mails(body)
	var dialog: ModalDialog = Modal.notify(host, "", [], false, {
		Modal.OPTION_TITLE: TranslationServer.translate("ui_mail_title"),
		Modal.OPTION_CONTENT: scroll,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})
	# ⚠ 「新」の印を描いたあとで読んだことにする（⚠ 今回は印が見える・次に開くと消える）。
	GameManager.mark_mails_read()
	return dialog


static func _heading(body: VBoxContainer, node_name: String, key: String) -> void:
	var heading: SheetHeading = SheetHeading.new()
	heading.name = node_name
	heading.title_key = key
	body.add_child(heading)


static func _caption(body: VBoxContainer, node_name: String, key: String) -> void:
	var none: Label = Label.new()
	none.name = node_name
	none.theme_type_variation = &"CaptionLabel"
	none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	none.text = TranslationServer.translate(key)
	body.add_child(none)


static func _add_errands(body: VBoxContainer) -> void:
	_heading(body, "ErrandsHeading", "ui_mail_errands")
	var shown: Array[Dictionary] = BaseTodaySheet.current_errands()
	if shown.is_empty():
		_caption(body, "NoErrands", "ui_base_today_none")
		return
	for entry: Dictionary in shown:
		var button: Button = Button.new()
		button.name = "Errand_" + str(entry[BaseTodaySheet.KEY_ID])
		button.theme_type_variation = &"DeskNoteButton"
		button.text = TranslationServer.translate(str(entry[BaseTodaySheet.KEY_TEXT]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(SceneManager.change_scene.bind(str(entry[BaseTodaySheet.KEY_PATH])))
		body.add_child(button)


static func _add_mails(body: VBoxContainer) -> void:
	_heading(body, "MailsHeading", "ui_mail_received")
	var mails: Array[Dictionary] = GameManager.get_mails()
	if mails.is_empty():
		_caption(body, "NoMails", "ui_mail_none")
		return
	for mail: Dictionary in mails:
		var row: LedgerRow = LedgerRow.new()
		row.name = "Mail_%d" % int(mail.get(GameStateKeys.MAIL_ID, 0))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		if not bool(mail.get(GameStateKeys.MAIL_READ, false)):
			var mark: Label = Label.new()
			mark.name = "NewMark"
			mark.theme_type_variation = &"ErrorLabel"
			mark.text = TranslationServer.translate("ui_mail_new")
			mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(mark)
		var text: Label = Label.new()
		text.name = "MailText"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text = text_of(mail)
		line.add_child(text)
		var at: Label = Label.new()
		at.name = "MailAt"
		at.theme_type_variation = &"CaptionLabel"
		at.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		at.text = _short_time(str(mail.get(GameStateKeys.MAIL_AT, "")))
		line.add_child(at)
		body.add_child(row)


# 知らせ1通の文（⚠ 種類ごと）。⚠ 知らない種類は種類の名前をそのまま（⚠ 漏れが見える）。
static func text_of(mail: Dictionary) -> String:
	var kind: String = str(mail.get(GameStateKeys.MAIL_KIND, ""))
	var args: Array = mail.get(GameStateKeys.MAIL_ARGS, []) as Array
	match kind:
		GameManager.MAIL_KIND_RESEARCH_AUTO:
			var names: PackedStringArray = PackedStringArray()
			for raw: Variant in args:
				names.append(ResearchCard.name_of(str(raw)))
			return TranslationServer.translate("ui_mail_research_auto") % [args.size(), TranslationServer.translate("ui_barracks_skill_separator").join(names)]
		# ⚠ 10-23（回MAIL-2）：⚠ ほかの出来事。
		GameManager.MAIL_KIND_CRAFT_DONE:
			return TranslationServer.translate("ui_mail_craft_done") % _item_name(args)
		GameManager.MAIL_KIND_SHOP_REFRESH:
			return TranslationServer.translate("ui_mail_shop_refresh")
		GameManager.MAIL_KIND_FIRST_RECORD:
			return TranslationServer.translate("ui_mail_first_record") % _item_name(args)
		GameManager.MAIL_KIND_FORGE_LEVEL:
			return TranslationServer.translate("ui_toast_forge_level_up") % (int(args[0]) if not args.is_empty() else 0)
		GameManager.MAIL_KIND_GOAL:
			return TranslationServer.translate("ui_mail_goal")
	return kind


static func _item_name(args: Array) -> String:
	var item_id: String = str(args[0]) if not args.is_empty() else ""
	return TranslationServer.translate(GameManager.item_name_key(item_id)) if item_id != "" else ""


# 「2026-10-19T15:04:05」→「10/19 15:04」。
static func _short_time(at: String) -> String:
	if at.length() < 16:
		return at
	return "%s/%s %s" % [at.substr(5, 2).lstrip("0"), at.substr(8, 2).lstrip("0"), at.substr(11, 5)]
