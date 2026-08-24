# res://scenes/adventure/party_preset_screen.gd
# パーティ選択画面（EXEC_PARTY_PRESETS.md §6）。GAME_DESIGN.md 5-5 / 13章。
#
# できること：プリセットの選択 ／ メンバーの差し替え ／ ビルド（スキル・割り振り）の切り替え。
# ⚠ 装備を選ぶ欄は作らない（GAME_DESIGN 13章「装備の変更はできない。ギルドで行う」）。
#   ⚠ プリセットの適用で装備が変わるのは別の話。禁じられているのは「この画面で装備を選ぶこと」。
#
# ⚠ モーダルを書かない（AGENTS.md の実例：モーダルの検証で1タスク溶かしている）。
#   メッセージは MessageLabel に出す。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。remove_child() してから queue_free()。

extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"

@onready var members_box: VBoxContainer = $Margin/Layout/Members
@onready var presets_box: VBoxContainer = $Margin/Layout/Scroll/Presets
@onready var message_label: Label = $Margin/Layout/MessageLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

# 「戻る」で帰る先。入口が2つあるので来た側が渡す（TransferKeys.RETURN_PATH）。
var _return_path: String = BASE_PATH

# 編成の候補（character_id の配列）。⚠ OptionButton の項目番号からIDを引くための表。
#   項目番号をそのまま character_id の代わりに使わないこと。デバッグビルドかどうかで
#   候補の件数が変わるため、本番ビルドで別のキャラが選ばれる。
var _party_candidates: Array[String] = []

# 枠ごとに「いまどのビルド番号を指しているか」。⚠ 押しただけでは状態を触らない
#   （EXEC_SKILL_SELECT.md §8-1 と同じ形。あそこで「押す＝解除」にして踏んでいる）。
#   焼く先と、編成プリセットを保存するときの参照先を決めるだけ。
var _selected_builds: Array[int] = []


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	var path: String = str(data.get(TransferKeys.RETURN_PATH, ""))
	if path != "":
		_return_path = path

	_party_candidates = GameManager.get_party_candidates()
	if _party_candidates.is_empty():
		push_error("[PartyPreset] 編成の候補が0件（characters.json が読めていない）")

	_selected_builds.resize(GameStateKeys.PARTY_SLOT_COUNT)
	_selected_builds.fill(0)

	message_label.text = ""
	back_button.pressed.connect(_on_back_pressed)
	_rebuild()


# 3行とも作り直す。⚠ 交換が起きると押した枠以外も変わるため。
func _rebuild() -> void:
	_rebuild_members()
	_rebuild_presets()


func _clear(box: Node) -> void:
	# ⚠ queue_free() だけだと、同じフレームに2本作ると行が二重に並ぶ（AGENTS.md）。
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


# --- いまの編成（3行） ---------------------------------------------

func _rebuild_members() -> void:
	_clear(members_box)

	var members: Array = GameManager.get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[PartyPreset] 編成が %d 件（%d のはず）" % [
			members.size(), GameStateKeys.PARTY_SLOT_COUNT
		])
		return

	for slot_index: int in range(GameStateKeys.PARTY_SLOT_COUNT):
		members_box.add_child(_make_member_row(slot_index, str(members[slot_index])))


func _make_member_row(slot_index: int, character_id: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MemberRow_%d" % slot_index

	# キャラを選ぶ。
	var picker: OptionButton = OptionButton.new()
	picker.name = "CharacterPicker_%d" % slot_index
	picker.size_flags_horizontal = 3
	for i: int in range(_party_candidates.size()):
		var candidate_id: String = _party_candidates[i]
		var char_data: Dictionary = MasterDataLoader.get_character(candidate_id)
		picker.add_item(tr(str(char_data.get("name_key", candidate_id))))
		if candidate_id == character_id:
			# ⚠ select() は item_selected を出さない。ここを「出す」書き方に変えると、
			#   行を作るたびにハンドラが走り、ハンドラが行を作り直すので固まる。
			picker.select(i)
	# ⚠ 接続は項目を入れ終わってから。先に繋ぐと add_item / select で発火しうる。
	picker.item_selected.connect(_on_character_selected.bind(slot_index))
	row.add_child(picker)

	# ビルド（キャラプリセット）を選ぶ。⚠ 押しても状態は変わらない。
	var build_picker: OptionButton = OptionButton.new()
	build_picker.name = "BuildPicker_%d" % slot_index
	var builds: Array = GameManager.get_character_presets(character_id)
	for i: int in range(GameManager.get_character_preset_count()):
		var label: String = tr("ui_party_preset_build") % (i + 1)
		var build: Variant = builds[i] if i < builds.size() else null
		var saved: bool = build is Dictionary and bool((build as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		if not saved:
			# ⚠ 未保存の番号も選べる（焼く先として要る）。
			label += "（%s）" % tr("ui_party_preset_empty")
		build_picker.add_item(label)
	build_picker.select(clampi(_selected_builds[slot_index], 0, GameManager.get_character_preset_count() - 1))
	build_picker.item_selected.connect(_on_build_selected.bind(slot_index))
	row.add_child(build_picker)

	# 「焼く」：いまのそのキャラの状態を、選んでいる番号へ書き写す。
	var burn: PrimaryButton = PrimaryButton.new()
	burn.name = "BurnButton_%d" % slot_index
	burn.text = "ui_party_preset_burn"
	burn.pressed.connect(_on_burn_pressed.bind(slot_index))
	row.add_child(burn)

	return row


func _on_character_selected(item_index: int, slot_index: int) -> void:
	# ⚠ item_index をそのまま character_id に使わないこと（_party_candidates の注記）。
	if item_index < 0 or item_index >= _party_candidates.size():
		push_error("[PartyPreset] 編成の候補の番号が範囲外: %d" % item_index)
		return
	# ⚠ 押した枠以外も変わりうる（同じキャラが別の枠に居ると交換になる）。3つとも作り直す。
	GameManager.set_party_member(slot_index, _party_candidates[item_index])
	message_label.text = ""
	_rebuild()


func _on_build_selected(item_index: int, slot_index: int) -> void:
	# ⚠ ここでは状態を触らない。焼く先と参照先が変わるだけ。
	_selected_builds[slot_index] = item_index


func _on_burn_pressed(slot_index: int) -> void:
	var members: Array = GameManager.get_party_members()
	if slot_index >= members.size():
		return
	GameManager.save_character_preset(str(members[slot_index]), _selected_builds[slot_index])
	message_label.text = ""
	_rebuild()


# --- 編成プリセット（10行） ----------------------------------------

func _rebuild_presets() -> void:
	_clear(presets_box)

	var presets: Array = GameManager.get_party_presets()
	# ⚠ 10 と書かない。件数は GameManager から引く。
	for index: int in range(GameManager.get_party_preset_count()):
		var preset: Variant = presets[index] if index < presets.size() else null
		presets_box.add_child(_make_preset_row(index, preset))


func _make_preset_row(index: int, preset: Variant) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow_%d" % index

	var saved: bool = preset is Dictionary and bool((preset as Dictionary).get(GameStateKeys.PRESET_SAVED, false))

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr("ui_party_preset_slot") % (index + 1)
	row.add_child(name_label)

	var summary: Label = Label.new()
	summary.name = "SummaryLabel"
	summary.size_flags_horizontal = 3
	summary.text = _summarize(preset) if saved else tr("ui_party_preset_empty")
	if not saved:
		summary.modulate = Color(0.5, 0.5, 0.5)
	row.add_child(summary)

	var apply: PrimaryButton = PrimaryButton.new()
	apply.name = "ApplyButton"
	apply.text = "ui_party_preset_apply"
	# ⚠ disabled にするのは「空き」のときだけ。参照先のビルドが空かどうかで
	#   出し分けない（押して理由が出るほうが分かる）。
	apply.disabled = not saved
	apply.pressed.connect(_on_apply_pressed.bind(index))
	row.add_child(apply)

	var save: PrimaryButton = PrimaryButton.new()
	save.name = "SaveButton"
	save.text = "ui_party_preset_save"
	save.pressed.connect(_on_save_pressed.bind(index))
	row.add_child(save)

	var clear: PrimaryButton = PrimaryButton.new()
	clear.name = "ClearButton"
	clear.text = "ui_party_preset_clear"
	clear.disabled = not saved
	clear.pressed.connect(_on_clear_pressed.bind(index))
	row.add_child(clear)

	return row


# 「僧侶 ビルド1 / 弓兵 ビルド3 / 剣士 ビルド1」の形。
#
# ⚠ 中身は複製せず、参照先を読んで組み立てる（参照方式なので、キャラ側のビルドを
#   直すとここの表示も次の再描画で追従する）。
# ⚠ 当初は「僧侶(1)」と括弧の数字だけにしていたが、⚠ 何番のビルドか読めなかった
#   （人間の指摘・2026-08-23）。⚠ 「いまの編成」の OptionButton と同じ
#   ui_party_preset_build を使うこと。2通りの呼び方を作らない。
func _summarize(preset: Variant) -> String:
	if not (preset is Dictionary):
		return ""
	var slots: Variant = (preset as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
	if not (slots is Array):
		return ""
	var parts: Array[String] = []
	for entry: Variant in (slots as Array):
		if not (entry is Dictionary):
			continue
		var character_id: String = str((entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var preset_index: int = int((entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		parts.append("%s %s" % [
			tr(str(char_data.get("name_key", character_id))),
			tr("ui_party_preset_build") % (preset_index + 1),
		])
	return " / ".join(parts)


func _on_apply_pressed(index: int) -> void:
	var report: Dictionary = GameManager.apply_party_preset(index)
	# ⚠ 文面は GameManager が組む。⚠ 適用の口が3つ（ここ・育成・装備）あるので、
	#   画面ごとに書くと言い回しが3通りになる。
	message_label.text = GameManager.format_apply_report(report)
	# ⚠ 選んでいるビルド番号も、適用した編成に合わせ直す。
	_sync_selected_builds(report)
	_rebuild()


func _on_save_pressed(index: int) -> void:
	# ⚠ 「いまの編成」3行の（キャラ, ビルド番号）をそのまま焼く（現在の状態を焼く形）。
	var members: Array = GameManager.get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		return
	var slots: Array = []
	for slot_index: int in range(GameStateKeys.PARTY_SLOT_COUNT):
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: str(members[slot_index]),
			GameStateKeys.PRESET_INDEX: _selected_builds[slot_index],
		})
	GameManager.save_party_preset(index, slots)
	message_label.text = ""
	_rebuild()


func _on_clear_pressed(index: int) -> void:
	GameManager.clear_party_preset(index)
	message_label.text = ""
	_rebuild()


# 適用した編成の参照先を、画面の選択状態にも反映する。
func _sync_selected_builds(report: Dictionary) -> void:
	if not bool(report.get(GameManager.APPLY_OK, false)):
		return
	var presets: Array = GameManager.get_party_presets()
	var members: Array = report.get(GameManager.APPLY_MEMBERS, [])
	for slot_index: int in range(mini(members.size(), _selected_builds.size())):
		for entry: Variant in presets:
			if not (entry is Dictionary):
				continue
			var slots: Variant = (entry as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
			if not (slots is Array):
				continue
			for slot_entry: Variant in (slots as Array):
				if not (slot_entry is Dictionary):
					continue
				if str((slot_entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, "")) == str(members[slot_index]):
					_selected_builds[slot_index] = int((slot_entry as Dictionary).get(GameStateKeys.PRESET_INDEX, 0))
					break


func _on_back_pressed() -> void:
	# 履歴に依存せず明示的に帰る（base_screen.gd と同じ流儀）。
	SceneManager.change_scene(_return_path)
