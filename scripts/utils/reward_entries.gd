class_name RewardEntries
extends RefCounted

# 報酬 Dictionary（{gold, gems, stamina, materials, inventory}）を画面に出す形へ組む（2026-09-17）。
#
# ⚠⚠ 倉庫の開封結果の窓（`chest_panel.gd`）と戦闘の結果窓（`battle_result_view.gd`）の2つが使う。
#   ⚠ 前は `chest_panel.gd` の中にあった。⚠ 同じものを2つ作らないためにここへ出した。
# ⚠ 静的関数なので `tr()` は呼べない（AGENTS.md）。⚠ `TranslationServer.translate()` を使う。
# ⚠ ここで GameManager の状態を読まないこと。⚠ 渡された報酬だけを見る。

# マスにならない資源（⚠ ゴールド・ジェム・スタミナ）。⚠ 並びは出す順。
const CURRENCY_KEYS: Array[String] = [
	GameStateKeys.REWARD_GOLD,
	GameStateKeys.REWARD_GEMS,
	GameStateKeys.REWARD_STAMINA,
]


# 報酬のうち **マスになるもの**（⚠ 素材と持ち物）。⚠ 個数はマスに出る。
# ⚠ 戻りは `ItemGrid.rebuild()` にそのまま渡せる形（⚠ マス1つ＝1要素）。
static func slot_entries(rewards: Dictionary) -> Array:
	var entries: Array = []
	for source: Variant in [
		rewards.get(GameStateKeys.REWARD_MATERIALS, {}),
		rewards.get(GameStateKeys.REWARD_INVENTORY, {}),
	]:
		if not (source is Dictionary):
			continue
		for item_id: String in (source as Dictionary):
			var count: int = int((source as Dictionary)[item_id])
			if count <= 0:
				continue
			entries.append({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
				GameManager.SLOT_ENTRY_ITEM_ID: item_id,
				GameManager.SLOT_ENTRY_INSTANCE_ID: "",
				GameManager.SLOT_ENTRY_GRADE: 0,
				GameManager.SLOT_ENTRY_COUNT: count,
				GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
			})
	return entries


# 報酬のうち **マスにならないもの**を `{資源のID: 量}` で返す。⚠ 0 は入れない。
# ⚠ 並びは `CURRENCY_KEYS` の順（⚠ Dictionary は入れた順を保つ）。
static func currency_amounts(rewards: Dictionary) -> Dictionary:
	var amounts: Dictionary = {}
	for key: String in CURRENCY_KEYS:
		var amount: int = int(rewards.get(key, 0))
		if amount > 0:
			amounts[key] = amount
	return amounts


# マスにならないものを1行の文字にする（⚠ 「ゴールド +50  ジェム +2」）。
static func currency_text(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	var amounts: Dictionary = currency_amounts(rewards)
	for key: String in amounts:
		parts.append("%s +%d" % [TranslationServer.translate("ui_res_" + key), int(amounts[key])])
	return "  ".join(parts)
