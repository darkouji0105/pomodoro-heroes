class_name RunPartyStrip
extends HBoxContainer

# 3人の「戦闘時 MAX HP」の行（2026-09-19・難ダンジョンのモック v2）。
#
# ⚠ 使う画面：難ダンジョンのマップ ／ レリック選択 ／ ボスの間の商人（⚠ 2画面以上＝components）。
# ⚠ 1人ぶん＝名前と今の値（明るい）＋「/素の値」（暗い）。⚠ 脱落は赤（Theme の ErrorLabel）。
#   ⚠ どれだけ目減りしたかが読めないと、ポーションを使う判断ができない（§4-4）。
#   ⚠ 脱落した人の行を消さないこと。消すと「誰が欠けたか」が分からないまま3人目で死亡する。
# ⚠ シナリオには「戦闘時 MAX HP」が無い。⚠ シナリオでは何も出さない（⚠ 行ごと隠す）。
# ⚠ 値は GameManager の口に聞くだけ。⚠ 再描画に await を持たせない（AGENTS.md）。


func _init() -> void:
	theme_type_variation = &"WideRow"


func refresh(kind: String) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = kind == GameManager.RUN_KIND_DUNGEON
	if not visible:
		return
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		var cell: HBoxContainer = HBoxContainer.new()
		cell.name = "Party_" + character_id
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var name_text: String = tr(str(char_data.get("name_key", character_id)))
		var main: Label = Label.new()
		main.name = "Value"
		cell.add_child(main)
		if GameManager.is_dungeon_character_downed(character_id):
			main.text = "%s %s" % [name_text, tr("ui_dungeon_downed")]
			main.theme_type_variation = &"ErrorLabel"
		else:
			main.text = "%s %d" % [name_text, GameManager.get_dungeon_character_max_hp(character_id)]
			var base: Label = Label.new()
			base.name = "Base"
			base.theme_type_variation = &"CaptionLabel"
			base.text = "/%d" % GameManager.get_dungeon_base_max_hp(character_id)
			cell.add_child(base)
		add_child(cell)
