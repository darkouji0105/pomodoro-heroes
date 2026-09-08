class_name IconTextures
extends RefCounted

# 線画アイコン（SVG）の対応表（2026-09-08・人間の指示「⚠ 差し替えて アイコン」）。
#
# ⚠⚠ `Glyphs`（絵文字）と同じ形。⚠ 引く口はここ1本。⚠ 呼ぶ側に分岐を書かせない。
#   ⚠ 違いは戻り値が `Texture2D` であることと、⚠ **無ければ `null` を返す**こと。
#   ⚠ null のときは呼ぶ側が `Glyphs` に落ちる＝⚠ 1枚ずつ差し替えられる。
#
# ⚠ SVG は Godot がインポート時にラスタライズする（⚠ `svg/scale` は既定の 1.0）。
#   ⚠ だから **48 x 48 の viewBox で描いてある**。⚠ 20〜24px で出すと縮小になり、
#   ⚠ 拡大でぼけることがない。⚠ 大きく出したくなったら SVG 側の viewBox を上げる。
# ⚠ 線は白（`#ffffff`）の1色。⚠ 色は使う側が `modulate` で着せる
#   （⚠ カラー絵文字ではできなかったこと。⚠ 等級の色・枠の種類の色をそのまま乗せられる）。
#
# ⚠ 読み込みは1回だけ（⚠ 下の `_cache`）。⚠ マスが100個並ぶ画面があるため。

const ICON_DIR: String = "res://assets/images/"
const ICON_PREFIX: String = "icon_"
const ICON_SUFFIX: String = ".svg"

# アイテムの種類 -> ファイル名の後半。⚠ `Glyphs.for_item()` と同じ分け方にすること。
const NAME_ITEM_WEAPON: String = "item_weapon"
const NAME_ITEM_HEAD: String = "item_head"
const NAME_ITEM_ARMOR: String = "item_armor"
const NAME_ITEM_LEGS: String = "item_legs"
const NAME_ITEM_ACCESSORY: String = "item_accessory"
const NAME_ITEM_GEM: String = "item_gem"
const NAME_ITEM_CHARM: String = "item_charm"
const NAME_ITEM_EMBLEM: String = "item_emblem"
const NAME_ITEM_RUNE: String = "item_rune"
const NAME_ITEM_MATERIAL: String = "item_material"
const NAME_ITEM_CONSUMABLE: String = "item_consumable"
const NAME_ITEM_RELIC: String = "item_relic"
const NAME_ITEM_CHEST: String = "item_chest"

# 素材は系統ごとに絵を分ける（2026-09-08・人間の指示
#   「⚠ 素材を分ける ジャンルごとに 建築シリーズが素材の名前っぽく
#     ⚠ 装飾系は宝石っぽく 修練は食べ物っぽく」）。
#
# ⚠⚠ 系統は `items.json` に欄が無い。⚠ 定義はIDの接頭辞だけ
#   （⚠ `GameStateKeys.ITEM_*_MATERIAL_PREFIX`。⚠ そこに理由も書いてある）。
#   ⚠ ここで綴りを書き起こさない。⚠ 定数で引く。
const MATERIAL_SERIES: Dictionary = {
	GameStateKeys.ITEM_CONSTRUCTION_MATERIAL_PREFIX: "material_construction",
	GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX: "material_training",
	GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX: "material_forging",
	GameStateKeys.ITEM_DECOR_MATERIAL_PREFIX: "material_decor",
}

# ルーンの種類 -> ファイル名の後半（2026-09-08・人間の指示「⚠ ルーンを中の模様を変えて」）。
#
# ⚠ 種類の判定は `MasterDataLoader.get_rune_kind()` の1本（⚠ 効果の形から決まる）。
#   ⚠ ここに "type" や "team" の綴りを持ち込まない。
const RUNE_INNER_NAMES: Dictionary = {
	MasterDataLoader.RUNE_KIND_MOVE: "rune_move",
	MasterDataLoader.RUNE_KIND_HEAL: "rune_heal",
	MasterDataLoader.RUNE_KIND_SHIELD: "rune_shield",
	MasterDataLoader.RUNE_KIND_DEBUFF: "rune_debuff",
	MasterDataLoader.RUNE_KIND_BUFF: "rune_buff",
}

# ステータスの軸 -> ファイル名の後半。⚠ 軸のIDは `GameStateKeys.STAT_*`。
const STAT_NAMES: Dictionary = {
	GameStateKeys.STAT_HP: "stat_hp",
	GameStateKeys.STAT_ATK: "stat_atk",
	GameStateKeys.STAT_MAG: "stat_mag",
	GameStateKeys.STAT_DEF: "stat_def",
	GameStateKeys.STAT_MDEF: "stat_mdef",
	GameStateKeys.STAT_ATKSPD: "stat_atkspd",
	GameStateKeys.STAT_HASTE: "stat_haste",
	GameStateKeys.STAT_CRIT_RATE: "stat_crit_rate",
	GameStateKeys.STAT_CRIT_DMG: "stat_crit_dmg",
	GameStateKeys.STAT_SPD: "stat_spd",
}

# ⚠ 読んだものを覚えておく（⚠ 同じ絵を100回読み直さない）。
static var _cache: Dictionary = {}


# アイテムの絵。⚠ 種類ごと（⚠ item_id ごとの表を作らない＝`Glyphs` と同じ）。
#
# ⚠ 種類の見分け方を写さない。⚠ `Glyphs.for_item()` が返した絵文字から引き直す
#   （⚠ 2つの表が別々に育つと、⚠ 絵文字と線画で違う種類が出る）。
static func for_item(item_id: String) -> Texture2D:
	# ⚠ 素材だけは系統ごとに分ける（⚠ `Glyphs` は11種の型でしか分けていない）。
	var series: String = _material_series_name(item_id)
	if series != "":
		return _load(series)
	return _load(_name_of_glyph(Glyphs.for_item(item_id)))


# 装飾の「中身」（2026-09-08・人間の指示「⚠ 枠で大まかな分類をして、中身を変える」）。
#
# ⚠⚠ 宝石・護符・紋章は **枠の形が種類**、⚠ **中の絵がステータス**。
#   ⚠ 前は種類ごとに1つの絵しか無く、⚠ 「HPの護符」と「魔防の護符」が同じ見た目だった
#   （⚠ 左上の漢字だけが違った）。
# ⚠ どのステータスかは `GameManager.get_part_definition()` に聞く（⚠ IDの綴りから切らない）。
# ⚠ ステータスを持たないもの（⚠ ルーン・素材・装備）は null＝中身なし。
static func inner_for_item(item_id: String) -> Texture2D:
	# ⚠ ルーンはステータスを持たない（⚠ 効果を撃つもの）。⚠ 中身は「何をするか」。
	var rune_kind: String = MasterDataLoader.get_rune_kind(item_id)
	if rune_kind != "":
		return _load(str(RUNE_INNER_NAMES.get(rune_kind, "")))
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	if definition.is_empty():
		return null
	return for_stat(str(definition.get(GameManager.ITEM_MASTER_PART_STAT, "")))


# 素材の系統のファイル名。⚠ 素材でなければ ""。
static func _material_series_name(item_id: String) -> String:
	if GameManager.get_material_tier(item_id) <= 0:
		return ""
	for prefix: String in MATERIAL_SERIES:
		if item_id.begins_with(prefix):
			return str(MATERIAL_SERIES[prefix])
	# ⚠ 系統が増えたのに表に足し忘れたとき。⚠ 前の1枚に落ちる（⚠ 黙って消えない）。
	return NAME_ITEM_MATERIAL


# ステータスの軸の絵。⚠ 表に無い軸は null。
static func for_stat(stat_key: String) -> Texture2D:
	return _load(str(STAT_NAMES.get(stat_key, "")))


# 装飾の枠の絵。⚠ 刺さる種類が1つのときだけ。⚠ ワイルド枠は null（⚠ 絵で言えない）。
static func for_part_slot(kinds: Variant) -> Texture2D:
	return _load(_name_of_glyph(Glyphs.for_part_slot(kinds)))


# 宝箱の絵。
static func for_chest() -> Texture2D:
	return _load(NAME_ITEM_CHEST)


# ⚠⚠ 絵文字 -> ファイル名。⚠ ここが `Glyphs` と線画をつなぐ唯一の場所。
#   ⚠ こうすると「どの品がどの種類か」の判定が `Glyphs` の1本のままになる。
static func _name_of_glyph(glyph: String) -> String:
	match glyph:
		Glyphs.ITEM_WEAPON:
			return NAME_ITEM_WEAPON
		Glyphs.ITEM_HEAD:
			return NAME_ITEM_HEAD
		Glyphs.ITEM_ARMOR:
			return NAME_ITEM_ARMOR
		Glyphs.ITEM_LEGS:
			return NAME_ITEM_LEGS
		Glyphs.ITEM_ACCESSORY:
			return NAME_ITEM_ACCESSORY
		Glyphs.ITEM_GEM:
			return NAME_ITEM_GEM
		Glyphs.ITEM_CHARM:
			return NAME_ITEM_CHARM
		Glyphs.ITEM_EMBLEM:
			return NAME_ITEM_EMBLEM
		Glyphs.ITEM_RUNE:
			return NAME_ITEM_RUNE
		Glyphs.ITEM_MATERIAL:
			return NAME_ITEM_MATERIAL
		Glyphs.ITEM_CONSUMABLE:
			return NAME_ITEM_CONSUMABLE
		Glyphs.RELIC:
			return NAME_ITEM_RELIC
	# ⚠ ポーション類（🍷 ❤）とフォールバック（📦）は線画を持たせていない。
	#   ⚠ null が返り、⚠ 呼ぶ側が絵文字に落ちる。
	return ""


static func _load(name: String) -> Texture2D:
	if name == "":
		return null
	if _cache.has(name):
		return _cache[name]
	var path: String = ICON_DIR + ICON_PREFIX + name + ICON_SUFFIX
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			texture = loaded as Texture2D
	# ⚠ 無かったことも覚える（⚠ 毎回 exists() を叩かない）。
	_cache[name] = texture
	return texture


# 検証用（⚠ 設計役は絵を見られない）。⚠ 「在るか」と「大きさ」だけ返す。
#   ⚠ ゲームのロジックから呼ばないこと。
static func all_for_check() -> Dictionary:
	var result: Dictionary = {}
	for name: String in [
		NAME_ITEM_WEAPON, NAME_ITEM_HEAD, NAME_ITEM_ARMOR, NAME_ITEM_LEGS,
		NAME_ITEM_ACCESSORY, NAME_ITEM_GEM, NAME_ITEM_CHARM, NAME_ITEM_EMBLEM,
		NAME_ITEM_RUNE, NAME_ITEM_MATERIAL, NAME_ITEM_CONSUMABLE,
		NAME_ITEM_RELIC, NAME_ITEM_CHEST,
	]:
		result[name] = _load(name)
	for prefix: String in MATERIAL_SERIES:
		result[str(MATERIAL_SERIES[prefix])] = _load(str(MATERIAL_SERIES[prefix]))
	for kind: String in RUNE_INNER_NAMES:
		result[str(RUNE_INNER_NAMES[kind])] = _load(str(RUNE_INNER_NAMES[kind]))
	for stat_key: String in STAT_NAMES:
		result[str(STAT_NAMES[stat_key])] = _load(stat_key_texture_name(stat_key))
	return result


static func stat_key_texture_name(stat_key: String) -> String:
	return str(STAT_NAMES.get(stat_key, ""))
