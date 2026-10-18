# res://scenes/ui/components/item_view.gd
# 品の見せ方の文字（2026-10-18・回UI-1018-1）。⚠ マス・行・触れると出る札・一括分解で**同じ文字**を出すための1か所。
#
# ⚠ 扱うのは「マスの形」の Dictionary（`GameManager.SLOT_ENTRY_*`）。⚠ 装備の個体は `instance_entry()` で包む。
# ⚠ 値は毎回マスターから引く（CLAUDE.md 4番）。⚠ ここで状態を変えない。

class_name ItemView
extends RefCounted


# ⚠ 個体をマスの形に包む（⚠ 持ち物の画面にあったものを共通へ移した）。⚠ 無い個体は空。
static func instance_entry(instance_id: String) -> Dictionary:
	var instance: Dictionary = GameManager.get_equipment_instance(instance_id)
	if instance.is_empty():
		return {}
	return {
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
		GameManager.SLOT_ENTRY_INSTANCE_ID: instance_id,
		GameManager.SLOT_ENTRY_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: owner_of_instance(instance_id),
	}


# `get_owned_instances()` の1件をマスの形に（⚠ 持ち主は view が持っている＝⚠ 引き直さない）。
static func entry_of_view(view: Dictionary) -> Dictionary:
	return {
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: str(view.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
		GameManager.SLOT_ENTRY_INSTANCE_ID: str(view.get(GameManager.INSTANCE_VIEW_ID, "")),
		GameManager.SLOT_ENTRY_GRADE: int(view.get(GameStateKeys.INSTANCE_GRADE, 1)),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, "")),
	}


static func owner_of_instance(instance_id: String) -> String:
	for view: Variant in GameManager.get_owned_instances():
		if str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
			return str((view as Dictionary).get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
	return ""


static func is_instance(entry: Dictionary) -> bool:
	return str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) == GameManager.SLOT_KIND_INSTANCE


static func item_id_of(entry: Dictionary) -> String:
	return str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))


static func instance_id_of(entry: Dictionary) -> String:
	return str(entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))


# ⚠ 一覧の鍵（⚠ 個体なら instance_id・それ以外は item_id）。
static func key_of(entry: Dictionary) -> String:
	return instance_id_of(entry) if is_instance(entry) else item_id_of(entry)


# ⚠ マスに出す等級（⚠ 装備＝個体の等級 ／ 装飾・素材＝段を等級の色へ写したもの＝`ItemIcon.grade_of()`）。
static func grade_of(entry: Dictionary) -> int:
	var grade: int = int(entry.get(GameManager.SLOT_ENTRY_GRADE, 0))
	return int(ItemIcon.grade_of(item_id_of(entry), grade).get(ItemIcon.RESULT_GRADE, 1))


static func is_special(entry: Dictionary) -> bool:
	return GameManager.get_item_special_effect(item_id_of(entry)) != ""


static func slot_of(entry: Dictionary) -> String:
	return str(MasterDataLoader.get_item(item_id_of(entry)).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))


static func name_text(entry: Dictionary) -> String:
	return TranslationServer.translate(GameManager.item_name_key(item_id_of(entry)))


# 「武器・等級10・★」／「装飾・段3」／「素材」。
static func sub_text(entry: Dictionary) -> String:
	var parts: Array[String] = []
	if is_instance(entry):
		var slot: String = slot_of(entry)
		if slot != "":
			parts.append(TranslationServer.translate("ui_equipment_slot_" + slot))
		parts.append(TranslationServer.translate("ui_equipment_grade") % int(entry.get(GameManager.SLOT_ENTRY_GRADE, 1)))
		if is_special(entry):
			parts.append(TranslationServer.translate("ui_eqfx_star"))
	elif not GameManager.get_part_definition(item_id_of(entry)).is_empty():
		parts.append(TranslationServer.translate("ui_belongings_tab_part"))
	else:
		parts.append(TranslationServer.translate("ui_belongings_tab_material"))
	return TranslationServer.translate("ui_barracks_skill_separator").join(parts)


# 装備の値（⚠ 個体だけ。⚠ それ以外は空）。
static func stats_of(entry: Dictionary) -> Dictionary:
	if not is_instance(entry):
		return {}
	return GameManager.get_instance_stats(instance_id_of(entry))


# ⚠ 主な値の軸（⚠ 一番大きい値＝`BelongingsDetail.main_stat_of()` と同じ決め方）。
static func main_stat_key(entry: Dictionary) -> String:
	if is_instance(entry):
		return BelongingsDetail.main_stat_of(stats_of(entry))
	var part: Dictionary = GameManager.get_part_definition(item_id_of(entry))
	return str(part.get(GameManager.ITEM_MASTER_PART_STAT, ""))


# 「+58」（⚠ 装飾は値の幅「+3〜+5」）。
static func main_value_text(entry: Dictionary) -> String:
	var stat_key: String = main_stat_key(entry)
	if stat_key == "":
		return ""
	if is_instance(entry):
		return BelongingsDetail.stat_text(stat_key, int(stats_of(entry).get(stat_key, 0)))
	return BelongingsDetail.part_range_text(item_id_of(entry))


# ⚠ 主な値の次の値たち（「攻撃速度 +17%」）。⚠ 0 の軸は出さない。
static func other_stats_text(entry: Dictionary) -> String:
	if not is_instance(entry):
		return ""
	var stats: Dictionary = stats_of(entry)
	var main: String = main_stat_key(entry)
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int(stats.get(stat_key, 0))
		if value == 0 or stat_key == main:
			continue
		parts.append("%s %s" % [TranslationServer.translate("ui_training_stat_" + stat_key), BelongingsDetail.stat_text(stat_key, value)])
	return "  ".join(parts)


static func owner_name(entry: Dictionary) -> String:
	var owner: String = str(entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if owner == "":
		return ""
	return TranslationServer.translate(str(MasterDataLoader.get_character(owner).get("name_key", owner)))


static func count_of(entry: Dictionary) -> int:
	return int(entry.get(GameManager.SLOT_ENTRY_COUNT, ItemIcon.NO_COUNT))
