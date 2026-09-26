# res://scenes/adventure/run_relic_select.gd
# レリック選択（シナリオ・難ダンジョン共通。2026-09-19・人間の決定「全部推奨で」）。
#
# ⚠⚠ 前は floor_relic_select（行の一覧）と dungeon_relic_select（マス目）の2枚だった。
#   ⚠ 見た目は難ダンジョン側（マス目＋押した所の近くに詳細）に揃えて1枚にした。
# ⚠ どちらのランかは TransferKeys.RUN_KIND で受け取る。⚠ 器は別のまま（台帳 §7）。
#   ⚠ 候補を引く・取る・脱落を見るのは GameManager の *_run_relic* の口だけ（⚠ 種類で振り分ける）。
# ⚠ 選ばずに出られない（⚠ 戻るは無い）。⚠ 踏んだら必ず1つ取る（⚠ 両方とも前からこの形）。
#   ⚠ 前の dungeon_relic_select.gd の冒頭には「⚠ 戻るでマップへ出られる」とあったが、
#     ⚠ 戻るボタンは .tscn にもスクリプトにも無かった（⚠ 2026-09-19 に報告）。
# ⚠ 候補は入った瞬間に1回だけ引く。⚠ シナリオは呼ぶたびに引き直すので、⚠ 作り直しで引かない。
# ⚠ この画面は状態を持たない。⚠ 選んだら GameManager へ渡してマップへ戻る。
# ⚠⚠ 2026-09-26（回UI-4・手本 DungeonRelic・人間の選択「手本の形」＝決定 `RUN-11b`）：
#   ⚠ **紙のカード3枚**に名前・効き目・誰に効くかを直接書く。⚠ 選んだカードに「選んだ」の判。
#   ⚠ 下の紙に「付ける人」と「◯◯に付ける」。⚠ **右の常設の詳細は消した**（⚠ `RUN-10` を覆した）。
#   ⚠ 押す回数は1回増えた（⚠ カード → 人 → 付ける）。⚠ 全員用は人を選ばない。
#   ⚠ ヘッダの右に鞄と持っているレリック・3人の行（⚠ 難ダンジョンだけ）は前のまま。

extends Control

const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"

# ランの種類ごとの題と案内（⚠ 翻訳キーは寄せない＝人間の決定。⚠ 綴りを組み立てない）。
const FLOOR_TITLE_KEY: String = "ui_relic_select_title"
const FLOOR_HINT_KEY: String = "ui_relic_select_hint"
const DUNGEON_TITLE_KEY: String = "ui_dungeon_relic_select"
const DUNGEON_HINT_KEY: String = "ui_dungeon_relic_hint"

# ⚠ 脱落しているキャラのボタンは赤（UiButton の DANGER）。⚠ 押しても take_run_relic() の先が弾く。

@onready var title_label: Label = $Layout/Header/TitleLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var held_relic_grid: ItemGrid = $Layout/Header/HeldRelicGrid
@onready var party_list: RunPartyStrip = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var body: VBoxContainer = $Layout/Body
@onready var hint_label: Label = $Layout/Footer/HintLabel

# 持っているレリックにホバーしたときの詳細（⚠ 候補の詳細は右に常設なので、⚠ 見張るのはヘッダだけ）。
var _detail_popup: ItemDetailPopup = null

# どちらのランか（GameManager.RUN_KIND_*）。
var _kind: String = ""
# どのマスのレリックか。⚠ シナリオでは使わない（⚠ 渡し方だけ揃えてある）。
var _node_id: String = ""
# 入ったときに1回だけ引いた候補。
var _choices: Array = []
# 選んでいるレリック。⚠ 空なら選んでいない。
var _selected_relic_id: String = ""
# 付ける人（⚠ 1人用だけ）。⚠ 空なら選んでいない。
var _selected_character: String = ""
# relic_id -> カード（`RelicCard`）。
var _cards: Dictionary = {}
# 下の紙の中身（⚠ 選び直すたびに作り直す）。
var _action_row: HBoxContainer = null


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_kind = str(data.get(TransferKeys.RUN_KIND, ""))
	_node_id = str(data.get(TransferKeys.RUN_NODE_ID, ""))
	# ⚠ 右上の通貨は難ダンジョンだけ消す（2026-09-20・人間の指示「⚠ シナリオにもリソースを」）。
	#   ⚠ ランの種類を受け取ってから見る（⚠ 先に見ると必ずシナリオ扱いになる）。
	if _kind == GameManager.RUN_KIND_DUNGEON:
		ResourceHud.set_shown(false)

	# ⚠ どちらのランか分からない／ランに入っていない。⚠ 空の画面を描かない。
	if _kind != GameManager.RUN_KIND_FLOOR and _kind != GameManager.RUN_KIND_DUNGEON:
		push_warning("[RunRelicSelect] ランの種類が渡っていないので冒険選択へ戻る: '%s'" % _kind)
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return
	if not GameManager.is_in_run(_kind):
		push_warning("[RunRelicSelect] ランに入っていないのでマップへ戻る")
		SceneManager.change_scene(_map_path())
		return

	_choices = GameManager.get_run_relic_choices(_kind, _node_id)
	if _choices.is_empty():
		# 候補が引けないのに閉じ込めない。⚠ そのままマップへ返す。
		push_warning("[RunRelicSelect] 候補が0件なのでマップへ戻る")
		SceneManager.change_scene(_map_path())
		return

	var is_floor: bool = _kind == GameManager.RUN_KIND_FLOOR
	title_label.text = tr(FLOOR_TITLE_KEY if is_floor else DUNGEON_TITLE_KEY)
	hint_label.text = tr(FLOOR_HINT_KEY if is_floor else DUNGEON_HINT_KEY)
	message_label.text = tr("ui_relic_select_locked")
	bag_label.text = "%s %d/%d" % [
		tr("ui_dungeon_bag"), GameManager.get_run_bag_used(_kind), GameManager.get_run_bag_slots(_kind)
	]
	var held: Array = GameManager.get_run_relic_slot_entries(_kind)
	held_relic_grid.rebuild(held, held.size())
	held_relic_grid.visible = not held.is_empty()
	$Layout/Header/RelicSep.visible = held_relic_grid.visible
	party_list.refresh(_kind)
	# ⚠ ヘッダのレリックはホバーで詳細（⚠ 候補はカードに直接書くので見張らない）。
	_detail_popup = ItemDetailPopup.adopt(self, ItemDetail.new())
	if _detail_popup != null:
		_detail_popup.watch(held_relic_grid)
	_rebuild()


func _map_path() -> String:
	return FLOOR_MAP_PATH if _kind == GameManager.RUN_KIND_FLOOR else DUNGEON_MAP_PATH


func _rebuild() -> void:
	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.name = "Cards"
	cards_row.theme_type_variation = &"WideRow"
	body.add_child(cards_row)
	for index: int in _choices.size():
		var relic_id: String = str(_choices[index])
		# ⚠ カードは部品（`RelicCard`）。⚠ 傾きは並びの番号で決まる。
		var card: RelicCard = RelicCard.create(relic_id, index, "", true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_card_pressed.bind(relic_id))
		cards_row.add_child(card)
		_cards[relic_id] = card

	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "ActionSheet"
	sheet.show_corners = false
	body.add_child(sheet)
	_action_row = HBoxContainer.new()
	_action_row.name = "ActionRow"
	sheet.add_child(_action_row)
	_refresh_selection()


func _on_card_pressed(relic_id: String) -> void:
	if _selected_relic_id == relic_id:
		return
	_selected_relic_id = relic_id
	_selected_character = ""
	_refresh_selection()


func _on_character_pressed(character_id: String) -> void:
	_selected_character = character_id
	_refresh_selection()


# 選んでいるカードの見た目と、下の紙（付ける人・付ける）を作り直す。
#
# ⚠ 取れるかの判定は take_run_relic() の先が持つ。⚠ ここで条件を書かない（⚠ 脱落は押せなくするだけ）。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
func _refresh_selection() -> void:
	for relic_id: String in _cards:
		(_cards[relic_id] as RelicCard).set_chosen(relic_id == _selected_relic_id)

	for child in _action_row.get_children():
		_action_row.remove_child(child)
		child.queue_free()
	var caption: Label = Label.new()
	caption.theme_type_variation = &"SheetHeadingLabel"
	caption.text = tr("ui_relic_attach_to")
	_action_row.add_child(caption)

	var single: bool = _selected_relic_id != "" and GameManager.is_single_relic(_selected_relic_id)
	if single:
		for member: Variant in GameManager.get_party_members():
			var character_id: String = str(member)
			if character_id == "":
				continue
			var char_data: Dictionary = MasterDataLoader.get_character(character_id)
			var button: Button = Button.new()
			button.name = "Give_" + character_id
			button.text = tr(str(char_data.get("name_key", character_id)))
			button.theme_type_variation = (
				&"PaperChoiceSelected" if character_id == _selected_character else &"PaperChoice"
			)
			if GameManager.is_run_character_downed(_kind, character_id):
				button.text = "%s（%s）" % [button.text, tr("ui_dungeon_downed")]
				button.disabled = true
			button.pressed.connect(_on_character_pressed.bind(character_id))
			_action_row.add_child(button)
	elif _selected_relic_id != "":
		var everyone: Label = Label.new()
		everyone.theme_type_variation = &"CaptionLabel"
		everyone.text = tr("ui_relic_scope_party")
		_action_row.add_child(everyone)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_row.add_child(spacer)

	var take: UiButton = UiButton.new()
	take.name = "TakeButton"
	take.variant = UiButton.Variant.PRIMARY
	if _selected_relic_id == "":
		take.text = tr("ui_relic_take")
		take.disabled = true
	elif single and _selected_character == "":
		take.text = tr("ui_relic_pick_character")
		take.disabled = true
	elif single:
		var picked: Dictionary = MasterDataLoader.get_character(_selected_character)
		take.text = tr("ui_relic_give_to") % tr(str(picked.get("name_key", _selected_character)))
	else:
		take.text = tr("ui_relic_take")
	take.pressed.connect(_on_take_pressed.bind(_selected_character if single else ""))
	_action_row.add_child(take)


func _on_take_pressed(character_id: String) -> void:
	if not GameManager.take_run_relic(_kind, _node_id, _selected_relic_id, character_id):
		message_label.text = tr("ui_relic_take_failed")
		message_label.theme_type_variation = &"ErrorLabel"
		return
	SceneManager.change_scene(_map_path())
