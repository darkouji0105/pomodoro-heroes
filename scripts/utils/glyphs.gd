class_name Glyphs
extends RefCounted

# 見た目の簡略表現（段階19-a・人間の指示「絵文字と文字と色で簡略的に表現する」）。
#
# ⚠⚠ **絵文字を書く場所はこのファイル1本だけ。** ⚠ 画面のコードに絵文字を直接書かないこと。
#   ⚠ フォントを差し替えたとき、⚠ ここだけ直せば全画面が入れ替わる状態を保つ。
#
# 【フォントの実測（2026-09-04）】⚠ 思いついた絵文字が在るとは限らない。
#
#   NotoSansJP-VariableFont_wght.ttf … 16,732 字。⚠ **絵文字は1文字も無い**
#   segoe-ui-emoji.ttf（fallback）    … ⚠ **1,274 字だけ**（COLR/CPAL のカラー絵文字）
#
#   ⚠ 無かったもの（豆腐になる）：⚔ 🗡 🛡 🧪 🏹 🪖 🪵 🧱 🛏 ⛑ 📿 🏅 🎖 🤺 🦄
#   ⚠ 在ったもの：👑 👹 👺 👻 💀 🐉 🐺 🐸 💂 🎯 😇 👕 👟 💍 💎 🔯 💠 📜 🔩 💊 🍷 🎁 🏰 🔥 ❓ 🔦
#
# ⚠⚠ **足したら必ず `scenario=glyphs` を回して NG が0件であることを確かめる。**
#   ⚠ ヘッドレスでは絵は出ないが、⚠ 「その字がフォントに在るか」は has_char() で取れる。
#
# ⚠ tr() は使わない（AGENTS.md「静的関数から tr() は呼べない」）。⚠ 絵文字は
#   言語で変わらないので ja.csv に置かない（⚠ `ui_icon_*` の漢字2文字とはそこが違う）。

# --- 味方（characters.json） ---
const CHAR_SWORDSMAN: String = "💂"
const CHAR_ARCHER: String = "🎯"
const CHAR_PRIEST: String = "😇"
## ⚠ 表に無いキャラ（検証用の char_debug_* を含む）。
const CHAR_FALLBACK: String = "👤"

# --- 敵（enemies.json） ---
const ENEMY_SLIME: String = "🐸"
const ENEMY_WOLF: String = "🐺"
const ENEMY_BOSS_SLIME_KING: String = "👑"
## ⚠ 表に無い敵（検証用の enemy_dbg_* を含む）。
const ENEMY_FALLBACK: String = "👿"
## ⚠ 召喚（summons.json）。⚠ 敵味方どちらにも出る。
const SUMMON: String = "👻"

# --- アイテム（items.json） ---
#
# ⚠⚠ item_id ごとではなく「種類ごと」に持つ。⚠ 91件ぶんの表を作らない。
#   ⚠ フォントに武器・防具の絵文字がほとんど無く（🗡 ⚔ 🛡 🪖 がどれも無い）、
#     ⚠ 個別に当てようとすると豆腐が並ぶ。
#   ⚠ 「どの品か」は ItemIcon の漢字2文字（ui_icon_*・78行）が引き続き受け持つ。
#     ⚠ 絵文字は「どの種類か」だけを言う＝2つで役割が分かれている。
const ITEM_WEAPON: String = "🔪"
const ITEM_HEAD: String = "🎩"
const ITEM_ARMOR: String = "👕"
const ITEM_LEGS: String = "👟"
const ITEM_ACCESSORY: String = "💍"
const ITEM_GEM: String = "💎"
const ITEM_CHARM: String = "🔯"
const ITEM_EMBLEM: String = "💠"
const ITEM_RUNE: String = "📜"
const ITEM_MATERIAL: String = "🔩"
const ITEM_CONSUMABLE: String = "💊"
## ⚠ ラン専用の品（ITEM_TYPE_DUNGEON）。⚠ 効果で分ける（回復／蘇生）。
const ITEM_POTION_HEAL: String = "🍷"
const ITEM_POTION_REVIVE: String = "❤"
## ⚠ 種類が分からない品。
const ITEM_FALLBACK: String = "📦"
## ⚠ レリック（relics.json）。⚠ items.json に無いので別枠。
const RELIC: String = "🔮"

# --- ステータスの10軸（2026-09-08・人間の指示「⚠ ステータスの種類ごとにアイコンを」）---
#
# ⚠⚠ フォントに `⚔` `🗡` `🛡` は無い（⚠ `scenario=glyphs` の「候補の下見」で実測）。
#   ⚠ 在る38件の中から、⚠ アイテムの種類やマスの絵文字と **ぶつからないもの**を選んである。
#   ⚠ 例：⚠ HP に `❤` を使わないのは、⚠ それが蘇生ポーションの絵だから。
# ⚠ 軸の並びと意味は GAME_DESIGN.md 8-1。⚠ 軸を増やしたらここにも足す。
const STAT_HP: String = "💗"
const STAT_ATK: String = "👊"
const STAT_MAG: String = "✨"
const STAT_DEF: String = "🔰"
const STAT_MDEF: String = "🌀"
const STAT_ATKSPD: String = "⏩"
const STAT_HASTE: String = "⏳"
const STAT_CRIT_RATE: String = "🎯"
const STAT_CRIT_DMG: String = "💢"
const STAT_SPD: String = "🏃"

# --- ダンジョンのマス（DUNGEON_NODE_KIND_*） ---
const NODE_BATTLE: String = "🔥"
const NODE_RELIC: String = "🔮"
const NODE_REST: String = "⛺"
const NODE_CHEST: String = "🎁"
const NODE_BOSS: String = "🏰"
## ⚠ たいまつが届いていないマス。⚠ シナリオ側の「？」と同じ役目。
const NODE_HIDDEN: String = "❓"

# --- 通路の効果（段階19-c-2・DUNGEON_EDGE_EFFECT_*） ---
#
# ⚠ 効果が無い通路には何も出さない（⚠ 定数を作らない。⚠ "" を返す）。
# ⚠ 見えていない通路は EDGE_HIDDEN。⚠ マスの「❓」と別の字にしてある
#   （⚠ 同じだと「マスが見えないのか通路が見えないのか」が読めない）。
const EDGE_TRAP_HP: String = "💥"
const EDGE_TRAP_CURRENCY: String = "💸"
const EDGE_TRAP_BAG: String = "💨"
const EDGE_CHEST: String = "🎁"
const EDGE_RESOURCE: String = "💰"
const EDGE_HIDDEN: String = "❔"


# キャラの絵文字。⚠ 表に無いIDは CHAR_FALLBACK。
#
# ⚠ 呼ぶ側で分岐を書かないこと。⚠ ここが唯一の対応表。
static func for_character(character_id: String) -> String:
	match character_id:
		"char_swordsman":
			return CHAR_SWORDSMAN
		"char_archer":
			return CHAR_ARCHER
		"char_priest":
			return CHAR_PRIEST
	return CHAR_FALLBACK


# 敵の絵文字。⚠ 表に無いIDは ENEMY_FALLBACK。
static func for_enemy(enemy_type_id: String) -> String:
	match enemy_type_id:
		"enemy_slime":
			return ENEMY_SLIME
		"enemy_wolf":
			return ENEMY_WOLF
		"boss_slime_king":
			return ENEMY_BOSS_SLIME_KING
	return ENEMY_FALLBACK


# 戦闘に出ている1体の絵文字。
#
# ⚠ 味方か敵かは呼ぶ側が知っている（BattleUnit.team）。⚠ ここで team を見ない。
# ⚠ master_id は BattleUnit.master_id（味方＝character_id ／ 敵＝enemy_type_id ／
#   召喚＝summon_unit_id）。⚠ unit_id（"party_0" 等）ではない。
static func for_unit(master_id: String, is_party: bool, is_summon: bool) -> String:
	if is_summon:
		return SUMMON
	if is_party:
		return for_character(master_id)
	return for_enemy(master_id)


# アイテムの絵文字。⚠ 種類ごと（item_id ごとの表を作らない）。
#
# ⚠ 種類は items.json から引く。⚠ ID の綴りで見分けないこと
#   （ITEM_MASTER_PART_KIND のコメントと同じ理由）。
static func for_item(item_id: String) -> String:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		# ⚠⚠ レリックは items.json ではなく relics.json（表が別）。
		#   ⚠ ここで拾わないと ITEM_FALLBACK（📦）になり、⚠ 12件が全部同じ見た目になる
		#     （⚠ 2026-09-07 に人間が実機で見つけた。⚠ RELIC は定義済みなのに使われていなかった）。
		#   ⚠ ItemDetail._show_relic() が同じ順（items → relics）で引いている。
		if not MasterDataLoader.get_relic(item_id).is_empty():
			return RELIC
		return ITEM_FALLBACK
	var item_type: String = str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, ""))
	match item_type:
		GameStateKeys.ITEM_TYPE_EQUIPMENT:
			return _for_equip_slot(str(definition.get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")))
		GameStateKeys.ITEM_TYPE_PART:
			return _for_part_kind(str(definition.get(GameManager.ITEM_MASTER_PART_KIND, "")))
		GameStateKeys.ITEM_TYPE_MATERIAL:
			return ITEM_MATERIAL
		GameStateKeys.ITEM_TYPE_CONSUMABLE:
			return ITEM_CONSUMABLE
		GameStateKeys.ITEM_TYPE_DUNGEON:
			# ⚠ 効果は GameManager に聞く（⚠ 判定を2箇所に書かない）。
			if GameManager.get_dungeon_item_effect(item_id) == GameManager.DUNGEON_EFFECT_REVIVE:
				return ITEM_POTION_REVIVE
			return ITEM_POTION_HEAL
	return ITEM_FALLBACK


static func _for_equip_slot(equip_slot: String) -> String:
	match equip_slot:
		GameStateKeys.EQUIP_WEAPON:
			return ITEM_WEAPON
		GameStateKeys.EQUIP_HEAD:
			return ITEM_HEAD
		GameStateKeys.EQUIP_ARMOR:
			return ITEM_ARMOR
		GameStateKeys.EQUIP_LEGS:
			return ITEM_LEGS
		GameStateKeys.EQUIP_ACCESSORY:
			return ITEM_ACCESSORY
	return ITEM_FALLBACK


# 装飾の枠の絵文字（2026-09-08・段階②）。
#
# ⚠ 刺さる種類が1つならその種類の絵文字。
# ⚠ 複数（＝ワイルド枠）なら "" ＝何も出さない。⚠ 「何でも刺さる」を1つの絵文字で
#   言い表せないので、⚠ 嘘の種類を出すより空のほうがよい（⚠ 名前はツールチップが出す）。
# ⚠ 刺さっているものの絵文字は for_item() のほう（⚠ 枠が受ける種類とは別物）。
# ⚠⚠ 未開放の枠は **そもそも出さない**（⚠ 2026-09-08・人間の指示）ので、
#   ⚠ 鍵の絵文字は持たない。⚠ 出すかどうかを決めるのは `PartSlotRow`。
static func for_part_slot(kinds: Variant) -> String:
	if not (kinds is Array) or (kinds as Array).size() != 1:
		return ""
	return _for_part_kind(str((kinds as Array)[0]))


static func _for_part_kind(part_kind: String) -> String:
	match part_kind:
		GameManager.PART_KIND_GEM:
			return ITEM_GEM
		GameManager.PART_KIND_CHARM:
			return ITEM_CHARM
		GameManager.PART_KIND_EMBLEM:
			return ITEM_EMBLEM
		GameManager.PART_KIND_RUNE:
			return ITEM_RUNE
	return ITEM_FALLBACK


# ステータスの軸の絵文字（2026-09-08）。⚠ 表に無い軸は ""（⚠ 何も出さない）。
#
# ⚠ 軸のIDは `GameManager.get_stat_keys()` が返すもの。⚠ ここに綴りを増やさない。
# ⚠ 呼ぶ側で分岐を書かないこと。⚠ ここが唯一の対応表。
static func for_stat(stat_key: String) -> String:
	match stat_key:
		GameStateKeys.STAT_HP:
			return STAT_HP
		GameStateKeys.STAT_ATK:
			return STAT_ATK
		GameStateKeys.STAT_MAG:
			return STAT_MAG
		GameStateKeys.STAT_DEF:
			return STAT_DEF
		GameStateKeys.STAT_MDEF:
			return STAT_MDEF
		GameStateKeys.STAT_ATKSPD:
			return STAT_ATKSPD
		GameStateKeys.STAT_HASTE:
			return STAT_HASTE
		GameStateKeys.STAT_CRIT_RATE:
			return STAT_CRIT_RATE
		GameStateKeys.STAT_CRIT_DMG:
			return STAT_CRIT_DMG
		GameStateKeys.STAT_SPD:
			return STAT_SPD
	return ""


# ダンジョンのマスの絵文字。⚠ 見えていないマスは NODE_HIDDEN。
#
# ⚠ 「見えているか」の判定はここでしない（GameManager.is_dungeon_node_revealed()）。
static func for_dungeon_node(kind: String) -> String:
	match kind:
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
			return NODE_BATTLE
		GameStateKeys.DUNGEON_NODE_KIND_RELIC:
			return NODE_RELIC
		GameStateKeys.DUNGEON_NODE_KIND_REST:
			return NODE_REST
		GameStateKeys.DUNGEON_NODE_KIND_CHEST:
			return NODE_CHEST
		GameStateKeys.DUNGEON_NODE_KIND_BOSS:
			return NODE_BOSS
	return NODE_HIDDEN


# 通路の効果の絵文字（段階19-c-2）。⚠ 効果が無ければ ""（⚠ 何も出さない）。
#
# ⚠ 「見えているか」の判定はここでしない（GameManager.is_dungeon_edge_revealed()）。
static func for_dungeon_edge(effect: String) -> String:
	match effect:
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP:
			return EDGE_TRAP_HP
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY:
			return EDGE_TRAP_CURRENCY
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG:
			return EDGE_TRAP_BAG
		GameStateKeys.DUNGEON_EDGE_EFFECT_CHEST:
			return EDGE_CHEST
		GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE:
			return EDGE_RESOURCE
	return ""


# scenario=glyphs が見る一覧。⚠ 定数を足したらここにも足すこと。
#
# ⚠ 「足し忘れると検証されない」形は避けたいが、⚠ GDScript に定数を列挙する口が
#   無い（ClassDB は class_name のスクリプト定数を返さない）。⚠ 代わりに
#   scenario=glyphs 側で「表の件数」も出して、⚠ 増えたのに件数が変わらなければ気づける。
static func all_for_check() -> Dictionary:
	return {
		"CHAR_SWORDSMAN": CHAR_SWORDSMAN,
		"CHAR_ARCHER": CHAR_ARCHER,
		"CHAR_PRIEST": CHAR_PRIEST,
		"CHAR_FALLBACK": CHAR_FALLBACK,
		"ENEMY_SLIME": ENEMY_SLIME,
		"ENEMY_WOLF": ENEMY_WOLF,
		"ENEMY_BOSS_SLIME_KING": ENEMY_BOSS_SLIME_KING,
		"ENEMY_FALLBACK": ENEMY_FALLBACK,
		"SUMMON": SUMMON,
		"ITEM_WEAPON": ITEM_WEAPON,
		"ITEM_HEAD": ITEM_HEAD,
		"ITEM_ARMOR": ITEM_ARMOR,
		"ITEM_LEGS": ITEM_LEGS,
		"ITEM_ACCESSORY": ITEM_ACCESSORY,
		"ITEM_GEM": ITEM_GEM,
		"ITEM_CHARM": ITEM_CHARM,
		"ITEM_EMBLEM": ITEM_EMBLEM,
		"ITEM_RUNE": ITEM_RUNE,
		"ITEM_MATERIAL": ITEM_MATERIAL,
		"ITEM_CONSUMABLE": ITEM_CONSUMABLE,
		"ITEM_POTION_HEAL": ITEM_POTION_HEAL,
		"ITEM_POTION_REVIVE": ITEM_POTION_REVIVE,
		"ITEM_FALLBACK": ITEM_FALLBACK,
		"RELIC": RELIC,
		"STAT_HP": STAT_HP,
		"STAT_ATK": STAT_ATK,
		"STAT_MAG": STAT_MAG,
		"STAT_DEF": STAT_DEF,
		"STAT_MDEF": STAT_MDEF,
		"STAT_ATKSPD": STAT_ATKSPD,
		"STAT_HASTE": STAT_HASTE,
		"STAT_CRIT_RATE": STAT_CRIT_RATE,
		"STAT_CRIT_DMG": STAT_CRIT_DMG,
		"STAT_SPD": STAT_SPD,
		"NODE_BATTLE": NODE_BATTLE,
		"NODE_RELIC": NODE_RELIC,
		"NODE_REST": NODE_REST,
		"NODE_CHEST": NODE_CHEST,
		"NODE_BOSS": NODE_BOSS,
		"NODE_HIDDEN": NODE_HIDDEN,
		"EDGE_TRAP_HP": EDGE_TRAP_HP,
		"EDGE_TRAP_CURRENCY": EDGE_TRAP_CURRENCY,
		"EDGE_TRAP_BAG": EDGE_TRAP_BAG,
		"EDGE_CHEST": EDGE_CHEST,
		"EDGE_RESOURCE": EDGE_RESOURCE,
		"EDGE_HIDDEN": EDGE_HIDDEN,
	}
