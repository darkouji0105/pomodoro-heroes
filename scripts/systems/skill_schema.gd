class_name SkillSchema
extends RefCounted

# スキルの器の「語彙」と「1件ぶんの構造検証」だけを持つ静的クラス。
# 決定台帳は docs/01_plan/PLAN_SKILL_TEMPLATE.md、指示書は
# docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE1.md。
#
# 【役割は2つだけ】
#   1. 器の語彙（値の一覧）を1箇所に持つ。値を1個足すときはここと
#      SkillResolver の分岐を1本ずつ触れば済む形に保つ
#   2. スキル1件ぶんの構造を検証する。全件回すのは MasterDataLoader 側
#
# ⚠ このファイルは MasterDataLoader を参照しない。参照すると
#   MasterDataLoader → SkillSchema → MasterDataLoader の循環になる。
#   characters.json と突き合わせる検証（射程）だけは MasterDataLoader 側に置く。
#
# ⚠ ここで push_error / push_warning を呼ばない。呼ぶのは MasterDataLoader 側。
#   件数を数えたいのと、呼ぶ場所を1箇所にするため。

# --- 検証結果の重さ ---
const LEVEL_ERROR: String = "error"
const LEVEL_WARNING: String = "warning"

# --- activation（発動の型） ---
const ACTIVATION_INSTANT: String = "instant"
const ACTIVATION_CHARGE: String = "charge"
# recast は段階5で動く。⚠ toggle は回CH-9（2026-10-10）で動くようになった（⚠ 下の FIELD_TOGGLE）。
const ACTIVATION_RECAST: String = "recast"
const ACTIVATION_TOGGLE: String = "toggle"
# パッシブ（PLAN 7-2・19章）。⚠ 「発動の型」であって効果の trigger ではない。
#   trigger は効果1件ごとの「いつ発火するか」なので、そちらに置くと1つのスキルの
#   中に「cast の効果」と「パッシブの効果」が混在でき、撃てるものなのか決まらない。
# ⚠ 発動の経路はスキルとまったく同じ（_fire_skill → cast → SkillResolver）。
#   違うのは引き金を引くのが誰かだけ。味方＝ボタン／敵＝攻撃拍／
#   パッシブ＝battle_controller._step_passives()。
# ⚠ 枠が別（BattleUnit.passive_ids）なので、ボタンにも敵AIにも混ざらない。
#   混ぜて後段で弾く形にしないこと（EXEC_SKILL_PASSIVE_VARS.md §0-1-1）。
const ACTIVATION_PASSIVE: String = "passive"
const ACTIVATIONS_KNOWN: Array = [
	ACTIVATION_INSTANT, ACTIVATION_CHARGE, ACTIVATION_RECAST, ACTIVATION_TOGGLE,
	ACTIVATION_PASSIVE
]

# --- target.team（誰を狙うか。相対で解く） ---
const TEAM_ENEMY: String = "enemy"
const TEAM_ALLY: String = "ally"
const TEAM_SELF: String = "self"
# source は「この効果を起こした相手」。段階3。
const TEAM_SOURCE: String = "source"
const TEAMS_KNOWN: Array = [TEAM_ENEMY, TEAM_ALLY, TEAM_SELF, TEAM_SOURCE]

# --- target.mode（母集団の絞り方） ---
const MODE_SELECT: String = "select"
const MODE_AREA: String = "area"   # 段階4で実装
const MODES_KNOWN: Array = [MODE_SELECT, MODE_AREA]

# --- target.origin（mode: area の円の中心・段階4） ---
#
# ⚠ mode: area のときだけ読む。mode: select に書いたら赤（E80）。
# ⚠ 省略できない（E77）。既定値を作らないこと。既定を user にすると「敵の団を
#   狙ったつもりが自分の足元で爆発」、target にすると逆が、どちらも書き忘れた
#   だけで黙って起きる（stack の既定値を作らなかったのと同じ理由）。
#
# ⚠ radius は「中心からの距離」。range（使用者からの距離）と混ぜないこと。
#   range は起点を1体選ぶときの絞りにしか効かず、radius は range を越えて
#   巻き込む（人間の決定・EXEC_SKILL_AREA.md §0）。
const ORIGIN_USER: String = "user"       # 使用者の位置が中心。sort / range は書けない（E78）
const ORIGIN_TARGET: String = "target"   # sort で選んだ1体の位置が中心
const ORIGIN_AIM: String = "aim"         # 溜めで動かした狙いの位置が中心（回GM-1）。sort / range は書けない
const ORIGINS_KNOWN: Array = [ORIGIN_USER, ORIGIN_TARGET, ORIGIN_AIM]

# --- target.sort（並べ替え） ---
const SORT_NEAREST: String = "nearest"
const SORT_FARTHEST: String = "farthest"
const SORT_LOWEST_HP: String = "lowest_hp"
const SORT_HIGHEST_HP: String = "highest_hp"
const SORT_ALL: String = "all"
const SORTS_KNOWN: Array = [
	SORT_NEAREST, SORT_FARTHEST, SORT_LOWEST_HP, SORT_HIGHEST_HP, SORT_ALL
]

# --- effects[].type ---
const EFFECT_DAMAGE: String = "damage"
const EFFECT_HEAL: String = "heal"
const EFFECT_BUFF: String = "buff"   # 段階3で実装
const EFFECT_DOT: String = "dot"     # 段階3で実装
const EFFECT_REACT: String = "react" # 段階3の後半①で実装（購読）
const EFFECT_SUMMON: String = "summon" # 段階6で実装（召喚・分裂）
# キャラ固有の資源を足す・決める（2026-10-10・回CH-1・EXEC_CHAR_RESOURCE.md §3）。
# ⚠ 宛先は撃った本人だけ（⚠ 資源は持ち主のもの）。⚠ target は読まない。
const EFFECT_RESOURCE: String = "resource"
# 押し出す（回CH-5）。{"type": "knockback", "distance": 80}。⚠ 撃った人から遠ざける向き。
# ⚠ 座標を動かすのは戦闘の画面（BattleController）だけ＝⚠ ここは結果に載せるだけ（召喚と同じ）。
const EFFECT_KNOCKBACK: String = "knockback"
# 自分が動く（回CH-6・EXEC_CHAR_RESOURCE.md §13）。⚠ 一瞬で移る（人間「⚠ １あ」）・動いたあと少し止まる（「⚠ ２あ」）。
#   {"type": "dash", "to": "target", "offset": 40} … 狙った相手（何体かなら真ん中）まで。offset だけ手前で止まる（突進・飛び込み）
#   {"type": "dash", "to": "back", "distance": 120} … 後ろへ下がる（ステップ）
# ⚠ 座標を動かすのは戦闘の画面（⚠ 結果に載せるだけ＝ノックバックと同じ）。⚠ スネア中は動かない（⚠ 設計役の仮）。
const EFFECT_DASH: String = "dash"
# クールダウンを縮める・消す（回CH-7・EXEC_CHAR_RESOURCE.md §14）。⚠ 宛先はスキルの target（自分・味方）。
#   {"type": "cooldown", "sec": 3, "skills": "all"}      … 3秒縮める
#   {"type": "cooldown", "pct": 30, "skills": "others"}  … 残りの 30% 縮める（⚠ 残りに対して）
#   {"type": "cooldown", "all": true, "skills": ["skill_x"]} … 全部消す
# ⚠ 量は sec ／ pct ／ all のどれか1つ（人間「⚠ １う」）。
# ⚠ skills＝"all"（全部）／ "others"（撃ったスキル以外）／ ID の配列。⚠ "others" の除外は SkillRuntime が撃つ瞬間に書く（`_except`）。
const EFFECT_COOLDOWN: String = "cooldown"
const COOLDOWN_SKILLS_ALL: String = "all"
const COOLDOWN_SKILLS_OTHERS: String = "others"
const COOLDOWN_FIELD_EXCEPT: String = "_except"
# 解除（回CH-7）。{"type": "dispel", "what": "debuff"}。⚠ 当てはまるものを全部消す（人間「⚠ ２あ」）。
# ⚠ デバフ＝状態のマスが赤いもの（人間「⚠ ３い」＝`StatusRegistry.is_debuff_entry()`）・バフ＝それ以外。
# ⚠ パッシブの状態は消しても次のフレームで付け直る（`_restore_passives()`）＝実質消えない。
const EFFECT_DISPEL: String = "dispel"
# 自分の召喚を使う（回NC-1・ネクロの「爆破」「古い順に3体で上級」）。⚠ 古い順に count 体（"all" なら全部）を消す。
#   {"type": "summon_consume", "unit_ids": ["summon_nc_zombie"], "count": 3}
#   {"type": "summon_consume", "unit_ids": [...], "count": "all", "blast_radius": 100, "multiplier": 1.0, "attack_type": "magic", "scale_from": "mag"}
# ⚠ blast_radius を書くと、消える1体ごとに「その位置から半径の中の敵」へダメージ（⚠ 威力は撃った本人の能力値）。
# ⚠ 消すのは戦闘の画面（⚠ 結果に載せるだけ＝召喚と同じ）。⚠ 消え方は死亡ではない（⚠ 「敵が倒された」は出ない）。
const EFFECT_SUMMON_CONSUME: String = "summon_consume"
const CONSUME_COUNT_ALL: String = "all"
const CONSUME_FIELD_UNIT_IDS: String = "unit_ids"
const CONSUME_FIELD_BLAST_RADIUS: String = "blast_radius"
# 状態の残り時間を最初に戻す（回GM-1・神の使いの通常攻撃「聖なる炎の効果時間を更新する」）。
#   {"type": "refresh_status", "status_id": "st_zl_holy_foe"} … 対象に付いているその状態（⚠ 誰が付けたものでも）の時計を 0 に戻す
# ⚠ 付いていなければ何もしない（⚠ 新しく付けない）。
const EFFECT_REFRESH_STATUS: String = "refresh_status"
# ダメージの印（回GM-1・「聖なる炎のダメージとして扱われる」）。⚠ damage と dot に書く。⚠ 吸収（intervene の drain_tag）が読む。
const FIELD_TAG: String = "tag"
# この攻撃で倒したら（回GM-1・処刑の一撃「聖なる炎を持つ敵を殺した場合、自身のHPを回復する」）。⚠ damage に書く。
#   "on_kill": {"when_status": "st_zl_holy_foe", "effects": [{"type": "heal", "target": {"team": "self"}, ...}]}
# ⚠ when_status は省ける（⚠ 書けば「倒した相手にその状態が付いていたら」）。⚠ effects は撃った本人が撃つ。
const FIELD_ON_KILL: String = "on_kill"
# 2つの状態がそろったら（回GM-1・聖水と聖なる炎の爆発＝人間「⚠ １あ」どちらが先でも・そろったら両方消える）。⚠ 状態（buff / dot・host: unit）に書く。
#   "on_meet": {"status_id": "st_zl_holy_foe", "effects": [{"type": "damage", ...}]}
# ⚠ effects は宿主に当たる・撃つのはこの状態を付けた人。⚠ 撃ったあと、宿主から両方の状態を消す。
const FIELD_ON_MEET: String = "on_meet"
# 狙いが動く溜め（回GM-1・人間「⚠ ２あ」＝溜めている間に狙いの円が右へ動き、離した場所に撃つ）。⚠ スキルの直下・activation: charge だけ。
#   "aim": {"from": 80, "speed": 300, "to": 700} … 自分の前 from から、毎秒 speed ずつ、to まで
# ⚠ 範囲の中心は target の origin: "aim"（⚠ 狙いが無いとき＝自動戦闘や敵は、射程の中の一番近い相手の位置）。
const FIELD_AIM: String = "aim"
# 次の攻撃を避けて反撃（回MC-1・傭兵のフェイント＝人間「⚠ １あ」）。⚠ buff（host: unit）に書く。
#   "evade": {"effects": [...]} … 相手からのダメージ1回を 0 にし、⚠ この状態を消して、⚠ 攻撃してきた相手へ effects を撃つ
# ⚠ 毒の周期では避けない（⚠ 攻撃ではない）。⚠ effects の target は書かない（⚠ 攻撃してきた相手に当たる）。
const FIELD_EVADE: String = "evade"
# 購読の「近くで」（回MC-1・人間「⚠ ２あ」）。⚠ react{} の中に書く・foe_died だけ。
#   "react": {"event": "foe_died", "within": 150, "effects": [...]} … 宿主の周り within の中で倒れたときだけ
const REACT_FIELD_WITHIN: String = "within"
# 威力の式の定数（回MC-1・傭兵「10＋失った体力の10%」）。⚠ {"source": "flat", "weight": 10} ＝ 10。
const SCALE_FLAT: String = "flat"
const AIM_FIELDS_REQUIRED: Array = ["from", "speed", "to"]
# 対象を取らない効果（回NC-1）。⚠ 購読の中でも target が要らない（E54 の例外）・実行時も対象を選ばない。
const TARGETLESS_EFFECT_TYPES: Array = [EFFECT_SUMMON, EFFECT_SUMMON_CONSUME]
# 召喚の上限（回NC-1・人間「⚠ あ６」＝⚠ 段階6の決定5「上限なし」を召喚ごとに上書きできるようにした）。
# ⚠ 召喚した人1人ぶんの召喚の数（⚠ 種類を問わない）。⚠ 超えたら古いほうから消える。⚠ 書かなければ上限なし（⚠ いままでどおり）。
const SUMMON_FIELD_MAX_PER_OWNER: String = "max_per_owner"
# 自分の召喚が足りないと撃てない（回NC-1）。⚠ スキルの直下に書く（⚠ cost と同じ場所・同じ暗転）。
#   "need_summons": {"unit_ids": ["summon_nc_zombie"], "count": 3}
const FIELD_NEED_SUMMONS: String = "need_summons"
# 相手の状態で効果が変わる（回CH-8・EXEC_CHAR_RESOURCE.md §15）。⚠ どの効果にも書ける。
#   "when_target": {"source": "status_has", "status_id": "bleed"}            … 相手がその状態か
#   "when_target": {"source": "debuff_count", "op": "gte", "value": 2}       … 相手の赤いマスの数
#   "when_target": {"source": "hp_ratio", "op": "lte", "value": 0.5}         … 相手の HP の割合（0〜1）
# ⚠ when_mult（倍率）／ when_crit: true（会心確定）を一緒に書くと（⚠ どちらも damage だけ）「満たしたら強くなる」（人間「⚠ １う」の あ・「⚠ ３あ」）。
# ⚠ どちらも書かなければ「満たした相手にだけ当たる」（「⚠ １う」の い）。
const FIELD_WHEN_TARGET: String = "when_target"
const FIELD_WHEN_MULT: String = "when_mult"
const FIELD_WHEN_CRIT: String = "when_crit"
const WHEN_STATUS_HAS: String = "status_has"
const WHEN_DEBUFF_COUNT: String = "debuff_count"
const WHEN_HP_RATIO: String = "hp_ratio"
const WHENS_KNOWN: Array = [WHEN_STATUS_HAS, WHEN_DEBUFF_COUNT, WHEN_HP_RATIO]
# 処刑（回CH-8）。⚠ damage に書く。⚠ 当たったあとの HP が割合以下なら倒す（人間「⚠ ２あ」）。
# ⚠ ボスは倒さない。⚠ 代わりに execute_boss_mult をダメージに掛ける（⚠ 書かなければ 1.0）。
const FIELD_EXECUTE_BELOW: String = "execute_below"
# 自分についての条件（回PQ-1・王女の「はなれなさい！」＝人間「⚠ ２あ」近くに敵がいなければ）。⚠ どの効果にも書ける。
#   "when_user": {"source": "enemies_within", "radius": 80, "op": "eq", "value": 0}
# ⚠ 満たさないと、その効果は当たらない（⚠ 絞り込みではなく、効果ごと飛ばす）。
const FIELD_WHEN_USER: String = "when_user"
# 貫通する飛び道具（回PQ-2・人間「⚠ 貫通する飛び道具にして」）。⚠ 効果に書く。
#   {"type": "damage", "delivery": "projectile", "trigger": "event:hit", "pierce_length": 400, ...}
# ⚠ 撃った瞬間に「自分から前へ pierce_length の中の敵」を近い順に拾う（⚠ スキルの target は撃てるかの判定だけに使う）。
# ⚠ 矢は1本・前へまっすぐ飛び、⚠ 通り過ぎた敵ごとに**その瞬間**に当たる（⚠ 着弾待ちを敵ごとに分ける）。
# ⚠ 前＝相手の陣の向き（味方は右・敵は左）。⚠ 戦場は横の1次元＝「線」はこれ。
const FIELD_PIERCE_LENGTH: String = "pierce_length"
# ⚠ 敵ごとの着弾の合図の頭（"hit:<unit_id>"）。⚠ SkillRuntime と BattleController だけが使う。
const EVENT_PIERCE_HIT_PREFIX: String = "hit:"
# ⚠ damage の矢に乗せられる効果（回NC-1・ネクロのビーム＝当たった相手の回復量を下げ、1体ごとに魂）。
const PIERCE_RIDER_TYPES: Array = [EFFECT_BUFF, EFFECT_RESOURCE]
const WHEN_ENEMIES_WITHIN: String = "enemies_within"
# 自分の後ろ radius の中にいる敵の数（回MC-1・傭兵「前後に敵がいる場合」）。⚠ 後ろ＝自分の陣の向き。
const WHEN_ENEMIES_BEHIND: String = "enemies_behind"
const WHEN_USER_SOURCES: Array = [WHEN_ENEMIES_WITHIN, WHEN_ENEMIES_BEHIND]
# 能力値を割合で上げ下げする（回DB-1・人間「⚠ ４あ」）。⚠ buff と dot に書ける。⚠ −20 なら −20%。
# ⚠ 計算は（素の値 ＋ value）×（1 ＋ 割合の合計/100）。⚠ atkspd だけは攻撃間隔に掛ける（⚠ −10 なら間隔が伸びる）。
const FIELD_STAT_PCT: String = "stat_pct"
# 目くらまし（回DB-1・人間「⚠ ５あ」）。⚠ buff に書く。⚠ 通常攻撃がこの % で外れる（⚠ 合計は 100 で頭打ち）。
const FIELD_MISS_PCT: String = "miss_pct"
# 共通の状態を名前で付ける（回DB-1・人間「⚠ １あ」）。{"type": "status", "status": "poison"}。
# ⚠ 中身は statuses.json の1か所。⚠ 読み込むときに MasterDataLoader が中身へ展開する（⚠ 実行時にこの型は来ない）。
const EFFECT_STATUS_REF: String = "status"
const FIELD_STATUS_REF: String = "status"
const FIELD_EXECUTE_BOSS_MULT: String = "execute_boss_mult"
const DISPEL_DEBUFF: String = "debuff"
const DISPEL_BUFF: String = "buff"
const DASH_TO_TARGET: String = "target"
const DASH_TO_BACK: String = "back"
const DASH_TOS_KNOWN: Array = [DASH_TO_TARGET, DASH_TO_BACK]
const EFFECT_TYPES_KNOWN: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT, EFFECT_SUMMON,
	EFFECT_RESOURCE, EFFECT_KNOCKBACK, EFFECT_DASH, EFFECT_COOLDOWN, EFFECT_DISPEL,
	EFFECT_SUMMON_CONSUME, EFFECT_REFRESH_STATUS,
	"cancel", "transform", "move"
]
# 実際に当たるもの。他は「書けるが飛ばす」（黄）。
const EFFECT_TYPES_IMPLEMENTED: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT, EFFECT_SUMMON,
	EFFECT_RESOURCE, EFFECT_KNOCKBACK, EFFECT_DASH, EFFECT_COOLDOWN, EFFECT_DISPEL,
	EFFECT_SUMMON_CONSUME, EFFECT_REFRESH_STATUS,
]
# resource の欄。⚠ amount（足す・負なら減らす）と set_to（その値にする）はどちらか1つ。
# ⚠ 持ち主にその資源があるか・種類と欄が合うかは MasterDataLoader が見る（⚠ ここは characters.json を知らない）。
const RESOURCE_FIELD_ID: String = "resource_id"
const RESOURCE_FIELD_AMOUNT: String = "amount"
const RESOURCE_FIELD_SET_TO: String = "set_to"
# ⚠ 相手の状態の数を掛ける（回SC-1・学者「⚠ ゲージの獲得量は敵の感電ストックの影響を受ける」）。
#   {"type": "resource", "resource_id": "charge", "amount": 3, "per_target_stack": "shock", "target": {"team": "source"}}
# ⚠ amount × 相手（target）に積まれている数。⚠ 資源が入るのは撃った本人。⚠ target は source（購読のきっかけ）だけ。
const RESOURCE_FIELD_PER_STACK: String = "per_target_stack"
const RESOURCE_ONLY_FIELDS: Array = [RESOURCE_FIELD_ID, RESOURCE_FIELD_AMOUNT, RESOURCE_FIELD_SET_TO, RESOURCE_FIELD_PER_STACK]
# ⚠ 威力の式を持たない。書けると「書いたのに効かない」が無音になる。
# ⚠ target は {"team": "self"} だけ書ける（回CH-3）：⚠ 購読の中の効果は target が必須（E は「購読の効果は各自に要る」）なので。
const RESOURCE_FIELDS_FORBIDDEN: Array = ["scale_from", "multiplier", "attack_type", "delivery"]

# 召喚（type: "summon"・段階6・PLAN 14-2）の欄。
#
# ⚠ 既定値を作らない（origin / stack / scale_from と同じ方針）。書き忘れが
#   どちらに倒れても無音で挙動が変わる：count を省略して1体にすると
#   「取り巻き3体のつもりが1体」、offset_x を省略して0にすると召喚者と
#   完全に重なって数字が読めない（宿題28）。
# ⚠ offset_x の符号は「敵に向かう向きが正」（前衛が正・後衛が負）。
#   ワールド座標に直接足さないこと。味方は +1、敵は -1 を掛けてから足す。
const SUMMON_FIELDS_REQUIRED: Array = ["unit_id", "count", "duration_sec", "offset_x"]
# ⚠ 召喚は対象を取らず、威力の式も持たない。書けると「書いたのに効かない」が無音になる。
const SUMMON_FIELDS_FORBIDDEN: Array = ["target", "scale_from", "multiplier", "attack_type"]
# ⚠ summon 以外の効果に書いてあったら赤（E99）。unit_id は「召喚するID」の意味で、
#   damage の results が持つ unit_id（＝殴られた側）と紛らわしい。
const SUMMON_ONLY_FIELDS: Array = ["unit_id", "offset_x", "count"]
# 状態として残る効果。host / status_id / stack / 寿命の欄を読む（PLAN 13章）。
const EFFECT_TYPES_STATUS: Array = [EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT]

# 介入点の欄（PLAN 11-1・段階3の後半③）。⚠ buff にしか書けない。
#
# ダメージの介入点だけは受け口が段階1からあり（SkillResolver._step_crit_override /
# _step_reduction）、こちらは残る3つ（回復・状態の付与・死亡）。
#
# ⚠ 効果の種類は増えていない。EFFECT_TYPES_* に何も足さないこと。
# ⚠ stat / value と同時に持ってよい（「攻撃力＋10かつ毒に免疫」）。
#   3つを同時に持ってもよい。排他にしない。
# ⚠ 4つ目が来たので intervene{} の入れ子に畳んだ（EXEC_SKILL_MITIGATION.md・人間の決定2）。
#   欄の名前と意味は1つも変えていない。場所だけ buff の直下から intervene{} の中へ移した。
# ⚠ 平置きで書いたら赤（E102）。移し忘れが無音で消えるのを防ぐ（宿題11）。
const BUFF_ON_DEATH: String = "on_death"              # { revive_hp_ratio: float }
const BUFF_BLOCK_STATUS: String = "block_status"      # Array[String]（status_id）
const BUFF_HEAL_TAKEN_PCT: String = "heal_taken_pct"  # int（負なら低下）
# ⚠ 平置きを見つけるための一覧。⚠ E102 だけが使う。中身の検証には使わない。
const BUFF_INTERVENE_FIELDS: Array = [
	BUFF_ON_DEATH, BUFF_BLOCK_STATUS, BUFF_HEAL_TAKEN_PCT
]

# ダメージの介入点の欄（EXEC_SKILL_MITIGATION.md）。⚠ intervene{} の中にだけ書ける。
#
# ⚠ 誰の状態を読むかが欄ごとに違う。読み違えると「効いているのに効いていない」になる。
#   殴られた側 … shield_hp / reduction_pct / reflect_pct / reflect_flat
#   殴った側   … pierce_pct / crit_always
const BUFF_INTERVENE: String = "intervene"
const INTERVENE_SHIELD_HP: String = "shield_hp"
const INTERVENE_REDUCTION_PCT: String = "reduction_pct"
const INTERVENE_PIERCE_PCT: String = "pierce_pct"
const INTERVENE_CRIT_ALWAYS: String = "crit_always"
const INTERVENE_REFLECT_PCT: String = "reflect_pct"
const INTERVENE_REFLECT_FLAT: String = "reflect_flat"
# 吸収（回GM-1・殴った側）。⚠ 印（tag）の付いたダメージを与えたら、その pct % 回復する。⚠ 2つそろえて書く。
const INTERVENE_DRAIN_TAG: String = "drain_tag"
const INTERVENE_DRAIN_PCT: String = "drain_pct"
# ⚠ 知らない欄を赤にする（E107）ための唯一の正。⚠ 欄を足したらここにも足すこと。
const INTERVENE_FIELDS_KNOWN: Array = [
	INTERVENE_SHIELD_HP, INTERVENE_REDUCTION_PCT, INTERVENE_PIERCE_PCT,
	INTERVENE_CRIT_ALWAYS, INTERVENE_REFLECT_PCT, INTERVENE_REFLECT_FLAT,
	INTERVENE_DRAIN_TAG, INTERVENE_DRAIN_PCT,
	BUFF_ON_DEATH, BUFF_BLOCK_STATUS, BUFF_HEAL_TAKEN_PCT,
]
# ⚠ 軽減の上限。100 にすると amount が必ず 0 になり、誰も死なずに決着しない
#   （GIVE_UP_SEC の赤で初めて気づく形になる）。⚠ データ側から触れないようにコードで持つ。
const REDUCTION_PCT_MAX: int = 95
const PIERCE_PCT_MAX: int = 100

# 範囲（オーラ・毒沼・設置地帯）の欄（EXEC_SKILL_AURA.md）。⚠ host: point 専用。
#
# ⚠ target.radius（mode: area）と混ぜないこと。あちらは「撃つ瞬間に誰を巻き込むか」、
#   こちらは「毎フレーム誰が中に居るか」。同じ名前を平置きで並べると必ず取り違える。
# ⚠ 3つとも必須。既定値を作らない（origin / stack / scale_from / 召喚の4欄と同じ方針）。
#   follow の既定を作ると「動くはずのオーラが動かない」が無音になる。
const FIELD_ZONE: String = "zone"
const ZONE_RADIUS: String = "radius"
const ZONE_TEAM: String = "team"
const ZONE_FOLLOW: String = "follow"
const ZONE_FIELDS_REQUIRED: Array = [ZONE_RADIUS, ZONE_TEAM, ZONE_FOLLOW]
# ⚠ 付与者から見た向き。target.team と同じ語彙にする（ここだけ「味方＝プレイヤー側」に
#   すると、敵が置いた毒沼が敵を焼く）。
const ZONE_TEAM_ALLY: String = "ally"
const ZONE_TEAM_ENEMY: String = "enemy"
const ZONE_TEAM_ALL: String = "all"
# ⚠ 置いた本人だけ（回SC-1・学者の感電スモーク「⚠ ４い」＝煙の中で再生するのは学者だけ）。
const ZONE_TEAM_SELF: String = "self"
const ZONE_TEAMS_KNOWN: Array = [ZONE_TEAM_ALLY, ZONE_TEAM_ENEMY, ZONE_TEAM_ALL, ZONE_TEAM_SELF]

# 周期の効果を回復にする（EXEC_SKILL_AURA.md）。⚠ dot にしか書けない。
#
# ⚠ multiplier の符号で分けないこと。skill_resolver.gd が「符号を跨ぐと緑の数字で
#   HPが減る」と名指しで警告している。欄で分ければ表示の色も介入点も既存のまま分かれる。
const FIELD_HEALS: String = "heals"

# 攻撃力の倍率（EXEC_SILENT_HOLES.md）。⚠ buff にしか書けない。
#
# ⚠ 綴りを "multiplier" にしないこと。buff は multiplier を書けない（別の意味で
#   既に埋まっている）。同じ綴りに2つの意味を持たせない。
# ⚠ % の整数。積み上げは和（1.0 + 合計/100）。掛け合わせない
#   （heal_taken_pct / reduction_pct / stat_mod と同じ）。
# ⚠ 下限は 0.0。マイナスで符号を跨がせると「殴ると回復する」になる。
const BUFF_ATK_MULT_PCT: String = "atk_mult_pct"

# 通常攻撃を置き換える（回CH-4・EXEC_CHAR_RESOURCE.md §11）。⚠ buff にしか書けない。
#   "basic_attack": { "effects": [...] }  … 次の通常攻撃をこの一撃にする（⚠ 形は characters.json の basic_attack と同じ）
#   "uses": 1                             … あと何回か（⚠ 書かなければ duration_sec のあいだずっと＝人間「⚠ ２ひとによる」）
# ⚠ 置き換え＝人間「⚠ １あ」。⚠ 置き換えた一撃も「◯回ごと」の1回に数える（人間「⚠ ３あ」）。
# ⚠ 「◯回ごと」と同じ回に重なったら、強化が勝つ（⚠ 設計役の仮）。
const BUFF_BASIC_ATTACK: String = "basic_attack"
const BUFF_USES: String = "uses"

# 行動を止める・守る（回CH-5・EXEC_CHAR_RESOURCE.md §12）。⚠ buff の `control` に1つ書く。
#   stun         … 移動・通常攻撃・スキルを全部止める（人間「⚠ １あ」）
#   snare        … 移動だけ止める（人間「⚠ スネアも追加」）
#   invulnerable … ダメージも、相手から付けられる状態も受けない（人間「⚠ ３あ」）
#   unstoppable  … スタン・スネア・ノックバックを受けない
# ⚠ ボスには弱く効く（人間「⚠ ２う」＝`Balance.adventure.boss_control_ratio` を秒数・距離に掛ける）。
const BUFF_CONTROL: String = "control"
const CONTROL_STUN: String = "stun"
const CONTROL_SNARE: String = "snare"
const CONTROL_INVULNERABLE: String = "invulnerable"
const CONTROL_UNSTOPPABLE: String = "unstoppable"
const CONTROLS_KNOWN: Array = [CONTROL_STUN, CONTROL_SNARE, CONTROL_INVULNERABLE, CONTROL_UNSTOPPABLE]
# ⚠ 止められない（unstoppable）が防ぐもの。
const CONTROLS_STOPPABLE: Array = [CONTROL_STUN, CONTROL_SNARE]

# 効果の直下に書ける欄の全部（EXEC_SILENT_HOLES.md・W16）。
#
# 【なぜ要るか】typo（"stt" / "mutliplier"）が無音で無視される。書いたのに何も
# 起きない状態は、画面を見てもログを見ても分からない（宿題11）。
# ⚠ 一覧はここ1本。2本目を作ると、欄を足したときに片方だけ直す。
# ⚠ 実データの全キー（24種）＋ コードが読む chance / charge_scales を
#   grep で列挙して作った。⚠ 憶測で書かないこと。正しい欄が黄で出る。
# ⚠ 欄を足したらここにも足すこと。
const EFFECT_FIELDS_KNOWN: Array = [
	# ⚠ max_stack はリテラル。FIELD_MAX_STACK の宣言がこの下にあり、
	#   const は前方参照できない（並べ替えると他の参照が壊れるのでこちらを直した）。
	"type", "host", "status_id", "stack", "max_stack",
	"duration_sec", "until", "interval_sec",
	"multiplier", "attack_type", "scale_from", "delivery",
	"stat", "value", "target", "trigger", "chance", "charge_scales",
	"react", "condition",
	BUFF_INTERVENE, FIELD_ZONE, FIELD_HEALS, BUFF_ATK_MULT_PCT,
	BUFF_BASIC_ATTACK, BUFF_USES, BUFF_CONTROL, "distance", "to", "offset",
	"sec", "pct", "all", "skills", "what",
	FIELD_WHEN_TARGET, FIELD_WHEN_MULT, FIELD_WHEN_CRIT, FIELD_EXECUTE_BELOW, FIELD_EXECUTE_BOSS_MULT,
	FIELD_STAT_PCT, FIELD_MISS_PCT, FIELD_WHEN_USER, FIELD_PIERCE_LENGTH,
	"unit_id", "count", "offset_x",
	"resource_id", "amount", "set_to", "per_target_stack",
	CONSUME_FIELD_UNIT_IDS, CONSUME_FIELD_BLAST_RADIUS, SUMMON_FIELD_MAX_PER_OWNER,
	FIELD_TAG, FIELD_ON_KILL, FIELD_ON_MEET, FIELD_EVADE,
]

# --- attack_type（どの防御で受けるか。攻撃側の参照元は scale_from） ---
# ⚠ physical / magic は BattleUnit の定数を唯一の正とする。
#    ここに書き直さないこと（2本目の一覧を作ると片方だけ直して事故る）。
const ATTACK_TYPE_TRUE: String = "true"   # 確定ダメージ（防御を0として扱う）

# --- effects[].host（効果の寿命の持ち主） ---
const HOST_NONE: String = "none"
const HOST_UNIT: String = "unit"
const HOST_POINT: String = "point"
const HOST_BATTLE: String = "battle"
const HOST_SPAWN: String = "spawn"
const HOSTS_KNOWN: Array = [HOST_NONE, HOST_UNIT, HOST_POINT, HOST_BATTLE, HOST_SPAWN]

# --- effects[].trigger（いつ発火するか） ---
# 解釈するのは SkillRuntime。⚠ SkillResolver は trigger を読まない（2箇所で解釈すると必ずズレる）。
const TRIGGER_CAST: String = "cast"
const TRIGGER_CHARGE_START: String = "charge_start"   # 段階2で実装
const TRIGGER_PREFIX_EVENT: String = "event:"

# 唯一「合図を出す側が居る」イベント名。ProjectileView が着弾で返す（PLAN 6-7）。
# ⚠ 語彙はここに置く。SkillSchema を参照する側（SkillRuntime）で定義すると、
#   検証がイベント名を知るために相互参照になる。
const EVENT_HIT: String = "hit"
const TRIGGER_PREFIX_DELAY: String = "delay:"         # 段階2で実装

# --- react.event（外の出来事＝購読・PLAN 10章） ---
#
# ⚠ EVENT_HIT（trigger の合図）と別の一覧にすること。演出シーンの合図と
#   外の出来事は別物で、混ぜると trigger: "event:took_damage" が書けてしまう。
#
# ⚠ attacked と dealt_damage を1つにしないこと。空振り（対象0体）と、
#   当たったが0ダメージは別の出来事。
const EVENT_ATTACKED: String = "attacked"            # damage の効果が発火した（空振りでも出る）
const EVENT_DEALT_DAMAGE: String = "dealt_damage"    # ダメージが1件確定した（攻撃者に配る）
const EVENT_TOOK_DAMAGE: String = "took_damage"      # ダメージが1件確定した（被害者に配る）
# 回CH-3（2026-10-10・EXEC_CHAR_RESOURCE.md §10）。
# ⚠ 「敵が倒された」は相手側の生きている全員に配る（人間「⚠ １い　敵が倒されたことをトリガーにする」）。
#   ⚠ きっかけ（source）＝とどめを刺した人。⚠ 召喚が倒したら召喚した人（人間「⚠ ２あ」）。⚠ 復活したら出ない。
const EVENT_FOE_DIED: String = "foe_died"
# ⚠ 通常攻撃のダメージが1件確定した（殴った本人に配る・source＝当たった相手）。
const EVENT_BASIC_HIT: String = "basic_hit"
# ⚠ スキルを撃った（本人だけに配る＝人間「⚠ ３あ」）。⚠ 通常攻撃・ルーン・購読の発火は数えない。
const EVENT_SKILL_USED: String = "skill_used"
# ⚠ 強化した一撃を撃った（回PQ-1・王女「⚠ 自身が強化攻撃を行うたびに」＝人間「⚠ ３あ」）。⚠ 本人だけ。
# ⚠ 「◯回ごと」の一撃か、置き換え（basic_attack のバフ）の一撃を撃ったとき。⚠ 当たったかは見ない（撃った瞬間）。
const EVENT_EMPOWERED_BASIC: String = "empowered_basic"
const EVENTS_KNOWN: Array = [
	EVENT_ATTACKED, EVENT_DEALT_DAMAGE, EVENT_TOOK_DAMAGE,
	EVENT_FOE_DIED, EVENT_BASIC_HIT, EVENT_SKILL_USED, EVENT_EMPOWERED_BASIC,
]
# 通常攻撃を撃つときのスキルID（⚠ BattleController と SkillRuntime の両方が読む＝語彙はここ）。
const BASIC_ATTACK_SKILL_ID: String = "basic_attack"

# --- effects[].delivery（どう届くか。待ち行列の種別タグ・PLAN 6-8） ---
#
# ⚠ attack_type（どの防御で受けるか）とは別物。混ぜないこと。
#   attack_type は 5-2-1 で「防御の参照先だけ」に純化した欄で、送り方の意味は持たない。
#   段階3の効果 cancel（飛び道具の無効化）と詠唱中断が、このタグで待ち行列を絞る。
#
# 省略時は melee。回復と自傷にも melee が入るが、投射する回復を作るまで実害は無い。
const DELIVERY_MELEE: String = "melee"
const DELIVERY_PROJECTILE: String = "projectile"
const DELIVERY_MAGIC: String = "magic"
const DELIVERIES_KNOWN: Array = [DELIVERY_MELEE, DELIVERY_PROJECTILE, DELIVERY_MAGIC]

# --- effects[].stack（重ねがけ規則・PLAN 13-2） ---
#
# ⚠ 省略時の既定値を作らない（scale_from と同じ方針）。書き忘れがどちらに
#   倒れても無音で挙動が変わるため。
#   既定を independent にすると、上書きのつもりで書き忘れたときスタックが
#   無限に積み上がる。既定を refresh にすると、独立のつもりで書き忘れたとき
#   DoT が重ならずダメージが黙って半分になる。どちらもエラーが出ない。
const STACK_INDEPENDENT: String = "independent"   # かけるたびに別の状態が増える
const STACK_REFRESH: String = "refresh"           # 同じ状態を寿命ごと置き直す
const STACKS_KNOWN: Array = [STACK_INDEPENDENT, STACK_REFRESH]

# --- effects[].until（秒数以外の寿命・PLAN 13-3） ---
#
# ⚠ duration_sec と排他。両方書いたら赤。
const UNTIL_CHARGE_END: String = "charge_end"
# ⚠ skill_end は語彙だけ。剥がすには「その cast_id の待ち行列が空か」を
#   SkillRuntime に聞く配線が要る。段階3の後半でまとめる（書くと黄で飛ばされる）。
const UNTIL_SKILL_END: String = "skill_end"
const UNTILS_KNOWN: Array = [UNTIL_CHARGE_END, UNTIL_SKILL_END]

# --- effects[].condition（毎フレーム評価する発火源・PLAN 10章） ---
#
# ⚠ of は scale_from の of（user / target / source）と別の一覧にすること。
#   状態には user も target も居ない（宿主と付与者しかいない）。同じ語を
#   使い回すと「target って誰？」が無音でズレる。
const COND_OF_HOST: String = "host"       # 宿主（付けられた側）
const COND_OF_SOURCE: String = "source"   # 付与者（付けた側）
const COND_OF_KNOWN: Array = [COND_OF_HOST, COND_OF_SOURCE]

const COND_OP_LT: String = "lt"
const COND_OP_LTE: String = "lte"
const COND_OP_GT: String = "gt"
const COND_OP_GTE: String = "gte"
const COND_OP_EQ: String = "eq"
const COND_OPS_KNOWN: Array = [COND_OP_LT, COND_OP_LTE, COND_OP_GT, COND_OP_GTE, COND_OP_EQ]

# その状態が付いているか。⚠ 0 か 1 しか返さない。
#   件数を返す status_count を作らないこと。作るとスタック閾値（Nスタックで別の
#   効果）がここから書けてしまうが、stack の上限も消え方も未実装（宿題5）なので、
#   independent が無限に積む状態に閾値が乗り、一度真になったら二度と偽に戻らない。
#   「デバフの数だけ強く」は変数表の担当（段階3の後半④）。条件は bool だけを返す。
const COND_SOURCE_STATUS_HAS: String = "status_has"

# --- scale_from の "of"（誰の値を見るか） ---
const SCALE_OF_USER: String = "user"
const SCALE_OF_TARGET: String = "target"
const SCALE_OF_SOURCE: String = "source"   # 段階3
const SCALE_OF_KNOWN: Array = [SCALE_OF_USER, SCALE_OF_TARGET, SCALE_OF_SOURCE]

# --- scale_from の source のうち、10軸ではないもの ---
const SCALE_HP_CURRENT: String = "hp_current"
const SCALE_HP_LOST: String = "hp_lost"
const SCALE_HP_RATIO: String = "hp_ratio"
const SCALE_HP_LOST_RATIO: String = "hp_lost_ratio"
const SCALE_DISTANCE: String = "distance"

# --- scale_from の source のうち、戦闘全体の値（PLAN 5-5-2「戦闘」の群） ---
# ⚠ wave_index は 1 始まり（BattleSession.current_wave をそのまま返す）。
#   名前が _index なので 0 始まりに読めるが、"wave_index >= 2" で「2波目以降」。
const SCALE_ELAPSED_SEC: String = "elapsed_sec"
const SCALE_ALIVE_ALLY: String = "alive_count_ally"
const SCALE_ALIVE_ENEMY: String = "alive_count_enemy"
const SCALE_WAVE_INDEX: String = "wave_index"

# --- scale_from の source のうち、状態の群（PLAN 5-5-2） ---
# ⚠ 入れ子で書く。{ "source": "stack", "status_id": "..." }（人間の決定）。
#   前方一致（"stack:xxx"）にしない。scale_sources() の「列挙できる形」が崩れ、
#   利用者すべて（condition_sources / E群 / 評価器2本）に前置き分岐が要る
#   （PLAN 5-5-4「自由文字列にしない」）。
# ⚠ condition の source: "status_has" + 兄弟の status_id 欄と同じ型。
const SCALE_STACK: String = "stack"

# of を読まない source。⚠ 例外の一覧はここ1本。分岐を各所に散らさないこと。
#   distance … 2者の間の値 ／ elapsed_sec・wave_index … 戦闘全体の値
const SCALE_SOURCES_NO_OF: Array = [SCALE_DISTANCE, SCALE_ELAPSED_SEC, SCALE_WAVE_INDEX]

# independent の上限（PLAN 13-1・宿題6）。
# ⚠ 上限に達したら「積まない」。古いものを捨てて積む形にしないこと
#   （寿命が延び続けて実質無限になる）。
# ⚠ これが無いと stack:<状態ID> の閾値が一度真になったら二度と偽に戻らない
#   （EXEC_SKILL_CONDITION.md §2-3 が status_count を作らなかった理由）。
const FIELD_MAX_STACK: String = "max_stack"

# ⚠ 画面が読む欄の名前（2026-09-11・スキル設定の「CD 6.0秒／チャージ 1.0秒」）。
#   ⚠ 綴りを画面に書き起こさせない。⚠ 欄の名前を変えるならここ1箇所。
const FIELD_COOLDOWN_SEC: String = "cooldown_sec"
const FIELD_ACTIVATION: String = "activation"
const FIELD_CHARGE: String = "charge"
const FIELD_JUST_SEC: String = "just_sec"
const FIELD_UNLOCK_LEVEL: String = "unlock_level"
# ⚠⚠ パッシブの解放条件（2026-09-14・人間の決定「⚠ そのレベルになったら自動開放する ポイントはそのままでいい」）。
#   ⚠ ステータスノードの**総ポイント（獲得した分）**がこの値以上で自動で開く。⚠ 振らなくてよい。
#   ⚠ パッシブだけの欄。⚠ スキルは unlock_level のまま。
const FIELD_UNLOCK_TOTAL_POINTS: String = "unlock_total_points"

# スキル直下に書いてよい欄。
# トグル型（回CH-9・EXEC_CHAR_RESOURCE.md §16）。⚠ activation: "toggle" には必須。
#   "toggle": {"interval_sec": 1.0, "repress": "off"}
# ⚠ 入れている間、interval_sec ごとに effects が出る（⚠ 入れた瞬間に1回目）。
# ⚠ cost を書けば**1回出るごとに払う**・払えなくなったら自動で切れる（人間「⚠ １あ」）。⚠ 書かなければ資源を使わない（生徒のレーザー）。
# ⚠ クールダウンは**切ったとき**に始まる（「⚠ ２あ」）。
# ⚠ もう一度押したとき＝repress：off（切れる）／ retarget（狙う相手を選び直す＝僧侶の祈り）（「⚠ ３スキルごとに違う」）。
# ⚠ スタン・戦闘不能・ウェーブ交代で切れる。
const FIELD_TOGGLE: String = "toggle"
const TOGGLE_INTERVAL: String = "interval_sec"
const TOGGLE_REPRESS: String = "repress"
const REPRESS_OFF: String = "off"
const REPRESS_RETARGET: String = "retarget"


# 資源を払って撃つ（2026-10-10・回CH-2・EXEC_CHAR_RESOURCE.md §9）。
#
#   "cost": {"resource_id": "charge", "amount": 40} … 40 払う（⚠ 足りなければ撃てない）
#   "cost": {"resource_id": "charge", "all": true}  … 全部払う（⚠ 1 以上ないと撃てない＝人間「⚠ ２あ」）
#
# ⚠ 払うのは1段目だけ（⚠ クールダウンと同じ）。⚠ 足りないとマスは暗く押せない（人間「⚠ １あ」）。
# ⚠ 持ち主にその資源があるか・ゲージかストックかは MasterDataLoader が見る（⚠ ここは characters.json を知らない）。
const FIELD_COST: String = "cost"
const COST_FIELD_RESOURCE_ID: String = "resource_id"
const COST_FIELD_AMOUNT: String = "amount"
const COST_FIELD_ALL: String = "all"
const COST_FIELDS_KNOWN: Array = [COST_FIELD_RESOURCE_ID, COST_FIELD_AMOUNT, COST_FIELD_ALL]

# 払った量で効果を変える（回CH-2・人間「⚠ ３あ」＝使った量に比例）。scale_from の項に書く：
#   {"source": "resource_spent", "weight": 1.0}
# ⚠ 値は撃つ瞬間に `SkillResolver.fold_resource_spent()` が項へ書き込む（⚠ 遅れて発火する効果にも同じ値が届く）。
# ⚠ `scale_sources()` には足さない（⚠ あちらは condition の語彙も兼ねる＝条件には書けない）。
# ⚠ `cost` を持つスキルにしか書けない ／ ⚠ 段（phases）のあるスキルには書けない（⚠ 払うのは1段目だけ）。
const SCALE_RESOURCE_SPENT: String = "resource_spent"
# いま持っている資源の量（回SC-1・学者のパッシブ「⚠ 充電の量に応じて回復量は変わる」）。
#   {"source": "resource", "resource_id": "charge", "weight": 0.2}
# ⚠ 撃った本人の資源（⚠ of は読まない）。⚠ 発火のたびに今の量を読む（⚠ 継続回復なら毎回）。
# ⚠ scale_sources() には足さない（⚠ 条件には書けない＝resource_spent と同じ）。
const SCALE_RESOURCE_NOW: String = "resource"
# ⚠ コードだけが書く欄（⚠ データに書いたら赤）。
const SCALE_FIELD_SPENT: String = "_spent"


# スキルの cost（⚠ 無ければ空）。
static func cost_of(skill_data: Dictionary) -> Dictionary:
	var raw: Variant = skill_data.get(FIELD_COST, null)
	return raw as Dictionary if raw is Dictionary else {}


# ⚠ typo を黙って既定値にしないための最後の砦（E26）。
const SKILL_FIELDS_KNOWN: Array = [
	"name_key", "user_character_id", "unlock_level", "unlock_total_points", "cooldown_sec",
	"activation", "charge", "recast", "target", "effects", "phases",
	# 資源を払う（2026-10-10・回CH-2）。
	FIELD_COST,
	# 自分の召喚が足りないと撃てない（回NC-1）。
	FIELD_NEED_SUMMONS,
	# 狙いが動く溜め（回GM-1）。
	FIELD_AIM,
	# トグル型（回CH-9）。
	FIELD_TOGGLE,
	# レリック（段階14-d）。⚠ relics.json は skills.json と同じ辞書へマージされるので、
	#   ここに並べないと E26「知らない欄がある」で全件が赤になる。
	FIELD_RELIC_SCOPE,
	# 装備の特殊効果（2026-10-02・回UI-仕組み⑦・`equip_effects.json`）。⚠ 画面の札が読む欄。
	FIELD_EQUIP_TRIGGER_KEY, FIELD_EQUIP_DESC_KEY,
	# 拠点の遺物の段ごとのパッシブ（2026-10-07・回HB-3・`MasterDataLoader._build_guild_relic_passives()`）。
	FIELD_GUILD_RELIC_ID,
]

# ⚠ 拠点の遺物（2026-10-07）。⚠ この欄を持つエントリは遺物が組み立てたパッシブ＝⚠ キャラに紐づかず解放も無い（⚠ レリックと同じ例外）。
const FIELD_GUILD_RELIC_ID: String = "guild_relic_id"

# 装備の特殊効果（2026-10-02）。⚠ `trigger_key` を持つエントリは装備の特殊効果＝⚠ キャラに紐づかず解放も無い（⚠ レリックと同じ例外）。
#   ⚠ 判定はこの1欄の有無だけ（⚠ IDの綴り `eqfx_` で見分けない）。
const FIELD_EQUIP_TRIGGER_KEY: String = "trigger_key"
const FIELD_EQUIP_DESC_KEY: String = "desc_key"

# レリックの適用範囲（段階14-d・PLAN_SCENARIO_MAP.md §5-2-5）。
#
# ⚠ この欄を持つエントリは「レリック」であり、キャラに紐づかない。
#   ⚠ user_character_id と unlock_level を要求しない（E3 / E4 の例外）。
#   ⚠ 例外はこの1欄の有無だけで判定する。IDの綴りで見分けないこと。
const FIELD_RELIC_SCOPE: String = "relic_scope"
const RELIC_SCOPE_PARTY: String = "party"
const RELIC_SCOPE_SINGLE: String = "single"
const RELIC_SCOPES_KNOWN: Array = [RELIC_SCOPE_PARTY, RELIC_SCOPE_SINGLE]

# charge{} の必須欄（数値）
const CHARGE_FIELDS_REQUIRED: Array = [
	"just_sec", "just_window_sec", "min_ratio", "just_bonus"
]

# --- phases[] / recast（段階5・PLAN 3-2 / 8章） ---

# 段の直下に書いてよい欄。⚠ typo を黙って既定値にしないための砦（E89）。
# ⚠ target は段ごとに必須。1段目から引き継がない。段は独立した発動であり
#   （cast_id も BattleLog の行も別）、引き継ぎを許すと2段目の対象が JSON から
#   読めなくなる。effects[].target の「上書き」とは意味が違う。
const PHASE_FIELDS_KNOWN: Array = ["target", "effects"]

# recast{} の必須欄（数値）
# ⚠ MasterDataLoader が返すのは float。is int で見ないこと（E69 の事故）。
const RECAST_FIELDS_REQUIRED: Array = ["window_sec"]

# 段の最小数。⚠ 1段の recast は window_sec が意味を持たず、「省略と同じ」の
#   つもりなのか「2段目を書き忘れた」のかが読めない（既定値を作らない方針）。
const PHASES_MIN: int = 2


# ============================================================
# 段（phases[]）の取り出し（段階5・PLAN 3-2）
# ============================================================

# 段の数。⚠ phases が無ければ 1（省略＝1段）。
static func phase_count(skill_data: Dictionary) -> int:
	var raw: Variant = skill_data.get("phases", null)
	if not (raw is Array):
		return 1
	return maxi((raw as Array).size(), 1)


# 段を1つ選び、その段の target / effects を直下に持つスキル定義を返す。
#
# ⚠ phases が無ければ引数をそのまま返す（複製もしない）。
#   「phases 省略の既存スキル全件が1ミリも変わらない」を、注意ではなく構造で守るため。
#   分岐を _fire_skill / blocked_reason / cast の3箇所に書くと、必ず1箇所だけ
#   直す事故になる（状態を消す経路を1本ずつ対応して踏んだのと同じ形）。
#
# ⚠ ここが段を知る唯一の場所。SkillRuntime も SkillResolver も段を知らないまま。
static func phase_of(skill_data: Dictionary, index: int) -> Dictionary:
	var raw: Variant = skill_data.get("phases", null)
	if not (raw is Array) or (raw as Array).is_empty():
		return skill_data

	var phases: Array = raw as Array
	# ⚠ 範囲外は 0 に丸める。撃てないより1段目が出るほうが、壊れ方が見える。
	var i: int = index
	if i < 0 or i >= phases.size():
		i = 0
	var raw_phase: Variant = phases[i]
	if not (raw_phase is Dictionary):
		# ロード時検証（E88）が守っているので通常は来ない。二重に守る。
		push_error("[SkillSchema] phases[%d] が Dictionary でない" % i)
		return skill_data

	var phase: Dictionary = raw_phase as Dictionary
	# ⚠ 浅い複製。中の target / effects は差し替えるので触らない。
	var out: Dictionary = skill_data.duplicate()
	out.erase("phases")
	out["target"] = phase.get("target", {})
	out["effects"] = phase.get("effects", [])
	return out


# attack_type に書ける値。BattleUnit の定数から組み立てる（2本目の一覧を作らない）。
static func attack_types_known() -> Array:
	return [BattleUnit.ATTACK_TYPE_PHYSICAL, BattleUnit.ATTACK_TYPE_MAGIC, ATTACK_TYPE_TRUE]


# scale_from の source に書ける名前（段階1ぶん）。
# 10軸は GameManager.get_stat_keys() が唯一の正。ここに軸名を並べた
# 2本目の配列を作らないこと。
static func scale_sources() -> Array:
	var sources: Array = []
	for stat_key in GameManager.get_stat_keys():
		sources.append(str(stat_key))
	sources.append(SCALE_HP_CURRENT)
	sources.append(SCALE_HP_LOST)
	sources.append(SCALE_HP_RATIO)
	sources.append(SCALE_HP_LOST_RATIO)
	sources.append(SCALE_DISTANCE)
	# 戦闘の群・状態の群（段階3の後半④）。
	# ⚠ ここに足したら、評価器2本（SkillResolver._scale_variable と
	#   StatusRegistry._condition_value）の両方に枝を足すこと。片方だけだと
	#   「damage では効くのに condition では0」という壊れ方をする。
	sources.append(SCALE_ELAPSED_SEC)
	sources.append(SCALE_ALIVE_ALLY)
	sources.append(SCALE_ALIVE_ENEMY)
	sources.append(SCALE_WAVE_INDEX)
	sources.append(SCALE_STACK)
	return sources


# condition の source に書ける名前。
#
# ⚠ scale_sources() を流用する（2本目の語彙を作らない）。
# ⚠ distance だけ除く。あちらは「使用者と対象の間」の値だが、状態には対象が居ない
#   ので、そのまま流用すると「宿主と付与者の距離」という別の意味になる。
#   座標の規則は point のオーラを入れる回で決める。
static func condition_sources() -> Array:
	var sources: Array = []
	for source_name: Variant in scale_sources():
		if str(source_name) != SCALE_DISTANCE:
			sources.append(str(source_name))
	sources.append(COND_SOURCE_STATUS_HAS)
	return sources


# スキル1件ぶんの構造を検証する。
# 戻り値は { "level": "error" or "warning", "message": String } の配列。空＝問題なし。
# message には必ず skill_id を含める（どのスキルが壊れているか分からないと直せない）。
# 通常攻撃（characters.json / enemies.json の "basic_attack"）を検証する。
# 戻り値の形は validate() と同じ。
#
# 【なぜ入口を分けるか】通常攻撃には target が無い。狙う相手は「歩いて近づいた
# 相手」（BattleUnit.target_unit_id）で決まっており、撃つ瞬間に選び直さない。
# ⚠ validate() に通すと target が必須になるが、通常攻撃は「書かなければ
#   歩いて近づいた相手を撃つ」が既定。必須にすると9件とも同じ target を
#   書き写すことになり、書いても効かない欄が増える。
#
# 【target を書いたとき】範囲攻撃になる（人間の決定・2026-08-16）。
# ⚠ 書いたユニットだけ「歩いて近づいた相手」以外にも当たる。射程の判定は
#   変わらない（近づいた相手が attack_range に入ったら発動する）。
#
# ⚠ 効果1件ぶんの検証は _validate_effect() を共用する。ここに2本目の判定を
#   書かないこと（scale_from や attack_type の規則が片方だけ古くなる）。
static func validate_basic_attack(owner_id: String, data: Dictionary) -> Array:
	var issues: Array = []

	if data == null or data.is_empty():
		_err(issues, owner_id, "basic_attack が無い、または空（通常攻撃が撃てない）")
		return issues

	# ⚠ スキルの欄を書いても効かない。黙って無視すると「書いたのに変わらない」になる。
	for field: Variant in ["activation", "charge", "cooldown_sec", "unlock_level", "phases"]:
		if data.has(field):
			_err(issues, owner_id, "basic_attack に %s は書けない（通常攻撃はスキルではない）" % str(field))

	# target は省略可。書いた場合だけ検証する（範囲攻撃）。
	# ⚠ range は書けない。通常攻撃の射程は characters.json の attack_range が持つ。
	#   2箇所に射程があると、どちらが効いているか実機でしか分からなくなる。
	if data.has("target"):
		var raw_target: Variant = data.get("target", null)
		if not (raw_target is Dictionary):
			_err(issues, owner_id, "basic_attack.target が Dictionary でない")
		else:
			_validate_target(issues, owner_id, raw_target as Dictionary, "basic_attack.target", false)

	var raw_effects: Variant = data.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, owner_id, "basic_attack.effects が無い、配列でない、または空")
		return issues

	var index: int = 0
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			_err(issues, owner_id, "basic_attack.effects[%d] が Dictionary でない" % index)
			index += 1
			continue
		var effect: Dictionary = raw_effect as Dictionary
		# ⚠ trigger は書ける（投射物の回に解禁した）。
		#   一度「通常攻撃は待ち行列に載せない」と禁止したが、それは誤りだった。
		#   要素は着弾で発火して消えるので伸び続けない。そして載せないと、
		#   飛び道具の無効化（cancel_by_delivery）が通常攻撃の矢にだけ効かなくなる。
		#
		# ⚠ 効果ごとの target 上書きは引き続き書けない。通常攻撃が狙うのは
		#   「歩いて近づいた相手」で、撃つ瞬間に選び直してはいけない。
		# ⚠ 例外（回MC-1・傭兵「前後に敵がいる場合は剣を振り回す」）：自分の周りの範囲（mode: area・origin: user）は書ける。
		#   ⚠ ただし通常攻撃の直下に target があるときだけ（⚠ 無いと近づいた相手が対象に固定され、効果ごとの target は読まれない）。
		var around_self: bool = effect.get("target", null) is Dictionary \
				and str((effect["target"] as Dictionary).get("mode", "")) == MODE_AREA \
				and str((effect["target"] as Dictionary).get("origin", "")) == ORIGIN_USER
		if effect.has("target") and not (around_self and data.has("target")):
			_err(issues, owner_id, "basic_attack.effects[%d] に target は書けない（⚠ 自分の周りの範囲だけは、直下に target があれば書ける）" % index)
		_validate_effect(issues, owner_id, effect, index, ACTIVATION_INSTANT)
		index += 1

	return issues


static func validate(skill_id: String, data: Dictionary) -> Array:
	var issues: Array = []

	# E1
	if data == null or data.is_empty():
		_err(issues, skill_id, "定義が空、または Dictionary ではない")
		return issues

	# E2 旧欄の残骸。「移行し忘れ」を確実に捕まえる。
	if data.has("type"):
		_err(issues, skill_id, "旧欄 'type' が残っている（activation / target / effects[] に割ること）")

	# レリックか（段階14-d）。⚠ relic_scope を持つエントリだけが該当する。
	#   ⚠ レリックはキャラに紐づかず、レベルでも解放されないので、
	#     user_character_id（E3）と unlock_level（E4）を要求しない。
	#   ⚠ 判定はこの1欄の有無だけ。IDの綴りで見分けないこと。
	var relic_scope: String = str(data.get(FIELD_RELIC_SCOPE, ""))
	# ⚠ 装備の特殊効果もキャラに紐づかない（⚠ 2026-10-02・下の E3 / E4 の例外に乗せる）。
	var is_relic: bool = relic_scope != "" or data.has(FIELD_EQUIP_TRIGGER_KEY) or data.has(FIELD_GUILD_RELIC_ID)
	# E130 … relic_scope の値が party / single のどちらでもない。
	#   ⚠ 2026-08-25：最初 E128 と書いたが、あれは research.json の検証が
	#     既に使っていた（master_data_loader.gd:344）。E129 も workshop が使用済み。
	#     ⚠ 番号の続きは NEXT_STEPS §2-7 を見てから採ること。
	#   ⚠ 綴りを間違えると「全員に効くつもりが1人にも効かない」が無音で起きる。
	if relic_scope != "" and not (relic_scope in RELIC_SCOPES_KNOWN):
		_err(issues, skill_id, "%s が不明: '%s'（%s のどちらか）" % [
			FIELD_RELIC_SCOPE, relic_scope, str(RELIC_SCOPES_KNOWN)
		])

	# E156〜E159 資源を払う（回CH-2）
	_validate_cost(issues, skill_id, data)
	_validate_need_summons(issues, skill_id, data)
	_validate_aim(issues, skill_id, data)

	# E3
	if str(data.get("name_key", "")) == "":
		_err(issues, skill_id, "name_key が無い")
	if not is_relic and str(data.get("user_character_id", "")) == "":
		_err(issues, skill_id, "user_character_id が無い")

	# E5 / W1
	var activation: String = str(data.get("activation", ""))
	if not (activation in ACTIVATIONS_KNOWN):
		_err(issues, skill_id, "activation が不明: '%s'" % activation)
	# E172 トグル型（回CH-9）
	if activation == ACTIVATION_TOGGLE:
		var raw_toggle: Variant = data.get(FIELD_TOGGLE, null)
		if not (raw_toggle is Dictionary):
			_err(issues, skill_id, "activation: 'toggle' なのに toggle{} が無い")
		else:
			var toggle: Dictionary = raw_toggle as Dictionary
			var interval: Variant = toggle.get(TOGGLE_INTERVAL, null)
			if not _is_num(interval) or float(interval) <= 0.0:
				_err(issues, skill_id, "toggle.interval_sec が正の数でない")
			if not (str(toggle.get(TOGGLE_REPRESS, "")) in [REPRESS_OFF, REPRESS_RETARGET]):
				_err(issues, skill_id, "toggle.repress が 'off' ／ 'retarget' でない（必須）")
			for key: Variant in toggle:
				if not (str(key) in [TOGGLE_INTERVAL, TOGGLE_REPRESS]):
					_err(issues, skill_id, "toggle{} に知らない欄がある: '%s'" % str(key))
			if data.has("phases"):
				_err(issues, skill_id, "activation: 'toggle' に phases は書けない")
	elif data.has(FIELD_TOGGLE):
		_err(issues, skill_id, "activation が toggle 以外なのに toggle{} がある")

	var is_passive: bool = (activation == ACTIVATION_PASSIVE)

	# E4
	# ⚠⚠ パッシブは unlock_level ではなく unlock_total_points（2026-09-14）。
	#   ⚠ 両方書けると「どちらが効いているか」が JSON から読めないので、⚠ パッシブに unlock_level は赤。
	# ⚠ cooldown_sec はパッシブには書けない（E73）。撃つものではないため。
	# ⚠ レリックはレベルで解放されないので unlock_level を要求しない（段階14-d）。
	# ⚠ レリックも activation: passive だが、解放という概念が無いので対象外（段階14-d）。
	if is_passive and not is_relic:
		if not _is_num(data.get(FIELD_UNLOCK_TOTAL_POINTS, null)):
			_err(issues, skill_id, "activation: 'passive' の unlock_total_points が数値でない")
		if data.has(FIELD_UNLOCK_LEVEL):
			_err(issues, skill_id, "activation: 'passive' に unlock_level は書けない（総ポイントで解放する）")
	elif not is_relic and not _is_num(data.get("unlock_level", null)):
		_err(issues, skill_id, "unlock_level が数値でない")
	if not is_passive and data.has(FIELD_UNLOCK_TOTAL_POINTS):
		_err(issues, skill_id, "unlock_total_points はパッシブにしか書けない")
	if not is_passive and not _is_num(data.get("cooldown_sec", null)):
		_err(issues, skill_id, "cooldown_sec が数値でない")

	# E73 パッシブに撃つための欄は書けない。
	# ⚠ cooldown_sec を書いても BattleUnit.start_cooldown() は passive_ids を
	#   見ないので何も起きない。無音で無視される欄を書かせない。
	if is_passive:
		# E92 recast も同じ（パッシブは撃つものではないので構えようがない）。
		for field: String in ["cooldown_sec", "charge", "recast", "phases"]:
			if data.has(field):
				_err(issues, skill_id, "activation: 'passive' に %s は書けない（撃つものではない）" % field)

	# E6 / E7
	var raw_charge: Variant = data.get("charge", null)
	if activation == ACTIVATION_CHARGE:
		if not (raw_charge is Dictionary):
			_err(issues, skill_id, "activation: charge なのに charge{} が無い")
		else:
			for field: Variant in CHARGE_FIELDS_REQUIRED:
				if not _is_num((raw_charge as Dictionary).get(field, null)):
					_err(issues, skill_id, "charge.%s が数値でない" % str(field))
	elif data.has("charge"):
		_err(issues, skill_id, "activation が charge 以外なのに charge{} がある")

	# E81 / E82 / E83 recast{}
	# ⚠ charge と同じ形（軸が値を取ったときだけ読む欄）。E6 / E7 と対称に保つこと。
	var raw_recast: Variant = data.get("recast", null)
	if activation == ACTIVATION_RECAST:
		if not (raw_recast is Dictionary):
			_err(issues, skill_id, "activation: recast なのに recast{} が無い")
		else:
			for field: Variant in RECAST_FIELDS_REQUIRED:
				# ⚠ MasterDataLoader が返すのは float。is int で見ないこと（E69）。
				if not _is_num((raw_recast as Dictionary).get(field, null)):
					_err(issues, skill_id, "recast.%s が数値でない" % str(field))
				elif float((raw_recast as Dictionary).get(field, 0.0)) <= 0.0:
					_err(issues, skill_id, "recast.%s は 0 より大きいこと（構える時間が無いと再発動できない）" % str(field))
	elif data.has("recast"):
		_err(issues, skill_id, "activation が recast 以外なのに recast{} がある")

	# E84〜E91 phases[]
	# ⚠ phases があるときは target / effects を段が持つ。直下には書けない（E86）。
	var has_phases: bool = data.has("phases")
	if activation == ACTIVATION_RECAST and not has_phases:
		_err(issues, skill_id, "activation: recast なのに phases[] が無い（再発動する段が無い）")
	elif has_phases and activation != ACTIVATION_RECAST:
		_err(issues, skill_id, "phases[] は activation: recast のスキルにしか書けない")
	if has_phases:
		if data.has("target") or data.has("effects"):
			_err(issues, skill_id, "phases[] と直下の target / effects は同居できない（どちらが効くか読めなくなる）")
		_validate_phases(issues, skill_id, data.get("phases", null), activation)

	# E8〜E15 target
	# ⚠ phases があるときは走らせない。走らせると、正しく書いた recast スキルが
	#   必ず E8 と E17 の2本を出す。
	var raw_target: Variant = data.get("target", null)
	if has_phases:
		pass
	elif not (raw_target is Dictionary):
		_err(issues, skill_id, "target が無い、または Dictionary でない")
	else:
		_validate_target(issues, skill_id, raw_target as Dictionary, "target", true)
		# E74 パッシブは自分にしか効かない。
		# ⚠ _step_passives() は「宿主に付いているか」で撃ち直すので、他人に
		#   付く形にすると、相手が死ぬたびに撃ち直して無限に付け直す。
		if is_passive and str((raw_target as Dictionary).get("team", "")) != TEAM_SELF:
			_err(issues, skill_id, "activation: 'passive' の target.team は 'self' だけ")

	# E17 effects
	# ⚠ phases があるときは走らせない（E8 と同じ理由）。
	var raw_effects: Variant = data.get("effects", null)
	if has_phases:
		pass
	elif not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, skill_id, "effects が無い、配列でない、または空")
	else:
		var index: int = 0
		for raw_effect: Variant in (raw_effects as Array):
			if not (raw_effect is Dictionary):
				_err(issues, skill_id, "effects[%d] が Dictionary でない" % index)
			else:
				# activation を渡すのは E44 / E45（チャージ専用の欄を instant に
				# 書いていないか）のため。効果だけを見ても判定できない。
				_validate_effect(issues, skill_id, raw_effect as Dictionary, index, activation)
			index += 1

	# E26 知らない欄（typo をここで捕まえる）
	for key: Variant in data:
		if not (str(key) in SKILL_FIELDS_KNOWN):
			_err(issues, skill_id, "知らない欄がある: '%s'" % str(key))

	return issues


# phases[] の検証（E87〜E91）。
#
# ⚠ 段の中身は _validate_target() / _validate_effect() をそのまま呼ぶ。
#   段専用の検証を2本目として書かないこと（片方だけ古くなる）。
static func _validate_phases(
		issues: Array, skill_id: String, raw_phases: Variant, activation: String
) -> void:
	# E87
	if not (raw_phases is Array):
		_err(issues, skill_id, "phases が配列でない")
		return
	var phases: Array = raw_phases as Array
	if phases.size() < PHASES_MIN:
		_err(issues, skill_id, "phases[] は段が %d つ以上要る（今 %d つ。1段なら phases を書かないこと）" % [
			PHASES_MIN, phases.size()
		])

	var index: int = 0
	for raw_phase: Variant in phases:
		var where: String = "phases[%d]" % index
		# E88
		if not (raw_phase is Dictionary):
			_err(issues, skill_id, "%s が Dictionary でない" % where)
			index += 1
			continue
		var phase: Dictionary = raw_phase as Dictionary

		# E89 知らない欄
		for key: Variant in phase:
			if not (str(key) in PHASE_FIELDS_KNOWN):
				_err(issues, skill_id, "%s に知らない欄がある: '%s'" % [where, str(key)])

		# E90 target は段ごとに必須（1段目から引き継がない）
		var raw_target: Variant = phase.get("target", null)
		if not (raw_target is Dictionary):
			_err(issues, skill_id, "%s.target が無い、または Dictionary でない" % where)
		else:
			_validate_target(issues, skill_id, raw_target as Dictionary, where + ".target", true)

		# E91 effects
		var raw_effects: Variant = phase.get("effects", null)
		if not (raw_effects is Array) or (raw_effects as Array).is_empty():
			_err(issues, skill_id, "%s.effects が無い、配列でない、または空" % where)
		else:
			var ei: int = 0
			for raw_effect: Variant in (raw_effects as Array):
				if not (raw_effect is Dictionary):
					_err(issues, skill_id, "%s.effects[%d] が Dictionary でない" % [where, ei])
				else:
					# ⚠ where_prefix を渡すと "phases[0].effects[1]" と出る
					#   （_validate_effect が ".effects[%d]" を足す）。
					_validate_effect(
						issues, skill_id, raw_effect as Dictionary, ei, activation, where
					)
				ei += 1
		index += 1


# target ブロックの検証。effects[].target からも呼ぶ（そちらは range を禁じる）。
static func _validate_target(
		issues: Array, skill_id: String, target: Dictionary, where: String, allow_range: bool
) -> void:
	var team: String = str(target.get("team", ""))

	# E9
	if not (team in TEAMS_KNOWN):
		_err(issues, skill_id, "%s.team が不明: '%s'" % [where, team])
		return

	# E52 team: source に mode / sort / count / range を書かせない（PLAN 10-3）。
	# ⚠ きっかけのユニットIDをそのまま使う欄なので、選び直す語彙を書けてはならない。
	#   書ける形にすると「選び直さない」という決定が JSON 側から破れる。
	if team == TEAM_SOURCE:
		for field: Variant in ["mode", "sort", "count", "range"]:
			if target.has(field):
				_err(issues, skill_id, "%s.team: source に %s は書けない（きっかけのユニットを選び直さない）" % [where, str(field)])
		return

	# E10 team: self に mode / sort / count / origin を書かせない
	# （mode を読むかが team で決まる逆流を作らないため。PLAN 21章）
	# ⚠ origin も同じ。self は mode を読まないので、書いても1つも効かない。
	if team == TEAM_SELF:
		for field: Variant in ["mode", "sort", "count", "origin"]:
			if target.has(field):
				_err(issues, skill_id, "%s.team: self に %s は書けない" % [where, str(field)])
	else:
		# E11
		var mode: String = str(target.get("mode", ""))
		if not (mode in MODES_KNOWN):
			_err(issues, skill_id, "%s.mode が無い、または不明: '%s'" % [where, mode])
		elif mode == MODE_AREA:
			# ⚠ W2（「area は段階4」の黄）は段階4で実装したので消した。残すと
			#   正しい JSON を書くたびに黄が出る（EXEC_SKILL_AREA.md §0-1 の8）。
			#
			# E15 radius … 中心からの距離。⚠ range（使用者からの距離）ではない。
			if not _is_num(target.get("radius", null)) or float(target.get("radius", 0.0)) <= 0.0:
				_err(issues, skill_id, "%s.mode: area なのに radius が正の数値でない" % where)

			# E77 origin … 省略できない（既定値を作らない・ORIGINS_KNOWN の注記）
			var origin: String = str(target.get("origin", ""))
			if not (origin in ORIGINS_KNOWN):
				_err(issues, skill_id, "%s.mode: area の origin が無い、または不明: '%s'（'user' か 'target'）" % [where, origin])
			elif origin == ORIGIN_USER:
				# E78 … origin: user は起点を選ばないので、選ぶための欄が1つも効かない。
				# ⚠ range も同じ。radius が「近くに敵が居るときだけ撃てる」を兼ねる
				#   （radius の中が0体なら select_targets() が空を返し no_target で弾かれる）。
				for field: Variant in ["sort", "range"]:
					if target.has(field):
						_err(issues, skill_id, "%s.origin: user に %s は書けない（起点を選ばない）" % [where, str(field)])
			else:
				# E79 … all は起点が1体に決まらない
				if str(target.get("sort", SORT_NEAREST)) == SORT_ALL:
					_err(issues, skill_id, "%s.origin: target に sort: 'all' は書けない（起点が1体に決まらない）" % where)
				# ⚠ sort そのものの綴りは下の共通の検証（E12）が見る

			# E80 count … radius の中は全員に当たる（人間の決定）
			if target.has("count"):
				_err(issues, skill_id, "%s.mode: area に count は書けない（radius の中は全員）" % where)

			# E12 と同じ綴りの検査を area にも掛ける（2本目の一覧を作らない）
			var area_sort: String = str(target.get("sort", SORT_NEAREST))
			if not (area_sort in SORTS_KNOWN):
				_err(issues, skill_id, "%s.sort が不明: '%s'" % [where, area_sort])
		else:
			# E80 origin … mode: select では読まない欄
			if target.has("origin"):
				_err(issues, skill_id, "%s.origin は mode: 'area' のときだけ書ける" % where)
			# E12 sort（省略は許す＝nearest）
			var sort: String = str(target.get("sort", SORT_NEAREST))
			if not (sort in SORTS_KNOWN):
				_err(issues, skill_id, "%s.sort が不明: '%s'" % [where, sort])
			# E13 count（sort: all は count を読まない。省略は許す＝1）
			elif sort != SORT_ALL and target.has("count"):
				var count: Variant = target.get("count", null)
				if not _is_num(count) or float(count) < 1.0 or float(count) != floor(float(count)):
					_err(issues, skill_id, "%s.count が1以上の整数でない" % where)

	# E14 / E16 range
	if target.has("range"):
		if not allow_range:
			_err(issues, skill_id, "%s に range は書けない（射程はスキルの母集団を絞るもの）" % where)
		elif not _is_num(target.get("range", null)) or float(target.get("range", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.range が正の数値でない" % where)


# 召喚の効果（type: "summon"・段階6・PLAN 14-2）の検証。
#
# ⚠ unit_id が summons.json に実在するかはここで見ない（E100）。この静的クラスは
#   1スキルしか知らない。クロス検証は MasterDataLoader._validate_all_skills()
#   （射程 × attack_range と同じ場所）。
# ⚠ duration_sec / offset_x を is int で見ないこと。MasterDataLoader は JSON の
#   数値を float で返す（E69 はこれで9件を誤って赤にした・CLAUDE.md 3番）。
static func _validate_summon_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String
) -> void:
	# E94 … 4つとも必須。既定値を作らない（origin / stack / scale_from と同じ方針）
	for field: String in SUMMON_FIELDS_REQUIRED:
		if not effect.has(field):
			_err(issues, skill_id, "%s に %s が無い（召喚の欄に既定値は作らない）" % [where, field])

	if str(effect.get("unit_id", "")) == "":
		_err(issues, skill_id, "%s.unit_id が空（summons.json のID）" % where)

	# E95 … 無期限を作らない。上限が無い（人間の決定5）ので、無期限を許すと消えない
	if effect.has("duration_sec"):
		if not _is_num(effect.get("duration_sec", null)):
			_err(issues, skill_id, "%s.duration_sec が数値でない" % where)
		elif float(effect.get("duration_sec", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.duration_sec は 0 より大きいこと（無期限は作らない）" % where)

	# E96 / W13 … 符号は「敵に向かう向きが正」（正＝前衛 / 負＝後衛）
	if effect.has("offset_x"):
		if not _is_num(effect.get("offset_x", null)):
			_err(issues, skill_id, "%s.offset_x が数値でない（正＝前衛 / 負＝後衛）" % where)
		elif is_zero_approx(float(effect.get("offset_x", 0.0))):
			_warn(issues, skill_id, "%s.offset_x が 0（召喚者と完全に重なって数字が読めない）" % where)

	# E97 … 小数を書かせない。N体目の位置が offset_x * (n+1) なので、体数は整数でないと意味が無い
	if effect.has("count"):
		var raw_count: Variant = effect.get("count", null)
		if not _is_num(raw_count):
			_err(issues, skill_id, "%s.count が数値でない" % where)
		elif float(raw_count) != float(int(float(raw_count))) or int(float(raw_count)) < 1:
			_err(issues, skill_id, "%s.count は 1 以上の整数であること: %s" % [where, str(raw_count)])

	# E179 … 召喚の上限（回NC-1）。⚠ 書かなければ上限なし。
	if effect.has(SUMMON_FIELD_MAX_PER_OWNER):
		var cap: Variant = effect.get(SUMMON_FIELD_MAX_PER_OWNER, null)
		if not _is_num(cap) or float(cap) < 1.0 or float(cap) != floor(float(cap)):
			_err(issues, skill_id, "%s.max_per_owner が1以上の整数でない" % where)

	# E98 … 召喚は対象を取らず、威力の式も持たない
	for forbidden: String in SUMMON_FIELDS_FORBIDDEN:
		if effect.has(forbidden):
			_err(issues, skill_id, "%s に %s は書けない（召喚は対象も威力の式も持たない）" % [where, forbidden])


# effects[] の1要素ぶんの検証。
#
# where_prefix … react.effects[] から再帰で呼ぶときの位置（"effects[0].react" の形）。
#                空なら "effects[%d]"。⚠ 表示のためだけの引数。判定に使わない。
# in_react     … 購読の中を見ている（E53：購読の入れ子を禁じる）。
static func _validate_effect(
		issues: Array, skill_id: String, effect: Dictionary, index: int, activation: String,
		where_prefix: String = "", in_react: bool = false
) -> void:
	var where: String = "effects[%d]" % index
	if where_prefix != "":
		where = "%s.effects[%d]" % [where_prefix, index]

	# E18
	var effect_type: String = str(effect.get("type", ""))
	if not (effect_type in EFFECT_TYPES_KNOWN):
		_err(issues, skill_id, "%s.type が無い、または不明: '%s'" % [where, effect_type])
		return

	# W4
	if not (effect_type in EFFECT_TYPES_IMPLEMENTED):
		_warn(issues, skill_id, "%s.type: '%s' はまだ実装していない。飛ばされる" % [where, effect_type])

	# E29〜E43 状態として残る効果（buff / dot / react）
	if effect_type in EFFECT_TYPES_STATUS:
		_validate_status_effect(issues, skill_id, effect, where, activation)

	# E46〜E53 購読（PLAN 10章）
	if effect_type == EFFECT_REACT:
		_validate_react_effect(issues, skill_id, effect, where, activation, in_react)
	elif effect.has("react"):
		# E50 … react{} は react 以外の効果には書けない。
		# ⚠ trigger と購読を同じ欄にしないための歯止め（PLAN 10章）。
		_err(issues, skill_id, "%s.type: '%s' に react{} は書けない（購読は type: 'react' だけ）" % [where, effect_type])

	# E62 … condition{} は残る効果（buff / dot / react）にしか書けない。
	# ⚠ E50 と同じ形の歯止め。書ける場所を1箇所に閉じる。残らない効果に書くと、
	#   毎フレーム評価する相手（状態）が存在しないので、黙って何も起きない。
	if effect.has("condition") and not (effect_type in EFFECT_TYPES_STATUS):
		_err(issues, skill_id, "%s.type: '%s' に condition{} は書けない（残らない効果は毎フレーム評価できない）" % [where, effect_type])

	# E94〜E98 召喚（段階6・PLAN 14-2）
	if effect_type == EFFECT_SUMMON:
		_validate_summon_effect(issues, skill_id, effect, where)
	else:
		# E99 … 召喚だけの欄を他の効果に書かせない。
		# ⚠ unit_id は「召喚するID」の意味で、results が持つ unit_id（＝殴られた側）と
		#   紛らわしい。1つの語が2つの意味を持つ状態を作らない（PLAN 1章の病気）。
		# ⚠ count だけは召喚を使う効果（summon_consume）にも書く（⚠ 何体使うか）。
		for summon_field: String in SUMMON_ONLY_FIELDS + [SUMMON_FIELD_MAX_PER_OWNER]:
			if summon_field == "count" and effect_type == EFFECT_SUMMON_CONSUME:
				continue
			if effect.has(summon_field):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない（type: 'summon' だけの欄）" % [
					where, effect_type, summon_field
				])

	# E164〜E165 行動を止める・押し出す（回CH-5）
	if effect.has(BUFF_CONTROL):
		var control: String = str(effect.get(BUFF_CONTROL, ""))
		if effect_type != EFFECT_BUFF:
			_err(issues, skill_id, "%s.type: '%s' に control は書けない（buff だけ）" % [where, effect_type])
		elif not (control in CONTROLS_KNOWN):
			_err(issues, skill_id, "%s.control が不明: '%s'（%s）" % [where, control, str(CONTROLS_KNOWN)])
		elif str(effect.get("host", "")) != HOST_UNIT:
			_err(issues, skill_id, "%s.control は host: 'unit' にしか書けない" % where)
	if effect_type == EFFECT_KNOCKBACK:
		var distance: Variant = effect.get("distance", null)
		if not _is_num(distance) or float(distance) <= 0.0:
			_err(issues, skill_id, "%s.distance が正の数でない（type: 'knockback' は必須）" % where)
		for forbidden: String in ["scale_from", "multiplier", "attack_type", "host"]:
			if effect.has(forbidden):
				_err(issues, skill_id, "%s.type: 'knockback' に %s は書けない" % [where, forbidden])
	elif effect_type == EFFECT_DASH:
		# E166 … to と、それに合う欄（target なら offset・back なら distance）
		var to: String = str(effect.get("to", ""))
		if not (to in DASH_TOS_KNOWN):
			_err(issues, skill_id, "%s.to が不明: '%s'（%s）" % [where, to, str(DASH_TOS_KNOWN)])
		elif to == DASH_TO_TARGET:
			var offset: Variant = effect.get("offset", null)
			if not _is_num(offset) or float(offset) < 0.0:
				_err(issues, skill_id, "%s.offset が 0 以上の数でない（to: 'target' は必須）" % where)
			if effect.has("distance"):
				_err(issues, skill_id, "%s.to: 'target' に distance は書けない（offset で書く）" % where)
		else:
			var back: Variant = effect.get("distance", null)
			if not _is_num(back) or float(back) <= 0.0:
				_err(issues, skill_id, "%s.distance が正の数でない（to: 'back' は必須）" % where)
			if effect.has("offset"):
				_err(issues, skill_id, "%s.to: 'back' に offset は書けない" % where)
		for forbidden: String in ["scale_from", "multiplier", "attack_type", "host"]:
			if effect.has(forbidden):
				_err(issues, skill_id, "%s.type: 'dash' に %s は書けない" % [where, forbidden])
	elif effect.has("distance"):
		_err(issues, skill_id, "%s.type: '%s' に distance は書けない（knockback / dash だけ）" % [where, effect_type])
	if effect_type != EFFECT_DASH:
		for dash_field: String in ["to", "offset"]:
			if effect.has(dash_field):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない（dash だけ）" % [where, effect_type, dash_field])

	# E183〜E186 神の使い（回GM-1）
	_validate_gm_fields(issues, skill_id, effect, where, effect_type, activation, in_react)

	# E178 自分の召喚を使う（回NC-1）
	if effect_type == EFFECT_SUMMON_CONSUME:
		_validate_summon_consume(issues, skill_id, effect, where)
	else:
		for consume_field: String in [CONSUME_FIELD_UNIT_IDS, CONSUME_FIELD_BLAST_RADIUS]:
			if effect.has(consume_field):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない（summon_consume だけ）" % [where, effect_type, consume_field])

	# E177 貫通する飛び道具（回PQ-2）
	if effect.has(FIELD_PIERCE_LENGTH):
		var length: Variant = effect.get(FIELD_PIERCE_LENGTH, null)
		if not _is_num(length) or float(length) <= 0.0:
			_err(issues, skill_id, "%s.pierce_length が正の数でない" % where)
		# ⚠ damage は送り方が要る（飛ぶもの）。⚠ 回NC-1：buff・resource にも書ける（⚠ 同じ矢に乗る＝通り過ぎた敵ごとに付く・増える）。
		if effect_type == EFFECT_DAMAGE:
			if not (str(effect.get("delivery", "")) in [DELIVERY_PROJECTILE, DELIVERY_MAGIC]):
				_err(issues, skill_id, "%s.pierce_length は delivery: 'projectile' ／ 'magic' にしか書けない（飛ぶもの）" % where)
		elif not (effect_type in PIERCE_RIDER_TYPES):
			_err(issues, skill_id, "%s.type: '%s' に pierce_length は書けない（damage ／ %s）" % [where, effect_type, str(PIERCE_RIDER_TYPES)])
		if str(effect.get("trigger", "")) != TRIGGER_PREFIX_EVENT + EVENT_HIT:
			_err(issues, skill_id, "%s.pierce_length は trigger: 'event:hit' と一緒に書く（通り過ぎた瞬間に当たる）" % where)
		if effect.has("target"):
			_err(issues, skill_id, "%s.pierce_length に target は書けない（前へ pierce_length の中の敵が対象）" % where)

	# E176 自分についての条件（回PQ-1）
	if effect.has(FIELD_WHEN_USER):
		var raw_when_user: Variant = effect.get(FIELD_WHEN_USER, null)
		if not (raw_when_user is Dictionary):
			_err(issues, skill_id, "%s.when_user が辞書でない" % where)
		else:
			var when_user: Dictionary = raw_when_user as Dictionary
			if not (str(when_user.get("source", "")) in WHEN_USER_SOURCES):
				_err(issues, skill_id, "%s.when_user.source が不明: '%s'（%s）" % [where, str(when_user.get("source", "")), str(WHEN_USER_SOURCES)])
			if not _is_num(when_user.get("radius", null)) or float(when_user.get("radius", 0)) <= 0.0:
				_err(issues, skill_id, "%s.when_user.radius が正の数でない" % where)
			if not (str(when_user.get("op", "")) in COND_OPS_KNOWN):
				_err(issues, skill_id, "%s.when_user.op が不明: '%s'" % [where, str(when_user.get("op", ""))])
			if not _is_num(when_user.get("value", null)):
				_err(issues, skill_id, "%s.when_user.value が数値でない" % where)

	# E169〜E171 相手の状態で変わる・処刑（回CH-8）
	if effect.has(FIELD_WHEN_TARGET):
		var raw_when: Variant = effect.get(FIELD_WHEN_TARGET, null)
		if not (raw_when is Dictionary):
			_err(issues, skill_id, "%s.when_target が辞書でない" % where)
		else:
			var when: Dictionary = raw_when as Dictionary
			var when_source: String = str(when.get("source", ""))
			if not (when_source in WHENS_KNOWN):
				_err(issues, skill_id, "%s.when_target.source が不明: '%s'（%s）" % [where, when_source, str(WHENS_KNOWN)])
			elif when_source == WHEN_STATUS_HAS:
				if str(when.get("status_id", "")) == "":
					_err(issues, skill_id, "%s.when_target に status_id が無い（status_has は必須）" % where)
			else:
				if not (str(when.get("op", "")) in COND_OPS_KNOWN):
					_err(issues, skill_id, "%s.when_target.op が不明: '%s'" % [where, str(when.get("op", ""))])
				if not _is_num(when.get("value", null)):
					_err(issues, skill_id, "%s.when_target.value が数値でない" % where)
	elif effect.has(FIELD_WHEN_MULT) or effect.has(FIELD_WHEN_CRIT):
		_err(issues, skill_id, "%s の when_mult ／ when_crit は when_target と一緒にしか書けない" % where)
	if effect.has(FIELD_WHEN_MULT):
		if effect_type != EFFECT_DAMAGE:
			_err(issues, skill_id, "%s.when_mult は damage にしか書けない" % where)
		if not _is_num(effect.get(FIELD_WHEN_MULT, null)) or float(effect.get(FIELD_WHEN_MULT, 0)) <= 0.0:
			_err(issues, skill_id, "%s.when_mult が正の数でない" % where)
	if effect.has(FIELD_WHEN_CRIT):
		if effect_type != EFFECT_DAMAGE:
			_err(issues, skill_id, "%s.when_crit は damage にしか書けない" % where)
		if effect.get(FIELD_WHEN_CRIT, null) != true:
			_err(issues, skill_id, "%s.when_crit は true だけ書ける" % where)
	if effect.has(FIELD_EXECUTE_BELOW):
		var below: Variant = effect.get(FIELD_EXECUTE_BELOW, null)
		if effect_type != EFFECT_DAMAGE:
			_err(issues, skill_id, "%s.execute_below は damage にしか書けない" % where)
		if not _is_num(below) or float(below) <= 0.0 or float(below) >= 1.0:
			_err(issues, skill_id, "%s.execute_below が 0 より大きく 1 未満でない" % where)
	if effect.has(FIELD_EXECUTE_BOSS_MULT):
		if not effect.has(FIELD_EXECUTE_BELOW):
			_err(issues, skill_id, "%s.execute_boss_mult は execute_below と一緒にしか書けない" % where)
		if not _is_num(effect.get(FIELD_EXECUTE_BOSS_MULT, null)) or float(effect.get(FIELD_EXECUTE_BOSS_MULT, 0)) <= 0.0:
			_err(issues, skill_id, "%s.execute_boss_mult が正の数でない" % where)

	# E167〜E168 クールダウン・解除（回CH-7）
	if effect_type == EFFECT_COOLDOWN:
		var amounts: int = 0
		for amount_field: String in ["sec", "pct", "all"]:
			if effect.has(amount_field):
				amounts += 1
		if amounts != 1:
			_err(issues, skill_id, "%s は sec ／ pct ／ all のどれか1つを書く" % where)
		if effect.has("sec") and (not _is_num(effect.get("sec", null)) or float(effect.get("sec", 0)) <= 0.0):
			_err(issues, skill_id, "%s.sec が正の数でない" % where)
		if effect.has("pct") and (not _is_num(effect.get("pct", null)) or float(effect.get("pct", 0)) <= 0.0 or float(effect.get("pct", 0)) > 100.0):
			_err(issues, skill_id, "%s.pct が 0 より大きく 100 以下でない" % where)
		if effect.has("all") and effect.get("all", null) != true:
			_err(issues, skill_id, "%s.all は true だけ書ける" % where)
		var raw_skills: Variant = effect.get("skills", null)
		if raw_skills is Array:
			if (raw_skills as Array).is_empty():
				_err(issues, skill_id, "%s.skills が空の配列" % where)
		elif not (str(raw_skills) in [COOLDOWN_SKILLS_ALL, COOLDOWN_SKILLS_OTHERS]):
			_err(issues, skill_id, "%s.skills が 'all' ／ 'others' ／ ID の配列でない（必須）" % where)
		if effect.has(COOLDOWN_FIELD_EXCEPT):
			_err(issues, skill_id, "%s.%s はデータに書けない（撃つ瞬間にコードが書く）" % [where, COOLDOWN_FIELD_EXCEPT])
	else:
		for cd_field: String in ["sec", "pct", "all", "skills"]:
			if effect.has(cd_field):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない（cooldown だけ）" % [where, effect_type, cd_field])
	if effect_type == EFFECT_DISPEL:
		if not (str(effect.get("what", "")) in [DISPEL_DEBUFF, DISPEL_BUFF]):
			_err(issues, skill_id, "%s.what が 'debuff' ／ 'buff' でない（必須）" % where)
	elif effect.has("what"):
		_err(issues, skill_id, "%s.type: '%s' に what は書けない（dispel だけ）" % [where, effect_type])
	if effect_type in [EFFECT_COOLDOWN, EFFECT_DISPEL]:
		for forbidden: String in ["scale_from", "multiplier", "attack_type", "host"]:
			if effect.has(forbidden):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない" % [where, effect_type, forbidden])

	# E162〜E163 通常攻撃を置き換える（回CH-4）
	if effect.has(BUFF_BASIC_ATTACK) or effect.has(BUFF_USES):
		_validate_basic_override(issues, skill_id, effect, where, effect_type)

	# E150〜E152 固有の資源（回CH-1）
	if effect_type == EFFECT_RESOURCE:
		_validate_resource_effect(issues, skill_id, effect, where)
	else:
		# E150 … 資源だけの欄を他の効果に書かせない（E99 と同じ形）。
		for resource_field: String in RESOURCE_ONLY_FIELDS:
			if effect.has(resource_field):
				_err(issues, skill_id, "%s.type: '%s' に %s は書けない（type: 'resource' だけの欄）" % [
					where, effect_type, resource_field
				])

	if effect_type == EFFECT_DAMAGE or effect_type == EFFECT_HEAL:
		# E19
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)

		# E20 / E21 attack_type
		if effect_type == EFFECT_DAMAGE:
			if effect.has("attack_type"):
				var attack_type: String = str(effect.get("attack_type", ""))
				if not (attack_type in attack_types_known()):
					_err(issues, skill_id, "%s.attack_type が不明: '%s'" % [where, attack_type])
		elif effect.has("attack_type"):
			# 回復が攻撃力依存だった事故の再発防止。欄そのものを作らない（PLAN 5-2）
			_err(issues, skill_id, "%s は heal なので attack_type を書けない" % where)

		# E27 scale_from は必須。既定値を作らない（決定1-5）
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（damage / heal は必須）" % where)

	# E22 scale_from の形（buff などが書いてきた場合もここで見る）
	if effect.has("scale_from"):
		_validate_scale_from(issues, skill_id, effect.get("scale_from", null), where)

	# E23
	if effect.has("chance"):
		if not _is_num(effect.get("chance", null)):
			_err(issues, skill_id, "%s.chance が数値でない" % where)
		elif float(effect.get("chance", 1.0)) < 1.0:
			# W8
			_warn(issues, skill_id, "%s.chance は段階1では読まれない（必ず当たる扱い）" % where)
	if effect.has("charge_scales") and not (effect.get("charge_scales", null) is bool):
		_err(issues, skill_id, "%s.charge_scales が bool でない" % where)

	# E28 delivery（書いてあって値が不明なら赤。省略は許す＝melee）
	if effect.has("delivery") and not (str(effect.get("delivery", "")) in DELIVERIES_KNOWN):
		_err(issues, skill_id, "%s.delivery が不明: '%s'" % [where, str(effect.get("delivery", ""))])

	# E24 / W5 trigger
	# cast / charge_start / delay:<数値> は段階2で実装した。警告を出さない。
	# event:◯◯ だけは合図を出す側（演出シーン）が存在しないので黄のまま。
	var trigger: String = str(effect.get("trigger", TRIGGER_CAST))
	if not _is_trigger_shape(trigger):
		_err(issues, skill_id, "%s.trigger の形が不正: '%s'" % [where, trigger])
	elif trigger == TRIGGER_PREFIX_EVENT + EVENT_HIT:
		# ⚠ 'hit' だけは合図を出す側が居る（ProjectileView が着弾で返す）。
		#   ここで黄を出さないこと。飛ぶ効果は十数件あるので、出すと本物の異常が埋まる。
		pass
	elif trigger.begins_with(TRIGGER_PREFIX_EVENT):
		_warn(issues, skill_id, "%s.trigger: '%s' は合図を出す側が居ない（アニメ未実装）。タイムアウトで発火する" % [where, trigger])

	# E45 charge_start は SkillRuntime.charge_start() からしか流れない。
	# チャージしないスキルに書くと一度も発火しない。無音なので赤で弾く。
	if trigger == TRIGGER_CHARGE_START and activation != ACTIVATION_CHARGE:
		_err(issues, skill_id, "%s.trigger: 'charge_start' は activation: charge のスキルにしか書けない" % where)

	# E75 / E76 パッシブの効果の縛り（EXEC_SKILL_PASSIVE_VARS.md §2-6 / §2-7）
	#
	# ⚠ どれも「_step_passives() が毎フレーム撃ち直す」形になるのを防ぐもの。
	#   走査は「宿主にその status_id が付いていなければ撃つ」しか見ていないので、
	#   付き方がズレると毎フレーム cast が走り、フレームレートごと落ちる。
	if activation == ACTIVATION_PASSIVE:
		# E76 … 遅れて付くものは、付くまでの間ずっと「欠けている」と判定される
		if trigger != TRIGGER_CAST:
			_err(issues, skill_id, "%s.trigger: activation: 'passive' の効果は 'cast' だけ（遅れて付くと毎フレーム撃ち直す）" % where)
		if effect.has("status_id"):
			# E75 … independent だと撃つたびに新しい1件が積まれる
			if str(effect.get("stack", "")) != STACK_REFRESH:
				_err(issues, skill_id, "%s.stack: activation: 'passive' の効果は 'refresh' だけ（毎フレーム積み上がる）" % where)
			# host: unit 以外だと「宿主に付いているか」で判定できない
			# ⚠ 例外：自分についてくる範囲（host: point・zone.follow: true）＝付けた人で探せる（回MC-1・傭兵の「周りの敵の攻撃力低下」）。
			var passive_host: String = str(effect.get("host", HOST_NONE))
			var follows: bool = passive_host == HOST_POINT and effect.get(FIELD_ZONE, null) is Dictionary \
					and (effect[FIELD_ZONE] as Dictionary).get(ZONE_FOLLOW, false) == true
			if passive_host != HOST_UNIT and not follows:
				_err(issues, skill_id, "%s.host: activation: 'passive' の効果は 'unit' だけ（⚠ ついてくる範囲は書ける）" % where)

	# E25 / E30 / W6 / W9 host
	var host: String = str(effect.get("host", HOST_NONE))
	if not (host in HOSTS_KNOWN):
		_err(issues, skill_id, "%s.host が不明: '%s'" % [where, host])
	elif host == HOST_NONE:
		pass
	elif host == HOST_SPAWN:
		# E93 … 段階6で type: "summon" を実装したので、書き方は1本に絞る（人間の決定7）。
		#
		# ⚠ 同じことが2通り書ける状態を残さない（phases と top-level の target を
		#   同居させない E86 と同じ形）。⚠ HOST_SPAWN の定数は消さない。PLAN 9章の
		#   分類語（何がどこに残るか）としては生きている。
		# ⚠ この枝は E30 より前に置くこと。あとに置くと、damage に host: 'spawn' と
		#   書いたときに E30 と2本出る。
		_err(issues, skill_id, "%s.host: 'spawn' は書けない（召喚は type: 'summon' で書く）" % where)
	elif not (effect_type in EFFECT_TYPES_STATUS):
		# E30 … 残らないものに宿主は無い（damage / heal に host を書いている）
		_err(issues, skill_id, "%s.type: '%s' に host: '%s' は書けない（残らない効果）" % [where, effect_type, host])
	elif host == HOST_BATTLE:
		# W9 … 器には載るが、参照する仕組み（条件・購読）がまだ無いので何も起きない。
		# ⚠ point はこの回（EXEC_SKILL_AURA.md）で読む側が入ったので外した。battle は残る。
		_warn(issues, skill_id, "%s.host: '%s' は器に載るだけ。参照する仕組み（条件・購読）がまだ無い" % [where, host])
	elif host == HOST_POINT and effect_type == EFFECT_REACT:
		# W15 … 罠（point × 購読）。⚠ 購読の配布は host: unit のみ（宿題8）。
		#   器には載るが1度も発火しない。⚠ buff / dot は読む側が入ったので黄を出さない。
		_warn(issues, skill_id, "%s.host: 'point' の react は器に載るだけ。購読の配布は host: 'unit' のみ" % where)

	# 範囲（zone{}）。⚠ host: point にしか書けず、host: point には必ず要る。
	_validate_zone(issues, skill_id, effect, where, host, effect_type)

	# W16 … 効果の直下の知らない欄（EXEC_SILENT_HOLES.md）。
	#
	# ⚠ 黄にする（赤にしない）。赤にすると、見落としが1件でもあった瞬間に
	#   ゲームが起動しなくなる。⚠ 出た件数を見てから赤に上げるかを人間が決める。
	for key: Variant in effect.keys():
		if not (str(key) in EFFECT_FIELDS_KNOWN):
			_warn(issues, skill_id, "%s に知らない欄がある: '%s'（書いても何も起きない）" % [where, str(key)])

	# E116 / E117 … 攻撃力の倍率。
	if effect.has(BUFF_ATK_MULT_PCT):
		if effect_type != EFFECT_BUFF:
			_err(issues, skill_id, "%s.%s は buff にしか書けない（type: '%s'）" % [
				where, BUFF_ATK_MULT_PCT, effect_type
			])
		else:
			# ⚠ 0 は禁止（何も起きない欄を書かせない・E39 と同じ）。
			var mult: Variant = effect.get(BUFF_ATK_MULT_PCT, null)
			if not _is_num(mult) or float(mult) != floor(float(mult)) or int(mult) == 0:
				_err(issues, skill_id, "%s.%s が0以外の整数でない" % [where, BUFF_ATK_MULT_PCT])

	# 効果ごとの target 上書き（range は書けない＝E16）
	var raw_target: Variant = effect.get("target", null)
	if raw_target != null:
		if not (raw_target is Dictionary):
			_err(issues, skill_id, "%s.target が Dictionary でない" % where)
		else:
			_validate_target(issues, skill_id, raw_target as Dictionary, where + ".target", false)


# 購読（type: "react"）の検証。E46〜E53。
#
# ⚠ 寿命・重ねがけ・status_id は _validate_status_effect() が共通で見る。
#   ここで見るのは react{} の中身だけ（同じ判定を2箇所に書かない）。
static func _validate_react_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String,
		activation: String, in_react: bool
) -> void:
	# E53 購読の入れ子。⚠ 再帰の深さを1段に固定する歯止め。
	#    入れ子を許すと「反応の反応」が書けてしまい、10-2 の印だけでは止まらない。
	if in_react:
		_err(issues, skill_id, "%s: 購読の中に購読は書けない（反応から反応を生まない・PLAN 10-2）" % where)
		return

	# E51 宿り先は unit だけ。point（罠）は座標の規則が要る、battle（コンボ）は段階3の後半②以降。
	var host: String = str(effect.get("host", HOST_NONE))
	if host != HOST_UNIT:
		_err(issues, skill_id, "%s.host: '%s' に購読は載せられない（今は host: 'unit' だけ）" % [where, host])

	# E46
	var raw_react: Variant = effect.get("react", null)
	if not (raw_react is Dictionary):
		_err(issues, skill_id, "%s に react{} が無い、または Dictionary でない" % where)
		return
	var react: Dictionary = raw_react as Dictionary

	# E47 出来事の名前。⚠ trigger の合図（EVENT_HIT）は書けない（別の一覧）。
	var event_name: String = str(react.get("event", ""))
	if not (event_name in EVENTS_KNOWN):
		_err(issues, skill_id, "%s.react.event が無い、または不明: '%s'" % [where, event_name])

	# E188 近くで（回MC-1）。⚠ foe_died だけ・正の数。
	if react.has(REACT_FIELD_WITHIN):
		var within: Variant = react.get(REACT_FIELD_WITHIN, null)
		if event_name != EVENT_FOE_DIED:
			_err(issues, skill_id, "%s.react.within は event: 'foe_died' にしか書けない" % where)
		elif not _is_num(within) or float(within) <= 0.0:
			_err(issues, skill_id, "%s.react.within が正の数でない" % where)

	# E48
	var raw_effects: Variant = react.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, skill_id, "%s.react.effects が無い、配列でない、または空" % where)
		return

	# E49 … 中身は effects[] と同じ検証を通す（2本目の語彙を作らない）。
	var index: int = 0
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			_err(issues, skill_id, "%s.react.effects[%d] が Dictionary でない" % [where, index])
		else:
			# E54 … 購読にはスキルの target が無い（反応する側の効果は単独で立つ）。
			# ⚠ 書き忘れると実行時に「target が無い」の赤が出るだけで、何も起きない。
			# ⚠ 召喚・召喚を使う効果は対象を取らない（⚠ target は書けない＝E98／E178）＝除く（回NC-1）。
			if not (raw_effect as Dictionary).has("target") \
					and not (str((raw_effect as Dictionary).get("type", "")) in TARGETLESS_EFFECT_TYPES):
				_err(issues, skill_id, "%s.react.effects[%d] に target が無い（購読の効果は各自に要る）" % [where, index])
			_validate_effect(
				issues, skill_id, raw_effect as Dictionary, index, activation,
				where + ".react", true
			)
		index += 1


# 状態として残る効果（buff / dot / react）の検証。E29〜E44 / W10 / W11。
#
# ⚠ ここで見るのは「無音で壊れる書き方」だけ。状態は、剥がれない・二重に付く・
#   一度も発火しない のどれもエラーを出さないので、書いた時点で弾く。
# 能力値の欄（回DB-1 で切り出した・E37〜E39 ＋ E174）。⚠ どれも無ければ false（⚠ 検査もしない）。
# ⚠ stat は value か stat_pct のどちらか（両方でもよい）と一緒に書く。
static func _validate_stat_fields(issues: Array, skill_id: String, effect: Dictionary, where: String) -> bool:
	var has_value: bool = effect.has("value")
	var has_pct: bool = effect.has(FIELD_STAT_PCT)
	if not effect.has("stat") and not has_value and not has_pct:
		return false
	# E37 / E38
	var stat_key: String = str(effect.get("stat", ""))
	if not (stat_key in GameManager.get_stat_keys()):
		_err(issues, skill_id, "%s.stat が10軸に無い: '%s'" % [where, stat_key])
	elif stat_key == GameStateKeys.STAT_HP:
		_err(issues, skill_id, "%s.stat に hp は書けない（max_hp を再計算しないため）" % where)
	# E39 … 0 も禁止（何も起きない状態を書かせない）
	if has_value:
		var value: Variant = effect.get("value", null)
		if not _is_num(value) or float(value) != floor(float(value)) or int(value) == 0:
			_err(issues, skill_id, "%s.value が0以外の整数でない" % where)
	# E174 … 割合（回DB-1）。⚠ −95〜（−100 で 0 になる＝何も起きない状態と同じ扱いにしない）
	if has_pct:
		var pct: Variant = effect.get(FIELD_STAT_PCT, null)
		if not _is_num(pct) or float(pct) != floor(float(pct)) or int(pct) == 0 or float(pct) < -95.0:
			_err(issues, skill_id, "%s.stat_pct が −95 以上の0以外の整数でない" % where)
	if not has_value and not has_pct:
		_err(issues, skill_id, "%s.stat に value も stat_pct も無い" % where)
	return true


# 通常攻撃を置き換える buff の欄（回CH-4）。
static func _validate_basic_override(
		issues: Array, skill_id: String, effect: Dictionary, where: String, effect_type: String
) -> void:
	# E162 … buff だけ・basic_attack は通常攻撃と同じ形
	if effect_type != EFFECT_BUFF:
		_err(issues, skill_id, "%s.type: '%s' に %s / %s は書けない（buff だけ）" % [where, effect_type, BUFF_BASIC_ATTACK, BUFF_USES])
		return
	if not effect.has(BUFF_BASIC_ATTACK):
		_err(issues, skill_id, "%s.%s は %s と一緒にしか書けない" % [where, BUFF_USES, BUFF_BASIC_ATTACK])
		return
	var raw: Variant = effect.get(BUFF_BASIC_ATTACK, null)
	if not (raw is Dictionary):
		_err(issues, skill_id, "%s.%s が辞書でない" % [where, BUFF_BASIC_ATTACK])
		return
	for issue: Variant in validate_basic_attack("%s %s.%s" % [skill_id, where, BUFF_BASIC_ATTACK], raw as Dictionary):
		issues.append(issue)
	# E163 … uses は1以上の整数（⚠ 書かなければ duration_sec のあいだずっと）
	if effect.has(BUFF_USES):
		var uses: Variant = effect.get(BUFF_USES, null)
		if not _is_num(uses) or float(uses) < 1.0 or float(uses) != floor(float(uses)):
			_err(issues, skill_id, "%s.%s が1以上の整数でない" % [where, BUFF_USES])


# 「◯回ごと」の一撃（回CH-4・characters.json の basic_attack_every）。
#   "basic_attack_every": { "every": 3, "attack": { "effects": [...] } }
# ⚠ every 回目の通常攻撃が attack に置き換わる（人間「⚠ １あ」）。⚠ 数えるのは全部の通常攻撃（「⚠ ３あ」）。
const FIELD_BASIC_EVERY: String = "basic_attack_every"


static func validate_basic_attack_every(owner_id: String, data: Dictionary) -> Array:
	var issues: Array = []
	var every: Variant = data.get("every", null)
	if not _is_num(every) or float(every) < 2.0 or float(every) != floor(float(every)):
		_err(issues, owner_id, "%s.every が2以上の整数でない" % FIELD_BASIC_EVERY)
	var raw: Variant = data.get("attack", null)
	if not (raw is Dictionary):
		_err(issues, owner_id, "%s.attack が辞書でない" % FIELD_BASIC_EVERY)
		return issues
	for key: Variant in data:
		if not (str(key) in ["every", "attack"]):
			_err(issues, owner_id, "%s に知らない欄がある: '%s'" % [FIELD_BASIC_EVERY, str(key)])
	for issue: Variant in validate_basic_attack(owner_id + " " + FIELD_BASIC_EVERY + ".attack", raw as Dictionary):
		issues.append(issue)
	return issues


# type: "resource" の欄（回CH-1）。
static func _validate_resource_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String
) -> void:
	# E151 resource_id は必須
	if str(effect.get(RESOURCE_FIELD_ID, "")) == "":
		_err(issues, skill_id, "%s.resource_id が無い（type: 'resource' は必須）" % where)
	# E152 amount と set_to はどちらか1つ・整数
	var has_amount: bool = effect.has(RESOURCE_FIELD_AMOUNT)
	var has_set_to: bool = effect.has(RESOURCE_FIELD_SET_TO)
	if has_amount == has_set_to:
		_err(issues, skill_id, "%s は amount と set_to のどちらか1つを書く" % where)
	for field: String in [RESOURCE_FIELD_AMOUNT, RESOURCE_FIELD_SET_TO]:
		if not effect.has(field):
			continue
		var raw: Variant = effect.get(field, null)
		if not _is_num(raw) or float(raw) != floor(float(raw)):
			_err(issues, skill_id, "%s.%s が整数でない" % [where, field])
	if has_set_to and _is_num(effect.get(RESOURCE_FIELD_SET_TO, null)) and float(effect.get(RESOURCE_FIELD_SET_TO, 0)) < 0.0:
		_err(issues, skill_id, "%s.set_to が負" % where)
	# E161 … target は撃った本人だけ（⚠ 資源は持ち主のもの）。⚠ per_target_stack のときだけ source（数を数える相手）。
	var per_stack: bool = effect.has(RESOURCE_FIELD_PER_STACK)
	var want_team: String = TEAM_SOURCE if per_stack else TEAM_SELF
	if effect.has("target") or per_stack:
		var raw_target: Variant = effect.get("target", null)
		if not (raw_target is Dictionary) or str((raw_target as Dictionary).get("team", "")) != want_team or (raw_target as Dictionary).size() != 1:
			_err(issues, skill_id, "%s.type: 'resource' の target は {\"team\": \"%s\"} だけ書ける" % [where, want_team])
	if per_stack and (str(effect.get(RESOURCE_FIELD_PER_STACK, "")) == "" or effect.has(RESOURCE_FIELD_SET_TO)):
		_err(issues, skill_id, "%s.per_target_stack は状態の ID を amount と一緒に書く" % where)
	for forbidden: String in RESOURCE_FIELDS_FORBIDDEN:
		if effect.has(forbidden):
			_err(issues, skill_id, "%s.type: 'resource' に %s は書けない（宛先は撃った本人・威力の式を持たない）" % [where, forbidden])


static func _validate_status_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String, activation: String
) -> void:
	var effect_type: String = str(effect.get("type", ""))

	# E29 残らない状態は書けない
	var host: String = str(effect.get("host", HOST_NONE))
	if host == HOST_NONE:
		_err(issues, skill_id, "%s.type: '%s' には host が要る（残らない状態は書けない）" % [where, effect_type])

	# E55〜E61 条件（毎フレーム評価する発火源・PLAN 10章）
	if effect.has("condition"):
		_validate_condition(issues, skill_id, effect.get("condition", null), where, host)

	# E36 identity
	if str(effect.get("status_id", "")) == "":
		_err(issues, skill_id, "%s.status_id が無い" % where)
	else:
		# W17 … 状態のマスに出す漢字1文字が翻訳表に無い（EXEC_STATUS_UI.md §3-E）。
		#
		# ⚠ 黄にする（赤にしない）。行が無くても戦闘は動く（マスに「？」が出る）。
		# ⚠ 静的関数から tr() は呼べない。TranslationServer.translate() を使う（AGENTS.md）。
		# ⚠ 「？」だけだと、漏れているのか本当にその状態なのかが画面から区別できない。
		#   ここで件数が出るので、ロード時に漏れが分かる。
		var status_id: String = str(effect.get("status_id", ""))
		var chip_key: String = "ui_status_ch_" + status_id
		if TranslationServer.translate(chip_key) == chip_key:
			_warn(issues, skill_id, "%s.status_id: '%s' の漢字が翻訳表に無い（%s）。マスに「？」が出る" % [
				where, status_id, chip_key
			])

	# E35 重ねがけ規則は省略不可
	if not effect.has("stack"):
		_err(issues, skill_id, "%s.stack が無い（independent / refresh を必ず書く）" % where)
	elif not (str(effect.get("stack", "")) in STACKS_KNOWN):
		_err(issues, skill_id, "%s.stack が不明: '%s'" % [where, str(effect.get("stack", ""))])

	# E69 / E70 上限（PLAN 13-1・宿題6）
	# ⚠ independent は上限が無いと無限に積む。stack:<状態ID> の変数を作った以上、
	#   上限が無いと閾値が一度真になったら二度と偽に戻らない
	#   （EXEC_SKILL_CONDITION.md §2-3）。だから必須にする。
	var stack_rule: String = str(effect.get("stack", ""))
	if stack_rule == STACK_INDEPENDENT:
		var raw_max: Variant = effect.get(FIELD_MAX_STACK, null)
		# ⚠ `raw_max is int` と書かないこと。JSON の 5 は 5.0（float）で来るので
		#   常に偽になり、正しく書いてある max_stack が全部赤になる（CLAUDE.md 3番）。
		#   ⚠ 2026-08-18 に実機で発覚。④-a から9件ぶん赤が出続けていた。
		#   整数かどうかは floor と比べて見る（E13 と同じ形）。
		if not _is_num(raw_max) or float(raw_max) < 1.0 or float(raw_max) != floor(float(raw_max)):
			_err(issues, skill_id, "%s.%s が無い、または1以上の整数でない（stack: 'independent' には必須）" % [
				where, FIELD_MAX_STACK
			])
	elif effect.has(FIELD_MAX_STACK):
		# ⚠ refresh は同一性のキーで置き直すので上限が意味を持たない。
		#   何も起きない欄を書かせない（E39 と同じ考え方）。
		_err(issues, skill_id, "%s.%s は stack: 'independent' のときだけ書ける" % [where, FIELD_MAX_STACK])

	# E31 / E32 寿命は duration_sec か until のどちらか一方
	var has_duration: bool = effect.has("duration_sec")
	var has_until: bool = effect.has("until")
	if not has_duration and not has_until:
		_err(issues, skill_id, "%s に duration_sec も until も無い" % where)
	elif has_duration and has_until:
		_err(issues, skill_id, "%s に duration_sec と until の両方がある（排他）" % where)

	# E33
	if has_duration:
		if not _is_num(effect.get("duration_sec", null)) or float(effect.get("duration_sec", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.duration_sec が正の数値でない" % where)

	# E34 / E44 / W11
	if has_until:
		var until: String = str(effect.get("until", ""))
		if not (until in UNTILS_KNOWN):
			_err(issues, skill_id, "%s.until が不明: '%s'" % [where, until])
		elif until == UNTIL_CHARGE_END and activation != ACTIVATION_CHARGE:
			# ⚠ 剥がす経路がチャージ終了しか無い。instant に書くと永久に残る
			_err(issues, skill_id, "%s.until: 'charge_end' は activation: charge のスキルにしか書けない" % where)
		elif until == UNTIL_SKILL_END:
			_warn(issues, skill_id, "%s.until: 'skill_end' は未実装（剥がす配線が無い）。この効果は飛ばされる" % where)

	# 介入点の欄（PLAN 11-1・段階3の後半③ ＋ EXEC_SKILL_MITIGATION.md）。
	# ⚠ 一覧はここ1本。status_registry.gd に2本目を作らないこと。
	#
	# E102 … 平置きは赤。intervene{} へ畳んだ（人間の決定2）ので、古い書き方が
	#        残っていると無音で無視される（宿題11＝知らない欄の検出が無い）。
	for field: String in BUFF_INTERVENE_FIELDS:
		if effect.has(field):
			_err(issues, skill_id, "%s.%s は intervene{} の中に書くこと（平置きは書けない）" % [where, field])

	var has_intervene: bool = false
	if effect.has(BUFF_INTERVENE):
		has_intervene = true
		# E104 … buff 以外・host: unit 以外には書けない（旧 E67 の移設）。
		# 宿主が居ないと「誰の死亡か」「誰への回復か」「誰の盾か」が決まらない。
		if effect_type != EFFECT_BUFF:
			_err(issues, skill_id, "%s.%s は buff にしか書けない（type: '%s'）" % [where, BUFF_INTERVENE, effect_type])
		elif host != HOST_UNIT:
			_err(issues, skill_id, "%s.%s は host: unit にしか書けない（host: '%s'）" % [where, BUFF_INTERVENE, host])

	if effect_type == EFFECT_BUFF:
		# ⚠ stat は「書かれているときだけ」見る。介入だけを持つ buff（復活・免疫・
		#   被回復増減）は stat も value も持たないため（段階3の後半③で緩めた）。
		# ⚠ has_stat は「stat / value の検証を走らせるか」。⚠ 「何かする buff か」とは
		#   別物にすること。混ぜると、atk_mult_pct だけを持つ buff に E37〜E39
		#   （stat が10軸に無い／value が0以外の整数でない）が誤って出る（実測で踏んだ）。
		# ⚠ 能力値の欄（stat / value / stat_pct）の検査は _validate_stat_fields() の1本（⚠ dot も同じものを呼ぶ）。
		var has_stat: bool = _validate_stat_fields(issues, skill_id, effect, where)
		# ⚠ 新しい補正の欄を足したら、E63（何もしない buff）の判定にも足すこと。
		var has_atk_mult: bool = effect.has(BUFF_ATK_MULT_PCT) or effect.has(BUFF_BASIC_ATTACK) or effect.has(BUFF_CONTROL) \
				or effect.has(FIELD_MISS_PCT)
		# E173 … 目くらまし（回DB-1）
		if effect.has(FIELD_MISS_PCT):
			var miss: Variant = effect.get(FIELD_MISS_PCT, null)
			if not _is_num(miss) or float(miss) < 1.0 or float(miss) > 100.0:
				_err(issues, skill_id, "%s.miss_pct が 1〜100 でない" % where)
		# E63 … 何もしない buff を書かせない。
		# ⚠ これが無いと、stat を必須にしなくなった分だけ typo（"stt"）が
		#   「介入だけを持つ buff」として黙って通る。
		# ⚠ 避けて反撃・そろったら（回MC-1・回GM-1）だけの buff は書ける（⚠ それ自体が働く）。
		var has_trigger_only: bool = effect.has(FIELD_EVADE) or effect.has(FIELD_ON_MEET)
		if not has_stat and not has_atk_mult and not has_intervene and not has_trigger_only:
			_err(issues, skill_id, "%s は buff なのに stat / value も %s も %s{} も無い" % [
				where, BUFF_ATK_MULT_PCT, BUFF_INTERVENE
			])
		# ⚠ buff は multiplier を読まない（PLAN 5-2。意味を3つ持たせない）
		if effect.has("multiplier"):
			_err(issues, skill_id, "%s は buff なので multiplier を書けない（stat / value を使う）" % where)

		# 介入点の中身（E103〜E107・W14）。⚠ 中身の検証は1本に閉じる。
		if effect.has(BUFF_INTERVENE):
			_validate_intervene(issues, skill_id, where, effect.get(BUFF_INTERVENE, null))

	elif effect_type == EFFECT_DOT:
		# 能力値も下げる継続ダメージ（回DB-1・毒＝攻撃力・火傷＝防御力）。⚠ 書かなければ何もしない。
		_validate_stat_fields(issues, skill_id, effect, where)
		# E40
		var interval: Variant = effect.get("interval_sec", null)
		if not _is_num(interval) or float(interval) <= 0.0:
			_err(issues, skill_id, "%s.interval_sec が正の数値でない" % where)
		# E41
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)
		# E42 … damage と同じ扱い。既定値を作らない
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（dot は damage と同じく必須）" % where)
		# E43
		# ⚠ heals: true のときは書かせない（E114）ので、必須からも外す。
		#   外し忘れると「回復にしたら attack_type が無いと怒られ、書いたら書くなと怒られる」
		#   という、どう書いても赤になる状態になる。
		if not bool(effect.get(FIELD_HEALS, false)):
			if not (str(effect.get("attack_type", "")) in attack_types_known()):
				_err(issues, skill_id, "%s.attack_type が無い、または不明: '%s'" % [where, str(effect.get("attack_type", ""))])
		# W10 … 端数は切り捨て（発火は floor(duration / interval) 回）
		if has_duration and _is_num(interval) and float(interval) > 0.0:
			var duration: float = float(effect.get("duration_sec", 0.0))
			var ratio: float = duration / float(interval)
			if absf(ratio - floor(ratio)) > 0.0001:
				_warn(issues, skill_id, "%s は duration_sec が interval_sec で割り切れない。端数は切り捨てで %d 回発火する" % [
					where, int(floor(ratio))
				])


# 範囲（zone{}）の検証。E108〜E115。
#
# ⚠ 「書ける場所」と「中身」を1本で見る。2本に分けると、host: point に zone{} が
#   無い場合（E109）だけ別の関数に置き忘れる。
static func _validate_zone(
		issues: Array, skill_id: String, effect: Dictionary, where: String,
		host: String, effect_type: String
) -> void:
	var has_zone: bool = effect.has(FIELD_ZONE)

	# E108 … host: point 以外には書けない（読む場所が無い＝無音で無視される）。
	if has_zone and host != HOST_POINT:
		_err(issues, skill_id, "%s.%s は host: 'point' にしか書けない（host: '%s'）" % [
			where, FIELD_ZONE, host
		])
		return
	# E109 … host: point には必ず要る。無いと誰が中に居るのか決まらない。
	if host == HOST_POINT and not has_zone:
		_err(issues, skill_id, "%s に %s{} が無い（host: 'point' は範囲が要る）" % [where, FIELD_ZONE])
		return
	if not has_zone:
		# ⚠ heals は zone を持たない dot にも書けてしまうので、ここで見る。
		_validate_heals(issues, skill_id, effect, where, effect_type)
		return

	var raw: Variant = effect.get(FIELD_ZONE, null)
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		_err(issues, skill_id, "%s.%s が Dictionary でない、または空" % [where, FIELD_ZONE])
		return
	var zone: Dictionary = raw as Dictionary

	# E113 … 知らない欄（E107 と同じ形。typo を無音にしない）。
	for key: Variant in zone.keys():
		if not (str(key) in ZONE_FIELDS_REQUIRED):
			_err(issues, skill_id, "%s.%s に知らない欄がある: '%s'" % [where, FIELD_ZONE, str(key)])

	for field: String in ZONE_FIELDS_REQUIRED:
		if not zone.has(field):
			_err(issues, skill_id, "%s.%s に %s が無い（範囲の欄に既定値は作らない）" % [
				where, FIELD_ZONE, field
			])

	# E110 … 半径は正の数。0 だと誰も入れない（書いたのに何も起きない）。
	if zone.has(ZONE_RADIUS):
		var radius: Variant = zone.get(ZONE_RADIUS, null)
		if not _is_num(radius) or float(radius) <= 0.0:
			_err(issues, skill_id, "%s.%s.%s が正の数値でない" % [where, FIELD_ZONE, ZONE_RADIUS])
	# E111 … 誰に効くか。⚠ 付与者から見た向き。
	if zone.has(ZONE_TEAM):
		if not (str(zone.get(ZONE_TEAM, "")) in ZONE_TEAMS_KNOWN):
			_err(issues, skill_id, "%s.%s.%s が不明: '%s'（'ally' / 'enemy' / 'all'）" % [
				where, FIELD_ZONE, ZONE_TEAM, str(zone.get(ZONE_TEAM, ""))
			])
	# E112 … 追従するか。⚠ bool 以外を許すと「文字列の \"false\" が真」になる。
	if zone.has(ZONE_FOLLOW):
		if not (zone.get(ZONE_FOLLOW, null) is bool):
			_err(issues, skill_id, "%s.%s.%s が bool でない" % [where, FIELD_ZONE, ZONE_FOLLOW])

	_validate_heals(issues, skill_id, effect, where, effect_type)


# 周期の効果を回復にする欄（heals）。E114 / E115。
static func _validate_heals(
		issues: Array, skill_id: String, effect: Dictionary, where: String, effect_type: String
) -> void:
	if not effect.has(FIELD_HEALS):
		return
	# E115 … dot 以外に書いても読む場所が無い。
	if effect_type != EFFECT_DOT:
		_err(issues, skill_id, "%s.%s は dot にしか書けない（type: '%s'）" % [
			where, FIELD_HEALS, effect_type
		])
		return
	if not (effect.get(FIELD_HEALS, null) is bool):
		_err(issues, skill_id, "%s.%s が bool でない" % [where, FIELD_HEALS])
		return
	# E114 … 回復は防御を見ないので attack_type は意味を持たない。
	# ⚠ 書けてしまうと「魔法防御で減る回復」を書いたつもりになる（無音）。
	if bool(effect.get(FIELD_HEALS, false)) and effect.has("attack_type"):
		_err(issues, skill_id, "%s.%s: true に attack_type は書けない（回復は防御を見ない）" % [
			where, FIELD_HEALS
		])


# 介入点（intervene{}）の中身の検証。E103〜E107・W14。
#
# ⚠ 中身を見る場所はここ1本。status_registry.gd に2本目の検証を作らないこと
#   （欄を足したときに片方だけ直す事故が、この器では13回起きている）。
# ⚠ 数値は _is_num() で見る。MasterDataLoader は JSON の 3 を 3.0 で返すので、
#   `is int` で見ると全部赤になる（CLAUDE.md 3番・E69 で9件やった）。
static func _validate_intervene(
		issues: Array, skill_id: String, where: String, raw: Variant
) -> void:
	# E103 … 空の intervene{} は「書いたのに何も起きない」。
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		_err(issues, skill_id, "%s.%s が Dictionary でない、または空" % [where, BUFF_INTERVENE])
		return
	var iv: Dictionary = raw as Dictionary

	# E107 … 知らない欄。⚠ typo が無音で消えるのを防ぐ唯一の網（宿題11）。
	for key: Variant in iv.keys():
		if not (str(key) in INTERVENE_FIELDS_KNOWN):
			_err(issues, skill_id, "%s.%s に知らない欄がある: '%s'" % [where, BUFF_INTERVENE, str(key)])

	# E105 … 量の欄は1以上の整数。0 を許すと「書いたのに何も起きない」が通る。
	for field: String in [INTERVENE_SHIELD_HP, INTERVENE_REFLECT_PCT, INTERVENE_REFLECT_FLAT]:
		if iv.has(field):
			var v: Variant = iv.get(field, null)
			if not _is_num(v) or float(v) != floor(float(v)) or int(v) < 1:
				_err(issues, skill_id, "%s.%s.%s が 1 以上の整数でない" % [where, BUFF_INTERVENE, field])

	# E106 … 割合の上限。⚠ 上限は REDUCTION_PCT_MAX / PIERCE_PCT_MAX が唯一の正。
	#   軽減 100% は「誰も死なない戦闘」になり、GIVE_UP_SEC の赤でしか気づけない。
	if iv.has(INTERVENE_REDUCTION_PCT):
		var red: Variant = iv.get(INTERVENE_REDUCTION_PCT, null)
		if not _is_num(red) or float(red) != floor(float(red)) \
				or int(red) < 1 or int(red) > REDUCTION_PCT_MAX:
			_err(issues, skill_id, "%s.%s.%s が 1〜%d の整数でない" % [
				where, BUFF_INTERVENE, INTERVENE_REDUCTION_PCT, REDUCTION_PCT_MAX
			])
	if iv.has(INTERVENE_PIERCE_PCT):
		var pierce: Variant = iv.get(INTERVENE_PIERCE_PCT, null)
		if not _is_num(pierce) or float(pierce) != floor(float(pierce)) \
				or int(pierce) < 1 or int(pierce) > PIERCE_PCT_MAX:
			_err(issues, skill_id, "%s.%s.%s が 1〜%d の整数でない" % [
				where, BUFF_INTERVENE, INTERVENE_PIERCE_PCT, PIERCE_PCT_MAX
			])

	# E182 … 吸収（回GM-1）。⚠ 印と割合はそろえて書く・割合は 1〜100。
	if iv.has(INTERVENE_DRAIN_TAG) != iv.has(INTERVENE_DRAIN_PCT):
		_err(issues, skill_id, "%s.%s の drain_tag と drain_pct はそろえて書く" % [where, BUFF_INTERVENE])
	if iv.has(INTERVENE_DRAIN_TAG) and str(iv.get(INTERVENE_DRAIN_TAG, "")) == "":
		_err(issues, skill_id, "%s.%s.drain_tag が空" % [where, BUFF_INTERVENE])
	if iv.has(INTERVENE_DRAIN_PCT):
		var drain: Variant = iv.get(INTERVENE_DRAIN_PCT, null)
		if not _is_num(drain) or float(drain) != floor(float(drain)) or int(drain) < 1 or int(drain) > 100:
			_err(issues, skill_id, "%s.%s.drain_pct が 1〜100 の整数でない" % [where, BUFF_INTERVENE])

	# W14 … crit_always: false は書いても何も起きない。消し忘れの合図。
	if iv.has(INTERVENE_CRIT_ALWAYS):
		var crit: Variant = iv.get(INTERVENE_CRIT_ALWAYS, null)
		if not (crit is bool):
			_err(issues, skill_id, "%s.%s.%s が bool でない" % [
				where, BUFF_INTERVENE, INTERVENE_CRIT_ALWAYS
			])
		elif not bool(crit):
			_warn(issues, skill_id, "%s.%s.%s が false（書いても何も起きない）" % [
				where, BUFF_INTERVENE, INTERVENE_CRIT_ALWAYS
			])

	# E64 … 復活。割合は 0 より大きく 1 以下。
	# ⚠ 0 を許すと「復活した瞬間にまた死ぬ」を書けてしまい、走査が毎フレーム回る。
	if iv.has(BUFF_ON_DEATH):
		var raw_death: Variant = iv.get(BUFF_ON_DEATH, null)
		if not (raw_death is Dictionary):
			_err(issues, skill_id, "%s.%s.%s が Dictionary でない" % [where, BUFF_INTERVENE, BUFF_ON_DEATH])
		else:
			var ratio: Variant = (raw_death as Dictionary).get("revive_hp_ratio", null)
			if not _is_num(ratio) or float(ratio) <= 0.0 or float(ratio) > 1.0:
				_err(issues, skill_id, "%s.%s.%s.revive_hp_ratio が 0 より大きく 1 以下の数値でない" % [
					where, BUFF_INTERVENE, BUFF_ON_DEATH
				])

	# E65 … 免疫。付けさせない status_id の配列。
	if iv.has(BUFF_BLOCK_STATUS):
		var raw_block: Variant = iv.get(BUFF_BLOCK_STATUS, null)
		if not (raw_block is Array) or (raw_block as Array).is_empty():
			_err(issues, skill_id, "%s.%s.%s が配列でない、または空" % [where, BUFF_INTERVENE, BUFF_BLOCK_STATUS])
		else:
			for item: Variant in (raw_block as Array):
				if not (item is String) or str(item) == "":
					_err(issues, skill_id, "%s.%s.%s の要素が空でない文字列でない" % [
						where, BUFF_INTERVENE, BUFF_BLOCK_STATUS
					])
					break

	# E66 … 被回復増減。0 は禁止（E39 と同じ考え方）。
	if iv.has(BUFF_HEAL_TAKEN_PCT):
		var pct: Variant = iv.get(BUFF_HEAL_TAKEN_PCT, null)
		if not _is_num(pct) or float(pct) != floor(float(pct)) or int(pct) == 0:
			_err(issues, skill_id, "%s.%s.%s が0以外の整数でない" % [where, BUFF_INTERVENE, BUFF_HEAL_TAKEN_PCT])


# 条件（condition{}）の検証。E55〜E61。
#
# ⚠ 条件は「一度も真にならない」「常に真」のどちらも実行時にエラーを出さず、
#   画面を見ても分からない。書き方の誤りはここで全部弾く。
static func _validate_condition(
		issues: Array, skill_id: String, raw: Variant, where: String, host: String
) -> void:
	# E55
	if not (raw is Dictionary):
		_err(issues, skill_id, "%s.condition が Dictionary でない" % where)
		return
	var cond: Dictionary = raw as Dictionary

	# E56 … 語彙は condition_sources() が唯一の正（distance は除いてある）
	var source: String = str(cond.get("source", ""))
	if not (source in condition_sources()):
		_err(issues, skill_id, "%s.condition.source が無い、または不明: '%s'" % [where, source])

	# E57 … ⚠ scale_from の of（user / target）と別の一覧
	if not (str(cond.get("of", "")) in COND_OF_KNOWN):
		_err(issues, skill_id, "%s.condition.of が無い、または不明: '%s'（host / source のどちらか）" % [
			where, str(cond.get("of", ""))
		])

	# E58
	if not (str(cond.get("op", "")) in COND_OPS_KNOWN):
		_err(issues, skill_id, "%s.condition.op が無い、または不明: '%s'" % [where, str(cond.get("op", ""))])

	# E59
	if not _is_num(cond.get("value", null)):
		_err(issues, skill_id, "%s.condition.value が数値でない" % where)

	# E60 / E71 … ⚠ ここの status_id は「見たい相手の状態のID」で、効果の status_id とは別物
	# ⚠ status_has（付いているか）と stack（何件積まれているか）の2つが status_id を取る。
	#   どちらも入れ子の形で書く（前方一致にしない・PLAN 5-5-4）。
	if source == COND_SOURCE_STATUS_HAS or source == SCALE_STACK:
		if str(cond.get("status_id", "")) == "":
			_err(issues, skill_id, "%s.condition.source: '%s' に status_id が無い（見たい相手の状態のID）" % [where, source])
	elif cond.has("status_id"):
		_err(issues, skill_id, "%s.condition.status_id は source: 'status_has' / 'stack' のときだけ書ける" % where)

	# ⚠ ここに「of を読まない source」の黄（W12）を足さないこと。
	#   condition の of は E57 が必須にしているので、elapsed_sec / wave_index を
	#   書くたびに黄が出る＝正常系に警告を付けることになる。
	#   scale_from 側は of が省略可なので、あちらにだけ W12 を置いてある。

	# E61 … 宿り先は unit だけ。point（オーラ）は真偽が「状態 × ユニットの対」ごとに
	#       なり、状態1件につき1つの真偽では足りない（段階3の後半②の担当外）。
	if host != HOST_UNIT:
		_err(issues, skill_id, "%s.host: '%s' に condition は書けない（今は host: 'unit' だけ）" % [where, host])


# E22。文字列（省略形）か、{source, of, weight} の配列。
static func _validate_scale_from(
		issues: Array, skill_id: String, raw: Variant, where: String
) -> void:
	var terms: Array = []
	if raw is String:
		terms = [{ "source": str(raw) }]
	elif raw is Array:
		if (raw as Array).is_empty():
			_err(issues, skill_id, "%s.scale_from が空配列" % where)
			return
		terms = raw as Array
	else:
		_err(issues, skill_id, "%s.scale_from が文字列でも配列でもない" % where)
		return

	var known: Array = scale_sources()
	for term: Variant in terms:
		if not (term is Dictionary):
			_err(issues, skill_id, "%s.scale_from の要素が Dictionary でない" % where)
			continue
		var entry: Dictionary = term as Dictionary
		var source: String = str(entry.get("source", ""))
		if not (source in known) and source != SCALE_RESOURCE_SPENT and source != SCALE_RESOURCE_NOW and source != SCALE_FLAT:
			_err(issues, skill_id, "%s.scale_from の source が不明: '%s'" % [where, source])
		# E175 … いまの資源の量には resource_id が要る（回SC-1）。
		if source == SCALE_RESOURCE_NOW and str(entry.get(RESOURCE_FIELD_ID, "")) == "":
			_err(issues, skill_id, "%s.scale_from の source: 'resource' に resource_id が無い" % where)
		elif source != SCALE_RESOURCE_NOW and entry.has(RESOURCE_FIELD_ID):
			_err(issues, skill_id, "%s.scale_from の resource_id は source: 'resource' のときだけ書ける" % where)
		# E159 … 払った量はコードが書く（⚠ データに書くと払った量と食い違う）。
		if entry.has(SCALE_FIELD_SPENT):
			_err(issues, skill_id, "%s.scale_from の %s はデータに書けない（撃つ瞬間にコードが書く）" % [where, SCALE_FIELD_SPENT])
		if entry.has("of") and not (str(entry.get("of", "")) in SCALE_OF_KNOWN):
			_err(issues, skill_id, "%s.scale_from の of が不明: '%s'" % [where, str(entry.get("of", ""))])
		if entry.has("weight") and not _is_num(entry.get("weight", null)):
			_err(issues, skill_id, "%s.scale_from の weight が数値でない" % where)

		# E68 … of: "source" は実装しないと決めた（人間の決定・2026-08-17）。
		# ⚠ 定数 SCALE_OF_SOURCE は残してある。外すと「of が不明」という
		#   別の文言で赤が出て、なぜ書けないのかが読み手に伝わらないため。
		# ⚠ 書けるのに 0.0 になる経路を消すのがこの赤の目的。
		if str(entry.get("of", "")) == SCALE_OF_SOURCE:
			_err(issues, skill_id, "%s.scale_from の of: 'source' は実装しないと決めた。of: 'user' / 'target' で書くこと" % where)

		# E71 / E72 … stack は入れ子で書く（{ source: "stack", status_id: "..." }）。
		# ⚠ condition 側の status_has と同じ型。前方一致にしない。
		if source == SCALE_STACK:
			if str(entry.get("status_id", "")) == "":
				_err(issues, skill_id, "%s.scale_from の source: 'stack' に status_id が無い" % where)
		elif entry.has("status_id"):
			_err(issues, skill_id, "%s.scale_from の status_id は source: 'stack' のときだけ書ける" % where)

		# W12 … of を読まない source に of を書いても無視される。
		# ⚠ 黄にしてある。赤にすると、既存の distance + of の書き方が全部止まる。
		if entry.has("of") and (source in SCALE_SOURCES_NO_OF):
			_warn(issues, skill_id, "%s.scale_from の source: '%s' は of を読まない（無視される）" % [where, source])


# cost の形（回CH-2）。
# 印・倒したら・そろったら・時間を戻す（回GM-1・E183〜E186）。
static func _validate_gm_fields(
		issues: Array, skill_id: String, effect: Dictionary, where: String,
		effect_type: String, activation: String, in_react: bool
) -> void:
	# E183 印は damage と dot だけ（⚠ 回復の dot には書けない＝吸収するダメージが無い）。
	if effect.has(FIELD_TAG):
		if not (effect_type in [EFFECT_DAMAGE, EFFECT_DOT]) or bool(effect.get(FIELD_HEALS, false)):
			_err(issues, skill_id, "%s.tag は damage と（回復でない）dot にしか書けない" % where)
		elif str(effect.get(FIELD_TAG, "")) == "":
			_err(issues, skill_id, "%s.tag が空" % where)
	# E184 倒したら（damage だけ）
	if effect.has(FIELD_ON_KILL):
		if effect_type != EFFECT_DAMAGE:
			_err(issues, skill_id, "%s.on_kill は damage にしか書けない" % where)
		else:
			_validate_sub_effects(issues, skill_id, effect.get(FIELD_ON_KILL, null), where + ".on_kill",
				["when_status", "effects"], activation, true)
	# E185 そろったら（状態・host: unit だけ）
	if effect.has(FIELD_ON_MEET):
		if not (effect_type in [EFFECT_BUFF, EFFECT_DOT]) or str(effect.get("host", "")) != HOST_UNIT:
			_err(issues, skill_id, "%s.on_meet は host: unit の buff / dot にしか書けない" % where)
		else:
			var meet: Variant = effect.get(FIELD_ON_MEET, null)
			if meet is Dictionary and str((meet as Dictionary).get("status_id", "")) == "":
				_err(issues, skill_id, "%s.on_meet.status_id が無い（どの状態とそろったら）" % where)
			elif meet is Dictionary and str((meet as Dictionary).get("status_id", "")) == str(effect.get("status_id", "")):
				_err(issues, skill_id, "%s.on_meet.status_id が自分と同じ" % where)
			_validate_sub_effects(issues, skill_id, meet, where + ".on_meet", ["status_id", "effects"], activation, false)
	# E189 避けて反撃（回MC-1）。⚠ host: unit の buff だけ・中の効果は攻撃してきた相手に当たる（⚠ target は書かない）。
	if effect.has(FIELD_EVADE):
		if effect_type != EFFECT_BUFF or str(effect.get("host", "")) != HOST_UNIT:
			_err(issues, skill_id, "%s.evade は host: unit の buff にしか書けない" % where)
		else:
			var evade: Variant = effect.get(FIELD_EVADE, null)
			if evade is Dictionary:
				for i: int in range(((evade as Dictionary).get("effects", []) as Array).size()):
					var sub: Variant = ((evade as Dictionary)["effects"] as Array)[i]
					if sub is Dictionary and (sub as Dictionary).has("target"):
						_err(issues, skill_id, "%s.evade.effects[%d] に target は書けない（攻撃してきた相手に当たる）" % [where, i])
			_validate_sub_effects(issues, skill_id, evade, where + ".evade", ["effects"], activation, false)
	# E186 時間を戻す
	if effect_type == EFFECT_REFRESH_STATUS:
		if str(effect.get("status_id", "")) == "":
			_err(issues, skill_id, "%s.status_id が無い（どの状態の時間を戻すか）" % where)
		for forbidden: String in ["scale_from", "multiplier", "attack_type", "host", "duration_sec"]:
			if effect.has(forbidden):
				_err(issues, skill_id, "%s.type: 'refresh_status' に %s は書けない" % [where, forbidden])


# on_kill / on_meet の中身。⚠ 中の効果は effects[] と同じ検証を通す（⚠ 入れ子の入れ子は書けない）。
static func _validate_sub_effects(
		issues: Array, skill_id: String, raw: Variant, where: String, keys: Array,
		activation: String, need_target: bool
) -> void:
	if not (raw is Dictionary):
		_err(issues, skill_id, "%s が辞書でない" % where)
		return
	for key: Variant in (raw as Dictionary):
		if not (str(key) in keys):
			_err(issues, skill_id, "%s に知らない欄がある: '%s'" % [where, str(key)])
	var effects: Variant = (raw as Dictionary).get("effects", null)
	if not (effects is Array) or (effects as Array).is_empty():
		_err(issues, skill_id, "%s.effects が空でない配列でない" % where)
		return
	for i: int in range((effects as Array).size()):
		var sub: Variant = (effects as Array)[i]
		if not (sub is Dictionary):
			_err(issues, skill_id, "%s.effects[%d] が辞書でない" % [where, i])
			continue
		for nested: String in [FIELD_ON_KILL, FIELD_ON_MEET, "react"]:
			if (sub as Dictionary).has(nested):
				_err(issues, skill_id, "%s.effects[%d] に %s は書けない（入れ子の入れ子）" % [where, i, nested])
		if need_target and not (sub as Dictionary).has("target"):
			_err(issues, skill_id, "%s.effects[%d] に target が無い（⚠ 撃った本人なら {\"team\": \"self\"}）" % [where, i])
		_validate_effect(issues, skill_id, sub as Dictionary, i, activation, where, true)


# 狙いが動く溜め（回GM-1・E187）。⚠ activation: charge だけ・target は origin: "aim" の範囲。
static func _validate_aim(issues: Array, skill_id: String, data: Dictionary) -> void:
	var raw_target: Variant = data.get("target", null)
	var uses_aim: bool = raw_target is Dictionary and str((raw_target as Dictionary).get("origin", "")) == ORIGIN_AIM
	if not data.has(FIELD_AIM):
		if uses_aim:
			_err(issues, skill_id, "target.origin: 'aim' なのに aim{} が無い")
		return
	if str(data.get("activation", "")) != ACTIVATION_CHARGE:
		_err(issues, skill_id, "aim{} は activation: charge にしか書けない（溜めている間に動く）")
	if not uses_aim:
		_err(issues, skill_id, "aim{} があるのに target.origin が 'aim' でない（狙いを使わない）")
	var aim: Variant = data.get(FIELD_AIM, null)
	if not (aim is Dictionary):
		_err(issues, skill_id, "aim が辞書でない")
		return
	for key: Variant in (aim as Dictionary):
		if not (str(key) in AIM_FIELDS_REQUIRED):
			_err(issues, skill_id, "aim に知らない欄がある: '%s'" % str(key))
	for field: String in AIM_FIELDS_REQUIRED:
		var v: Variant = (aim as Dictionary).get(field, null)
		if not _is_num(v) or float(v) < 0.0:
			_err(issues, skill_id, "aim.%s が 0 以上の数でない" % field)
	if _is_num((aim as Dictionary).get("from", null)) and _is_num((aim as Dictionary).get("to", null)) \
			and float((aim as Dictionary)["to"]) < float((aim as Dictionary)["from"]):
		_err(issues, skill_id, "aim.to が from より手前")


# 自分の召喚が足りないと撃てない（回NC-1・E179）。⚠ unit_ids が summons.json にあるかは MasterDataLoader（E100 と同じ場所）。
static func _validate_need_summons(issues: Array, skill_id: String, data: Dictionary) -> void:
	if not data.has(FIELD_NEED_SUMMONS):
		return
	var raw: Variant = data.get(FIELD_NEED_SUMMONS, null)
	if not (raw is Dictionary):
		_err(issues, skill_id, "need_summons が辞書でない")
		return
	var need: Dictionary = raw as Dictionary
	for key: Variant in need:
		if not (str(key) in [CONSUME_FIELD_UNIT_IDS, "count"]):
			_err(issues, skill_id, "need_summons に知らない欄がある: '%s'" % str(key))
	if not _is_id_list(need.get(CONSUME_FIELD_UNIT_IDS, null)):
		_err(issues, skill_id, "need_summons.unit_ids が空でない文字列の配列でない")
	var count: Variant = need.get("count", null)
	if not _is_num(count) or float(count) < 1.0 or float(count) != floor(float(count)):
		_err(issues, skill_id, "need_summons.count が1以上の整数でない")
	if str(data.get("activation", "")) == ACTIVATION_PASSIVE:
		_err(issues, skill_id, "activation: 'passive' に need_summons は書けない（撃つ瞬間が無い）")


# 召喚を使う効果（回NC-1・E178）。
static func _validate_summon_consume(issues: Array, skill_id: String, effect: Dictionary, where: String) -> void:
	if not _is_id_list(effect.get(CONSUME_FIELD_UNIT_IDS, null)):
		_err(issues, skill_id, "%s.unit_ids が空でない文字列の配列でない（summons.json のID）" % where)
	var count: Variant = effect.get("count", null)
	var count_ok: bool = str(count) == CONSUME_COUNT_ALL if count is String \
			else (_is_num(count) and float(count) >= 1.0 and float(count) == floor(float(count)))
	if not count_ok:
		_err(issues, skill_id, "%s.count が1以上の整数か 'all' でない" % where)
	for forbidden: String in ["target", "host"]:
		if effect.has(forbidden):
			_err(issues, skill_id, "%s.type: 'summon_consume' に %s は書けない（自分の召喚が相手）" % [where, forbidden])
	# ⚠ 爆発の欄はそろって書く（⚠ 半径だけ・威力だけは無音で何も起きない）。
	var has_blast: bool = effect.has(CONSUME_FIELD_BLAST_RADIUS)
	if has_blast:
		var radius: Variant = effect.get(CONSUME_FIELD_BLAST_RADIUS, null)
		if not _is_num(radius) or float(radius) <= 0.0:
			_err(issues, skill_id, "%s.blast_radius が正の数でない" % where)
	for blast_field: String in ["multiplier", "attack_type", "scale_from"]:
		if effect.has(blast_field) != has_blast:
			_err(issues, skill_id, "%s.%s は blast_radius と一緒に書く（爆発の威力）" % [where, blast_field])


static func _is_id_list(raw: Variant) -> bool:
	if not (raw is Array) or (raw as Array).is_empty():
		return false
	for v: Variant in (raw as Array):
		if not (v is String) or str(v) == "":
			return false
	return true


static func _validate_cost(issues: Array, skill_id: String, data: Dictionary) -> void:
	var uses_spent: bool = uses_resource_spent(data)
	if not data.has(FIELD_COST):
		# E158 … 払った量で変える効果なのに払わない（⚠ 常に 0 になる）。
		if uses_spent:
			_err(issues, skill_id, "scale_from に resource_spent があるのに cost が無い（常に 0 になる）")
		return
	var raw: Variant = data.get(FIELD_COST, null)
	# E156 cost の形
	if not (raw is Dictionary):
		_err(issues, skill_id, "cost が辞書でない")
		return
	var cost: Dictionary = raw as Dictionary
	for key: Variant in cost:
		if not (str(key) in COST_FIELDS_KNOWN):
			_err(issues, skill_id, "cost に知らない欄がある: '%s'" % str(key))
	if str(cost.get(COST_FIELD_RESOURCE_ID, "")) == "":
		_err(issues, skill_id, "cost.resource_id が無い")
	# E157 amount（1以上の整数）と all: true はどちらか1つ
	var has_amount: bool = cost.has(COST_FIELD_AMOUNT)
	var has_all: bool = cost.has(COST_FIELD_ALL)
	if has_amount == has_all:
		_err(issues, skill_id, "cost は amount と all のどちらか1つを書く")
	if has_amount:
		var amount: Variant = cost.get(COST_FIELD_AMOUNT, null)
		if not _is_num(amount) or float(amount) < 1.0 or float(amount) != floor(float(amount)):
			_err(issues, skill_id, "cost.amount が1以上の整数でない")
	if has_all and cost.get(COST_FIELD_ALL, null) != true:
		_err(issues, skill_id, "cost.all は true だけ書ける")
	if str(data.get("activation", "")) == ACTIVATION_PASSIVE:
		_err(issues, skill_id, "activation: 'passive' に cost は書けない（撃つ瞬間が無い）")
	# E158 … 段のあるスキルで払った量を読む（⚠ 払うのは1段目だけ）。
	if uses_spent and data.has("phases"):
		_err(issues, skill_id, "phases のあるスキルに resource_spent は書けない（払うのは1段目だけ）")


# scale_from に resource_spent を書いた効果があるか（⚠ 段・購読の中も見る）。
static func uses_resource_spent(data: Dictionary) -> bool:
	for phase_index: int in range(phase_count(data)):
		var raw_effects: Variant = phase_of(data, phase_index).get("effects", null)
		if raw_effects is Array and _effects_use_spent(raw_effects as Array):
			return true
	return false


static func _effects_use_spent(effects: Array) -> bool:
	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		var raw_scale: Variant = effect.get("scale_from", null)
		if raw_scale is String and str(raw_scale) == SCALE_RESOURCE_SPENT:
			return true
		if raw_scale is Array:
			for term: Variant in (raw_scale as Array):
				if term is Dictionary and str((term as Dictionary).get("source", "")) == SCALE_RESOURCE_SPENT:
					return true
		var raw_react: Variant = effect.get("react", null)
		if raw_react is Dictionary and (raw_react as Dictionary).get("effects", null) is Array:
			if _effects_use_spent((raw_react as Dictionary)["effects"] as Array):
				return true
	return false


# trigger は cast / charge_start / event:◯◯ / delay:<数値> のどれか。
static func _is_trigger_shape(trigger: String) -> bool:
	if trigger == TRIGGER_CAST or trigger == TRIGGER_CHARGE_START:
		return true
	if trigger.begins_with(TRIGGER_PREFIX_EVENT):
		return trigger.length() > TRIGGER_PREFIX_EVENT.length()
	if trigger.begins_with(TRIGGER_PREFIX_DELAY):
		return trigger.substr(TRIGGER_PREFIX_DELAY.length()).is_valid_float()
	return false


# JSON から来る数値は float。int も許す（手書きの 1 を弾かないため）。
static func _is_num(value: Variant) -> bool:
	return (value is float) or (value is int)


static func _err(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_ERROR, "message": "%s: %s" % [skill_id, message] })


static func _warn(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_WARNING, "message": "%s: %s" % [skill_id, message] })
