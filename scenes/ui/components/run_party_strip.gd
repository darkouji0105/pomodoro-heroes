class_name RunPartyStrip
extends HBoxContainer

# 3人の「戦闘時 MAX HP」の行（2026-09-19・難ダンジョンのモック v2）。
#
# ⚠ 使う画面：難ダンジョンのマップ ／ レリック選択 ／ ボスの間の商人（⚠ 2画面以上＝components）。
# ⚠ 1人ぶん＝名前・バー（RunHpBar）・今の値＋「/素の値」（暗い）。⚠ 脱落は赤（Theme の ErrorLabel）。
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
		# ⚠ 1人ぶん＝［名前］［バー］［今の値 /素の値］（2026-09-20・人間の指示「HPをバーにして見やすく」）。
		var cell: HBoxContainer = HBoxContainer.new()
		cell.name = "Party_" + character_id
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var name_label: Label = Label.new()
		name_label.name = "Name"
		name_label.text = tr(str(char_data.get("name_key", character_id)))
		cell.add_child(name_label)

		var base_max_hp: int = GameManager.get_dungeon_base_max_hp(character_id)
		var max_hp: int = GameManager.get_dungeon_character_max_hp(character_id)
		var downed: bool = GameManager.is_dungeon_character_downed(character_id)
		var bar: RunHpBar = RunHpBar.new()
		bar.name = "Bar"
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.set_values(0 if downed else max_hp, base_max_hp)
		cell.add_child(bar)

		var value: Label = Label.new()
		value.name = "Value"
		value.text = tr("ui_dungeon_downed") if downed else "%d" % max_hp
		if downed:
			value.theme_type_variation = &"ErrorLabel"
		cell.add_child(value)
		# ⚠ 素の MAX HP は暗く添える（⚠ 脱落中は「脱落」だけ）。
		if not downed:
			var base: Label = Label.new()
			base.name = "Base"
			base.theme_type_variation = &"CaptionLabel"
			base.text = "/%d" % base_max_hp
			cell.add_child(base)
		add_child(cell)
